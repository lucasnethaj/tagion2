import std.getopt;
import std.stdio;
import std.file : exists;
import std.format;
import std.algorithm : map, max, min, filter, each;
import std.range : lockstep, zip;
import std.array;
import std.string : strip, toLower;
import std.conv : to;
import std.array : join;
import std.exception : assumeUnique;
import std.string : representation;
import core.time : MonoTime;
import std.socket : InternetAddress, AddressFamily;
import core.thread;

import tagion.hibon.HiBON : HiBON;
import tagion.hibon.Document : Document;
import tagion.hibon.HiBONRecord;
import tagion.hibon.HiBONJSON;

import tagion.basic.Basic : basename, Buffer, Pubkey;
import tagion.script.StandardRecords;
import tagion.script.TagionCurrency;
import tagion.crypto.SecureNet : StdSecureNet, StdHashNet, scramble;
import tagion.wallet.KeyRecover;
import tagion.wallet.WalletRecords : RecoverGenerator, DevicePIN, Quiz;
import tagion.wallet.SecureWallet;
import tagion.utils.Term;
import tagion.basic.Message;
import tagion.utils.Miscellaneous;

//import tagion.script.StandardRecords : Invoice;
import tagion.communication.HiRPC;
import tagion.network.SSLSocket;
import tagion.Keywords;

//import tagion.revision;

enum LINE = "------------------------------------------------------";

StdSecureNet net;

version (none) {
    enum ulong AXION_UNIT = 1_000_000;
    enum ulong AXION_MAX = 1_000_000 * AXION_UNIT;
}

version (none) ulong toAxion(const double amount) pure {
    auto result = AXION_UNIT * amount;
    if (result > AXION_MAX) {
        result = AXION_MAX;
    }
    return cast(ulong) result;
}

version (none) double toTagion(const ulong amount) pure {
    return (cast(real) amount) / AXION_UNIT;
}

version (none) string TGN(const ulong amount) pure {
    const ulong tagions = amount / AXION_UNIT;
    const ulong axions = amount % AXION_UNIT;
    return format("%d.%d TGN", tagions, axions);
}

// Order
// Is defined as information's which the customer send to receive get payment information (pubkeys)
//

// Invoice
// Is defined as information's which the seller generates to the costumer about the (pubkeys)
//

Buffer drive_state;
void writeAccounts(string file, Buffer[Pubkey] accounts) {
    if (accounts.length) {
        auto hibon_accounts = new HiBON;
        foreach (hashpkey, drive; accounts) {
            hibon_accounts[hashpkey.toHexString] = drive;
        }
        auto hibon = new HiBON;
        hibon["state"] = drive_state;
        hibon[accounts.stringof] = hibon_accounts;
        file.fwrite(hibon);
    }
}

Buffer[Pubkey] readAccounts(string file) {
    Buffer[Pubkey] accounts;
    if (file.exists) {
        const doc = file.fread;
        // immutable data=assumeUnique(cast(ubyte[])file.fread);
        // const doc=Document(data);
        // if (doc.isInOrder) {
        drive_state = doc["state"].get!Buffer;
        const doc_accounts = doc[accounts.stringof].get!Document;
        foreach (e; doc_accounts[]) {
            Pubkey key = decode(e.key);
            accounts[key] = e.get!Buffer;
            // }
        }
    }
    return accounts;
}

version (none) ulong calcTotal(const(StandardBill[]) bills) {
    ulong result;
    foreach (b; bills) {
        result += b.value;
    }
    return result;
}

version (none) ulong calcTotal(const(Invoice[]) invoices) {
    ulong result;
    foreach (b; invoices) {
        result += b.amount;
    }
    return result;
}

version (none) void updateBills(string file, StandardBill[] bills) {
    import tagion.dart.DARTFile;

    if (bills.length) {
        auto bills_hibon = new HiBON;
        foreach (i, bill; bills) {
            HiBON archive = new HiBON;
            archive[DARTFile.Params.archive] = bill.toHiBON;
            archive[DARTFile.Params.type] = cast(uint)(DARTFile.Recorder.Archive.Type.ADD);
            bills_hibon[i] = archive;
        }
        file.fwrite(bills_hibon);
    }
}

version(none)
StandardBill[] readBills(string file) {
    StandardBill[] result;
    if (file.exists) {
        const doc_recorder = file.fread;
        if (doc_recorder.isInorder && doc_recorder.isArray) {
            foreach (e; doc_recorder[]) {
                const doc_archive = e.get!Document;
                const doc_bill = doc_archive["archive"].get!Document;
                auto bill = StandardBill(doc_bill);
                Pubkey pkey = bill.owner;
                if (pkey in accounts) {
                    result ~= bill;
                }
            }
        }
    }
    return result;
}

string accountfile = "account.hibon";
Buffer[Pubkey] accounts;

string walletfile = "tagionwallet.hibon";
string quizfile = "quiz.hibon";

void warning() {
    writefln("%sWARNING%s: This wallet should only be used for the Tagion Dev-net%s", RED, BLUE, RESET);
}

Invoice[] readInvoices(string file) {
    Invoice[] result;
    if (file.exists) {
        const doc = file.fread;
        if (doc.isInorder && doc.isArray) {
            foreach (e; doc[]) {
                const sub_doc = e.get!Document;
                result ~= Invoice(sub_doc);
            }
        }
    }
    return result;
}

//alias ContractT=Contract!(ContractType.INTERNAL);
version (none) bool payment(const(Invoice[]) orders, const(StandardBill[]) bills, ref SignedContract result) {
    if (net) {
        const topay = calcTotal(orders);

        StandardBill[] contract_bills;
        if (topay > 0) {
            string source;
            uint count;
            foreach (o; orders) {
                source = assumeUnique(format("%s %s", o.amount, source));
                count++;
            }

            // Input
            ulong amount = topay;

            foreach (b; bills) {
                amount -= min(amount, b.value);
                contract_bills ~= b;
                if (amount == 0) {
                    break;
                }
            }
            if (amount != 0) {
                return false;
            }
            //        result.input=contract_bills; // Input bills
            //        Buffer[] inputs;
            foreach (b; contract_bills) {
                result.contract.input ~= net.calcHash(b.toHiBON.serialize);
            }
            const _total_input = calcTotal(contract_bills);
            if (_total_input >= topay) {
                const _rest = _total_input - topay;
                count++;
                result.contract.script = assumeUnique(format("%s %s %d pay", source, _rest, count));
                // output
                Invoice money_back;
                money_back.amount = _rest;
                createInvoice(money_back);
                result.contract.output ~= money_back.pkey;
                foreach (o; orders) {
                    result.contract.output ~= o.pkey;
                }
            }
            else {
                return false;
            }
        }

        // Sign all inputs
        immutable message = net.calcHash(result.contract.toHiBON.serialize);
        shared shared_net = cast(shared) net;
        foreach (i, b; contract_bills) {
            Pubkey pkey = b.owner;
            if (pkey in accounts) {
                writefln("%d] b.owner        %s", i, b.owner.toHexString);
                writefln("%d] account        %s", i, net.derivePubkey(accounts[pkey]).toHexString);
                immutable tweak_code = accounts[pkey];
                auto bill_net = new StdSecureNet;
                bill_net.derive(tweak_code, shared_net);
                immutable signature = bill_net.sign(message);
                result.signs ~= signature;
                writefln("signed %5s pkey=%s", net.verify(message, signature, pkey), pkey.toHexString);
            }
        }

        //    result.contract=Document(contract);
        return true;
    }
    return false;
}

version (none)
void createInvoice(ref Invoice invoice) {
    string current_time = MonoTime.currTime.toString;
    scope seed = new ubyte[net.hashSize];
    scramble(seed);
    drive_state = net.calcHash(seed ~ drive_state ~ current_time.representation);
    scramble(seed);
    //                invoice.drive=drive_state;

    const pkey = net.derivePubkey(drive_state);
    invoice.pkey = cast(Buffer) pkey;
    accounts[pkey] = drive_state;
}

string contractfile = "contract.hibon";
string billsfile = "bills.hibon";
string invoicefile = "invoice.hibon";
string devicefile = "device.hibon";
Invoice[] invoices;
Invoice[] orders;
StandardBill[] bills;

version(none)
void accounting() {
    int ch;
    KeyStroke key;

    if (drive_state.length is 0) {
        const seed = "invoices";
        drive_state = net.calcHash(seed.representation);
    }

    CLEARSCREEN.write;
    scope (success) {
        CLEARSCREEN.write;
    }

    scope (success) {
        if (invoices.length) {
            auto hibon = new HiBON;
            foreach (i, ref invoice; invoices) {
                const index = cast(uint) i;
                /++
                 string current_time=MonoTime.currTime.toString;
                 scope seed=new ubyte[net.hashSize];
                 scramble(seed);
                 drive_state=net.calcHash(seed~drive_state~current_time.representation);
                 scramble(seed);
//                invoice.drive=drive_state;

const pkey=net.drivePubkey(drive_state);
invoice.pkey=cast(Buffer)pkey;
accounts[pkey]=drive_state;
+/
                createInvoice(invoice);
                hibon[index] = invoice.toHiBON;
            }
            invoicefile.fwrite(hibon);
            accountfile.writeAccounts(accounts);
        }
    }

    uint select_index = 0;
    uint selected = uint.max;
    const _total = calcTotal(bills);
    while (ch != 'q') {
        HOME.write;
        warning();
        writefln(" Invoices ");
        LINE.writeln;
        writefln("                                 total %s", TGN(_total));
        LINE.writeln;

        if (invoices) {
            foreach (i, a; invoices) {
                string select_code;
                string chosen_code;
                if (select_index == i) {
                    select_code = BLUE ~ BACKGOUND_WHITE;
                }
                if (selected == i) {
                    chosen_code = GREEN;
                }
                // const ulong tagions=a.amount/AXION_UNIT;
                // const ulong axions=a.amount % AXION_UNIT;

                writefln("%2d %s%s%s %s%s", i, select_code, chosen_code, a.name, TGN(a.amount), RESET);
            }
            LINE.writeln;
            writefln("%1$sq%2$s:quit %1$si%2$s:invoice %1$sEnter%2$s:select %1$sUp/Down%2$s:move              ",
                FKEY, RESET);
        }
        else {
            writefln("%1$sq%2$s:quit %1$si%2$s:invoice ", FKEY, RESET);
        }
        CLEARDOWN.writeln;
        const keycode = key.getKey(ch);

        with (KeyStroke.KeyCode) {
            switch (keycode) {
            case UP:
                if (invoices.length) {
                    select_index = (select_index - 1) % invoices.length;
                }
                break;
            case DOWN:
                if (invoices.length) {
                    select_index = (select_index + 1) % invoices.length;
                }
                break;
            case ENTER:
                selected = select_index;
                writefln("%s%s%s", questions[select_index], CLEAREOL, CLEARDOWN);
                answers[select_index]=readln.strip;
                writefln("line=%s", answers[select_index]);
                break;
            case NONE:
                switch (ch) {
                case 'i':
                    writeln("Item name");
                    Invoice new_invoice;
                    new_invoice.name = readln.strip;
                    if (new_invoice.name.length == 0 || (new_invoice.name[0] == ':')) {
                        break;
                    }
                    writefln("Price in TGN");
                    const amount_tagion = readln.strip;
                    if (amount_tagion.length == 0 || (amount_tagion[0] == ':')) {
                        break;
                    }
                    new_invoice.amount = toAxion(amount_tagion.to!double);
                    if (new_invoice.amount) {
                        invoices ~= new_invoice;
                    }
                    CLEARSCREEN.write;
                    break;
                default:
                    // ignore
                }
                break;
            default:
                // ignore
            }
        }
    }
}

version (none) bool loginPincode(const(char[]) pincode) {
    auto hashnet = new StdHashNet;
    auto recover = new KeyRecover(hashnet);
    auto pinhash = recover.checkHash(pincode.representation);
    //writefln("pinhash=%s", pinhash.toHexString);
    auto R = new ubyte[hashnet.hashSize];
    xor(R, wallet.Y, pinhash);
    if (wallet.check == recover.checkHash(R)) {
        net = new StdSecureNet;
        net.createKeyPair(R);
        return true;
    }
    return false;
}

enum MAX_PINCODE_SIZE = 128;
//Wallet* wallet;
struct WalletInterface {
    alias StdSecureWallet = SecureWallet!StdSecureNet;
    StdSecureWallet secure_wallet;
    Quiz quiz;
    this(StdSecureWallet secure_wallet) {
        this.secure_wallet=secure_wallet;
    }


    bool loginPincode() {
        CLEARSCREEN.write;
        foreach(i;0..3) {
            HOME.write;
            writefln("%1$sAccess code required%2$s", GREEN, RESET);
            writefln("%1$sEnter empty pincode to proceed recovery%2$s", YELLOW, RESET);
            writefln("pincode:");
            char[] pincode;
            scope(exit) {
                scramble(pincode);
            }
            readln(pincode);
            pincode.word_strip;
            writefln("pincode.length=%d", pincode.length);
            if (pincode.length) {
                secure_wallet.login(pincode);
                if (secure_wallet.isLoggedin) {
                    return true;
                }
                writefln("%1$sWrong pincode%2$s", RED, RESET);
            }
            else {

//                writefln("quiz.questions=%s", quiz.questions);
                generateSeed(quiz.questions, true);
                return secure_wallet.isLoggedin;
            }
        }
        CLEARSCREEN.write;
        return false;
    }

    void accountView() {

        enum State {
            CREATE_ACCOUNT,
            WAIT_LOGIN,
            LOGGEDIN
        }

        State state;

        version (none)
            if (walletfile.exists) {
                immutable data = assumeUnique(cast(ubyte[]) walletfile.fread);
                const doc = Document(data);
                if (doc.isInorder) {
                    auto hashnet = new StdHashNet;
                    wallet = new Wallet(doc);
                    state = State.WAIT_LOGIN;
                }
            }

        version(none)
            if (wallet !is null) {
                if (net is null) {
                    state = State.WAIT_LOGIN;
                }
                else {
                    state = State.LOGGEDIN;
                }
            }

        int ch;
        KeyStroke key;
        CLEARSCREEN.write;
        while (ch != 'q') {
            HOME.write;
            warning();
            writefln(" Account overview ");

            LINE.writeln;
            const processed = secure_wallet.account.processed;
            if (!processed) {
                writefln("                                 available %s", secure_wallet.account.available);
                writefln("                                    active %s", secure_wallet.account.active);
            }
            (processed?GREEN:RED).write;
            writefln("                                     total %s", secure_wallet.account.total);
            RESET.write;
            LINE.writeln;
            with (State) final switch (state) {
                case CREATE_ACCOUNT:
                    if (secure_wallet.isLoggedin) {
                        writefln("%1$sq%2$s:quit %1$sa%2$s:account %1$sp%2$s:change pin%3$s", FKEY, RESET, CLEARDOWN);
                    }
                    else {
                        writefln("%1$sq%2$s:quit %1$sa%2$s:account %1$sc%2$s:create%3$s", FKEY, RESET, CLEARDOWN);
                    }
                    break;
                case WAIT_LOGIN:
                    writefln("Pincode:%s", CLEARDOWN);
                    //char[MAX_PINCODE_SIZE] stack_pincode;
                    char[] pincode;
                    pincode.length = MAX_PINCODE_SIZE;
                    readln(pincode);
                    //pincode = pincode[0..size];
                    word_strip(pincode);
                    scope(exit) {
                        //pincode = stack_pincode;
                        scramble(pincode);
                    }
                    secure_wallet.login(pincode);
                    if (secure_wallet.isLoggedin) {
                        state = LOGGEDIN;
                        continue;
                    }
                    else {
                        writefln("%sWrong pin%s", RED, RESET);
                        writefln("Press %sEnter%s", YELLOW, RESET);
                    }
                    break;
                case LOGGEDIN:
                    writefln("%1$sq%2$s:quit %1$sa%2$s:account %1$sr%2$s:recover%3$s", FKEY, RESET, CLEARDOWN);
                    break;
                }
            CLEARDOWN.writeln;
            const keycode = key.getKey(ch);
            switch (ch) {
            case 'a':
                if (walletfile.exists) {
                    version(none)
                        accounting;
                }
                else {
                    writeln("Account doesn't exists");
                    Thread.sleep(1.seconds);
                }
                break;
            case 'c':
                if (!secure_wallet.isLoggedin) {
                    generateSeed(standard_questions.idup, false);
                }
                break;
            case 'p':
                changePin;
                break;
            default:
                // ignore
            }
        }
    }

    enum FKEY = YELLOW;

    void pressKey() {
        writefln("Press %1$sEnter%2$s", YELLOW, RESET);
        readln;
    }

    void changePin() {
        CLEARSCREEN.write;
        if (secure_wallet.isLoggedin) {
            foreach(i; 0..3) {
                HOME.write;
        CLEARSCREEN.write;
        scope (success) {
            CLEARSCREEN.write;
        }
        writeln("Change you pin code");
        LINE.writeln;
        if (secure_wallet.pin.Y) {
            char[] old_pincode;
            char[] new_pincode1;
            char[] new_pincode2;
            scope(exit) {
                // Scramble the code to prevent memory leaks
                old_pincode.scramble;
                new_pincode1.scramble;
                new_pincode2.scramble;
            }
            writeln("Current pincode:");
            readln(old_pincode);
            old_pincode.word_strip;
//            secure_wallet.login(old_pincode);
            if (secure_wallet.check_pincode(old_pincode)) {
                writefln("%1$sCorrect pin%2$s", GREEN, RESET);
                bool ok;
                do {
                    writefln("New pincode:%s", CLEARDOWN);
                    readln(new_pincode1);
                    new_pincode1.word_strip;
                    writefln("Repeate:");
                    readln(new_pincode2);
                    new_pincode2.word_strip;
                    ok=(new_pincode1.length >= 4);
                    if (ok && (ok = (new_pincode1 == new_pincode2)) is true) {
                        secure_wallet.change_pincode(old_pincode, new_pincode1);
                        secure_wallet.login(new_pincode1);
                        devicefile.fwrite(secure_wallet.pin);
                        return;
                    }
                    else {
                        writefln("%1$sPincode to short or does not match%2$s", RED, RESET);
                    }
                }
                while(!ok);
                // if (new_pincode1
                // if (
            }
            else {
                writefln("%1$sWrong pin%2$s", GREEN, RESET);
                pressKey;
            }
            return;
        }
                    writefln("%1$sPin code is missing. You need to recover you keys%2$s", RED, RESET);
        }
        }
    }

    void generateSeed(const(string[]) questions, const bool recover_flag) {
        auto answers = new char[][questions.length];
        auto translated_questions = questions.map!(s => message(s));
        CLEARSCREEN.write;
        scope (success) {
            CLEARSCREEN.write;
        }
        int ch;
        KeyStroke key;
        uint select_index = 0;
        uint confidence;
        if (recover_flag) {
            confidence=secure_wallet.confidence;
        }
        while (ch != 'q') {
            //    import core.stdc.stdio : getc, stdin;
            HOME.write;
            warning();
            if (recover_flag) {
                writefln("Recover account");
                writefln("Answers %d to more of the questions below", confidence);
            }
            else {
                writefln("Create a new account");
                writefln("Answers two to more of the questions below");
            }
            LINE.writeln;
            uint number_of_answers;
            foreach (i, question, answer; lockstep(translated_questions, answers)) {
                string select_code;
                string chosen_code;
                if (select_index == i) {
                    select_code = BLUE ~ BACKGOUND_WHITE;
                }
                if (answer.length) {
                    chosen_code = GREEN;
                    number_of_answers++;
                }
                writefln("%2d %s%s%s%s %s%s", i, select_code, chosen_code, question, RESET, answer.trim, CLEAREOL);
            }
            writefln("recover_flag=%s", recover_flag);
            if (!recover_flag) {
                confidence = min(confidence, number_of_answers);
            }
            writefln("Confidence %d", confidence);

            LINE.writefln;
//            const info = (recover_flag)?"recover":"create";
            if (recover_flag) {
                writefln("%1$sq%2$s:quit %1$sEnter%2$s:select %1$sUp/Down%2$s:move %1$sc%2$s:recover%3$s",
                    FKEY, RESET, CLEARDOWN);
            }
            else {
                writefln("%1$sq%2$s:quit %1$sEnter%2$s:select %1$sUp/Down%2$s:move %1$sLeft/Right%2$s:confidence %1$sc%2$s:create%3$s",
                    FKEY, RESET, CLEARDOWN);
            }
            const keycode = key.getKey(ch);
//            if (keycode = KeyStroke.KeyCode.NONE) {
            // writefln("%s %s", keycode, ch);
//        version(none)
            with (KeyStroke.KeyCode) {
                switch (keycode) {
                case UP:
                    select_index = (select_index - 1) % questions.length;
                    break;
                case DOWN:
                    select_index = (select_index + 1) % questions.length;
                    break;
                case LEFT:
                    if (!recover_flag && confidence > 2) {
                        confidence--;
                    }
                    break;
                case RIGHT:
                    if (!recover_flag) {
                        confidence = max(confidence + 1, number_of_answers);
                    }
                    break;
                case ENTER:
                    writefln("%s%s%s", questions[select_index], CLEAREOL, CLEARDOWN);
                    char[] answer;
                    answer.length = MAX_PINCODE_SIZE;
                    readln(answer);
                    //answer.word_strip;
                    answers[select_index] = answer;
                    if(!recover_flag) {
                        confidence++;
                    }
                    break;
                case NONE:
                    switch (ch) {
                    case 'c': // Create Wallet
                        writefln("Wallet C ");
                        scope(exit) {
                            // Erase the answer from memory
                            answers.each!((ref a) =>  {scramble(a); a=null;});
                            pressKey;
                        }
                        auto quiz_list =zip(questions, answers)
                            .filter!(q => q[1].length > 0);
                        quiz.questions  = quiz_list.map!(q => q[0]).array.dup;
                        auto selected_answers = quiz_list.map!(q => q[1]).array;
                        if (selected_answers.length < 3) {
                            writefln("%1$sThen number of answers must be more than %4$d%2$s%3$s", RED, RESET, CLEAREOL, selected_answers.length);
                        }
                        else {
                            if (recover_flag) {
                                writefln("RECOVER_FLAG");
                                stdout.flush;
                                const ok = secure_wallet.correct(quiz.questions, selected_answers);
                                writefln("RECOVER %s", ok);
                                if (ok) {
                                    writefln("%1$s%3$d or more answers was correct%2$s", GREEN, RESET, confidence);
                                }
                                else {
                                    writefln("%1$sSome wrong answers. The account has not been recovered%2$s", RED, RESET);
                                    secure_wallet.logout;
                                    continue;
                                }
                            }
                            // auto hashnet = new StdHashNet;
                            // auto recover = KeyRecover(hashnet);

                            // if (confidence == selected_answers.length) {
                            //     // Due to some bug in KeyRecover
                            //     confidence--;
                            // }

                            do {
                                char[] pincode1; // = stack_pincode1;
                                pincode1.length  = MAX_PINCODE_SIZE;
                                char[] pincode2;
                                pincode2.length  = MAX_PINCODE_SIZE;
                                scope(exit) {
                                    scramble(pincode1);
                                    scramble(pincode1);
                                }
                                writefln("Pincode:%s", CLEARDOWN);
                                readln(pincode1);
                                pincode1.word_strip;
                                writefln("Repeate:");
                                readln(pincode2);
                                pincode2.word_strip;

                                if (pincode1 != pincode2) {
                                    writefln("%sPincode is not the same%s", RED, RESET);
                                }
                                else if (pincode1.length < 4) {
                                    writefln("%sPincode must be at least 4 chars%s", RED, RESET);
                                }
                                else if (pincode1.length > MAX_PINCODE_SIZE) {
                                    writefln("%1$sPincode must be less than %3$d chars%2$s", RED, RESET, pincode1.length);
                                }
                                else {
                                    if (recover_flag) {
                                        const ok=secure_wallet.recover(quiz.questions, selected_answers, pincode1);
                                        if (ok) {
                                            writefln("%1$sWallet recovered%2$s", GREEN, RESET);
                                        }
                                        else {
                                            writefln("%1$sWallet NOT recovered%2$s", RED, RESET);
                                        }
                                        walletfile.fwrite(secure_wallet.wallet);
                                        devicefile.fwrite(secure_wallet.pin);
                                    }
                                    else {
                                        secure_wallet=StdSecureWallet.createWallet(quiz.questions, selected_answers, confidence, pincode1);
                                    // writefln("pincode1=%s", pincode1);
                                    //writefln("secure_wallet.wallet
                                        secure_wallet.login(pincode1);
                                        walletfile.fwrite(secure_wallet.wallet);
                                        devicefile.fwrite(secure_wallet.pin);
                                        quizfile.fwrite(quiz);
                                        writefln("%1$sWallet created%2$s", GREEN, RESET);

                                    }
                                    // writefln("loggedin=%s", secure_wallet.isLoggedin);
                                }
                            }
                            while (!secure_wallet.isLoggedin);
                            return;
                        }
                        break;
                    default:
                        writefln("Ignore %s '%s'", keycode, cast(char)ch);
                        // ignore
                    }
                    break;
                default:
                    // ignore
                }
            }

        }
//    return null;
    }
}

enum REVNO = 0;
enum HASH = "xxx";

const(char[]) trim(return scope const(char)[] word) pure nothrow @safe @nogc {
    import std.ascii : isWhite;
    while (word.length && word[0].isWhite) {
        word=word[1..$];
    }
    while (word.length && word[$-1].isWhite) {
        word=word[0..$-1];
    }
    return word;
}

void word_strip(scope ref char[] word_strip) pure nothrow @safe @nogc {
    import std.ascii : isWhite;
    scope not_change = word_strip;
    scope(exit) {
        assert((word_strip.length is 0) ||(&not_change[0] is &word_strip[0]), "The pincode should not be reallocated");
    }
    size_t current_i;
    foreach(c; word_strip) {
        if (!c.isWhite) {
            word_strip[current_i++] = c;
        }
    }
    word_strip=word_strip[0..current_i];
}


@safe
unittest {
    import std.ascii : isWhite;
    scope char[] word;
    word.length = MAX_PINCODE_SIZE;
    const test_text = "  Some text with space ";
    const no_change = &word[0];
    word[0..test_text.length] = test_text;
    assert(no_change is &word[0]);
    word_strip(word);
    assert(no_change is &word[0]);
    assert(equal(word, test_text.filter!(c => !c.isWhite)));
}

int main(string[] args) {
    immutable program = args[0];
    bool version_switch;
    string payfile;
    bool wallet_ui;
    bool update_wallet;
    uint number_of_bills;
    string passphrase = "verysecret";
    ulong value = 1000_000_000;
    bool generate_wallet;
    string item;
    string pincode;
    string addr = "localhost";
    ushort port = 10800;
    bool send_flag;
    string create_invoice_command;
    bool print_amount;

    WalletInterface wallet_interface;
    //   pragma(msg, "bill_type ", GetLabel!(StandardBill.bill_type));
    auto main_args = getopt(args, std.getopt.config.caseSensitive,
        std.getopt.config.bundling, "version",
        "display the version", &version_switch,
        "wallet", format("Wallet file : default %s", walletfile), &walletfile,
        "device", format("Device file : default %s", devicefile), &devicefile,
        "quiz", format("Quiz file : default %s", quizfile), &quizfile,
        "invoice|c", format("Invoice file : default %s", invoicefile), &invoicefile,
        "create-invoice", "Create invoice by format LABEL:PRICE. Example: Foreign_invoice:1000", &create_invoice_command,
        "contract|t", format("Contractfile : default %s", contractfile), &contractfile,
        "send|s", "Send contract to the network", &send_flag,
        "amount", "Display the wallet amount", &print_amount,
        "pay|I", format("Invoice to be payed : default %s", payfile), &payfile,
        "update|U", "Update your wallet", &update_wallet, "item|m",
        "Invoice item select from the invoice file", &item,
        "pin|x", "Pincode", &pincode,
        "port|p", format("Tagion network port : default %d", port), &port,
        "url|u", format("Tagion url : default %s", addr), &addr,
        "visual|g", "Visual user interface", &wallet_ui,);
    if (version_switch) {
        writefln("version %s", REVNO);
        writefln("Git handle %s", HASH);
        return 0;
    }

    if (walletfile.exists) {
        const wallet_doc = walletfile.fread;
        const pin_doc = devicefile.exists?devicefile.fread:Document.init;
        if (wallet_doc.isInorder && pin_doc.isInorder) {
            wallet_interface.secure_wallet = WalletInterface.StdSecureWallet(wallet_doc, pin_doc);
        }
        if (quizfile.exists) {
            const quiz_doc = quizfile.fread;
            if (quiz_doc.isInorder) {
                wallet_interface.quiz = Quiz(quiz_doc);
            }
        }
    }
    else {
        wallet_ui = true;
        wallet_interface.quiz.questions = standard_questions.dup;
    }

    if ( wallet_interface.secure_wallet != WalletInterface.StdSecureWallet.init) {
        if (pincode) {
            const flag = wallet_interface.secure_wallet.login(pincode);
            if (!flag) {
                stderr.writefln("%sWrong pincode%s", RED, RESET);
                return 3;
            }
        }
        else if (!wallet_interface.loginPincode) {
            return 4;
        }
        wallet_ui = true;
    }

    if (accountfile.exists) {
        accounts = accountfile.readAccounts;
    }

    if (billsfile.exists) {
        const bills_data = billsfile.fread;
    }

    if (payfile.exists) {
        orders = payfile.readInvoices;
        // const contract=payment(orders, bills);
        // contractfile.fwrite(contract.toHiBON.serialize);
    }

    if (main_args.helpWanted) {
        defaultGetoptPrinter([
                format("%s version %s", program, REVNO), "Documentation: https://tagion.org/", "", "Usage:",
                format("%s [<option>...]", program), "",
                // "Where:",
                // format("<file>           hibon outfile (Default %s", outputfilename),
                // "",

                "<option>:",

                ].join("\n"), main_args.options);
        return 0;
    }

    version(none)
        if (update_wallet) {
            HiRPC hirpc;
            Buffer prepareSearch(Buffer[] owners) {
                HiBON params = new HiBON;
                foreach (i, owner; owners) {
                    params[i] = owner;
                }
                const sender = hirpc.action("search", params);
                immutable data = sender.toDoc.serialize;
                return data;
            }

            // writeln(accounts.length);
            StandardBill[] new_bills;
            Buffer[] pkeys;
            foreach (pkey, dkey; accounts) {
                pkeys ~= cast(Buffer) pkey;
            }
            auto client = new SSLSocket(AddressFamily.INET, EndpointType.Client);
            client.connect(new InternetAddress(addr, port));
            scope (exit) {
                client.close;
            }
            client.blocking = true;
            // writefln("looking for %s", (cast(Buffer)pkey).toHexString);
            auto to_send = prepareSearch(pkeys);
            client.send(to_send);

            auto rec_buf = new void[4000];
            ptrdiff_t rec_size;

            do {
                rec_size = client.receive(rec_buf); //, current_max_size);
                // writefln("read rec_size=%d", rec_size);
                Thread.sleep(400.msecs);
            }
            while (rec_size < 0);
            auto resp_doc = Document(cast(Buffer) rec_buf[0 .. rec_size]);
            auto received = hirpc.receive(resp_doc);
            if (!received.error.hasMember(Keywords.code)) {
                foreach (bill; received.params[]) {
                    auto std_bill = StandardBill(bill.get!Document);
                    new_bills ~= std_bill;
                }
                billsfile.updateBills(new_bills);
                bills = new_bills;
                writeln("Wallet updated");
            }
            else {
                writeln("Wallet update failed");
            }
        }

    if (wallet_ui) {
        writefln("Wallet UI");
        wallet_interface.accountView;
    }
    else {
        if (print_amount) {
            writefln("%s", wallet_interface.secure_wallet.account.total);
            // const total_input = calcTotal(bills);
            // writeln(TGN(total_input));
        }
        version(none)
            if (create_invoice_command.length) {
                auto invoice_args = create_invoice_command.split(':');
                bool invalid = false;
                if (invoice_args.length == 2) {

                    scope (success) {
                        if (invoices.length && !invalid) {
                            auto hibon = new HiBON;
                            foreach (i, ref invoice; invoices) {
                                const index = cast(uint) i;
                                createInvoice(invoice);
                                hibon[index] = invoice.toHiBON;
                            }
                            invoicefile.fwrite(hibon);
                            accountfile.writeAccounts(accounts);
                        }
                    }

                    auto invoice_name = invoice_args[0];
                    auto invoice_price = invoice_args[1];
                    Invoice new_invoice;
                    new_invoice.name = invoice_name;
                    if (new_invoice.name.length == 0 || invoice_price.length == 0) {
                        invalid = true;
                    }
                    else {
                        new_invoice.amount = toAxion(invoice_price.to!double);
                        if (new_invoice.amount) {
                            invoices ~= new_invoice;
                        }
                        else {
                            invalid = true;
                        }
                    }
                }
                else {
                    invalid = true;
                }
                if (invalid) {
                    writeln("Bad command");
                }
            }
            else if (orders) {
                SignedContract signed_contract;
                const flag = payment(orders, bills, signed_contract);
                // writefln("signed_contract.contarct.output.length=%d", signed_contract.contract.output.length);
                if (flag) {
                    //contractfile.fwrite(signed_contract.toHiBON.serialize);
                    HiRPC hirpc;
                    const sender = hirpc.action("transaction", signed_contract.toHiBON);
                    immutable data = sender.toDoc.serialize;
                    const test = Document(data);

                    const scontract = SignedContract(test["message"].get!Document["params"].get!Document);
                    //writefln("%s", Document(scontract.toHiBON.serialize).toJSON.toPrettyString);
                    // writefln("scontract.contarct.output.length=%d", scontract.contract.output.length);
                    // writefln("scontract.contarct.output=%s", scontract.contract);
                    contractfile.fwrite(sender.toDoc);
                }
            }
        if (send_flag) {
            if (contractfile.exists) {
                immutable data = contractfile.fread();
                writeln(data.data[0 .. $]);
                auto doc1 = Document(data.data);
                writeln(doc1.size);

                import LEB128 = tagion.utils.LEB128;

                writeln(LEB128.calc_size(doc1.serialize));
                auto client = new SSLSocket(AddressFamily.INET, EndpointType.Client);
                client.connect(new InternetAddress(addr, port));
                scope (exit) {
                    client.close;
                }
                client.blocking = true;
                // writeln(cast(string) data.data);
                client.send(data.data);

                auto rec_buf = new void[4000];
                ptrdiff_t rec_size;

                do {
                    rec_size = client.receive(rec_buf); //, current_max_size);
                    // writefln("read rec_size=%d", rec_size);
                    Thread.sleep(400.msecs);
                }
                while (rec_size < 0);

                HiRPC hirpc;
                auto resp_doc = Document(cast(Buffer) rec_buf[0 .. rec_size]);
                auto received = hirpc.receive(resp_doc);
                version(none)
                    if (received.params.hasMember(Keywords.code) && received.error[Keywords.code].get!int != 0) {
                        writeln(received.error[Keywords.message].get!string);
                    }
                    else {
                        accountfile.writeAccounts(accounts);
                        writeln("Successfuly sended");
                    }

                Thread.sleep(200.msecs);
            }
        }
    }
    return 0;
}
