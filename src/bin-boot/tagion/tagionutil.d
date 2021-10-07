import std.getopt;
import std.stdio;
import std.file: fread = read, fwrite = write, exists;
import std.format;
import std.exception : assumeUnique;

import tagion.hibon.HiBON : HiBON;
import tagion.hibon.Document : Document;
import tagion.basic.Basic : basename, Buffer, Pubkey;
import tagion.script.StandardRecords;
import tagion.crypto.SecureNet : StdSecureNet;
import tagion.script.StandardRecords : Invoice;
import tagion.dart.DARTFile;

//import tagion.revision;
import std.array : join;

class HiRPCNet : StdSecureNet {
    this(string passphrase) {
        super();
        generateKeyPair(passphrase);
    }
}


Invoice[] invoices;
HiBON generateBills(Document doc) {
    foreach(d; doc[]) {
        invoices~=Invoice(d.get!Document);
    }
    enum TGS="TGS";
//    enum RECORDTYPE = "BILL";
    HiBON archives = new HiBON;
    foreach(i, I; invoices) {
        StandardBill bill;
        with(bill) {
            bill_type = TGS;
            // type = RECORDTYPE;
            value = I.amount;
            epoch = 0;
            auto pkey=I.pkey;
            owner=pkey; //bill_net.calcHash(bill_net.calcHash(pkey));
        }
        HiBON archive = new HiBON;
        archive[DARTFile.Params.archive] = bill.toHiBON;
        archive[DARTFile.Params.type]=cast(uint)(DARTFile.Recorder.Archive.Type.ADD);
        archives[i]=archive;
    }
    return archives;
}

enum REVNO=0;
enum HASH="xxx";
int main(string[] args) {
    immutable program=args[0];
    bool version_switch;

    string invoicefile;
    string outputfilename;
//    StandardBill bill;
    uint number_of_bills;
//    string passphrase="verysecret";
//    ulong value=1000_000_000;

//    bill.toHiBON;

    //   pragma(msg, "bill_type ", GetLabel!(StandardBill.bill_type));
    auto main_args = getopt(args,
        std.getopt.config.caseSensitive,
        std.getopt.config.bundling,
        "version",   "display the version",     &version_switch,
        "invoice|i","Sets the HiBON input file name", &invoicefile,
// //        "outputfile|o", format("Sets the output file name: default : %s", outputfilename), &outputfilename,
//         "bills|b", "Generate bills", &number_of_bills,
        // "value|V", format("Bill value : default: %d", value), &value,
        // "passphrase|P", format("Passphrase of the keypair : default: %s", passphrase), &passphrase

        );

    if (version_switch) {
        writefln("version %s", REVNO);
        writefln("Git handle %s", HASH);
        return 0;
    }

    if ( main_args.helpWanted ) {
        defaultGetoptPrinter(
            [
                format("%s version %s", program, REVNO),
                "Documentation: https://tagion.org/",
                "",
                "Usage:",
                format("%s [<option>...] <file>", program),
                "",
                "Where:",
                format("<file>           hibon outfile (Default %s)", outputfilename),
                "",

                "<option>:",

                ].join("\n"),
            main_args.options);
        return 0;
    }

    if ( args.length > 2) {
        stderr.writefln("Only one output file name allowed (given %s)", args[1..$]);
    }
    else if (args.length > 1) {
        outputfilename=args[1];
    }

    if (invoicefile.exists) {
        immutable data=assumeUnique(cast(ubyte[])invoicefile.fread);
        const doc=Document(data);
        auto hibon=generateBills(doc);
        fwrite(outputfilename, hibon.serialize);
    }

//    writefln("args=%s", args);
    return 0;
}
