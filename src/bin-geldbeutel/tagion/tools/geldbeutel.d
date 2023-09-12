module tagion.tools.geldbeutel;
import core.thread;
import std.format;
import std.getopt;
import std.stdio;
import std.array;
import std.path;
import std.file : exists, mkdir;
import tagion.hibon.HiBONRecord : fwrite, fread;
import std.algorithm;
import std.range;
import tagion.tools.revision;
import tagion.tools.Basic;
import tagion.basic.Types : FileExtension;
import tagion.wallet.KeyRecover;
import tagion.utils.Term;
import tagion.wallet.SecureWallet;
import tagion.wallet.WalletRecords;
import tagion.wallet.AccountDetails;
import tagion.basic.Message;
import tagion.hibon.Document;
import tagion.basic.tagionexceptions;
import tagion.tools.wallet.WalletOptions;
import tagion.tools.wallet.WalletInterface;

mixin Main!(_main, "newwallet");

import tagion.crypto.SecureNet;

import Wallet = tagion.wallet.SecureWallet;

/**
 * @brief build file path if needed file with folder long path
 * @param file - input/output parameter with filename
 * @param path - forlders destination to file
 */
@safe
static void set_path(ref string file, string path) {
    file = buildPath(path, file.baseName);
}

int _main(string[] args) {
    immutable program = args[0];
    bool version_switch;
    bool overwrite_switch; /// Overwrite the config file
    bool create_account;
    bool change_pin;
    bool set_default_quiz;
    string path;
    string pincode;
    bool wallet_ui;
    GetoptResult main_args;
    WalletOptions options;
    auto config_file = "wallet.json";
    if (config_file.exists) {
        options.load(config_file);
    }
    else {
        options.setDefault;
    }

    try {
        main_args = getopt(args, std.getopt.config.caseSensitive,
                std.getopt.config.bundling,
                "version", "display the version", &version_switch,
                "overwrite|O", "Overwrite the config file and exits", &overwrite_switch,
                "path", format("Set the path for the wallet files : default %s", path), &path,
                "wallet", format("Wallet file : default %s", options.walletfile), &options.walletfile,
                "device", format("Device file : default %s", options.devicefile), &options.devicefile,
                "quiz", format("Quiz file : default %s", options.quizfile), &options.quizfile,
                "C|create", "Create a new account", &create_account,
                "c|changepin", "Change pin-code", &change_pin,//"questions", "Questions for wallet creation", &questions_str,
                //"answers", "Answers for wallet creation", &answers_str,
                /*
                "path", format("Set the path for the wallet files : default %s", path), &path,
                "wallet", format("Wallet file : default %s", options.walletfile), &options.walletfile,
                "device", format("Device file : default %s", options.devicefile), &options.devicefile,
                "quiz", format("Quiz file : default %s", options.quizfile), &options.quizfile,
                "invoice|i", format("Invoice file : default %s", invoicefile), &invoicefile,
                "create-invoice|c", "Create invoice by format LABEL:PRICE. Example: Foreign_invoice:1000", &create_invoice_command,
                "contract|t", format("Contractfile : default %s", options.contractfile), &options.contractfile,
                "send|s", "Send contract to the network", &send_flag,
                "amount", "Display the wallet amount", &print_amount,
                "pay|I", format("Invoice to be payed : default %s", payfile), &payfile,
                "update|U", "Update your wallet", &update_wallet,
                "item|m", "Invoice item select from the invoice file", &item,
                */
                "pin|x", "Pincode", &pincode,/*
                "port|p", format("Tagion network port : default %d", options.port), &options.port,
                "url|u", format("Tagion url : default %s", options.addr), &options.addr,
                "visual|g", "Visual user interface", &wallet_ui,
                "questions", "Questions for wallet creation", &questions_str,
                "answers", "Answers for wallet creation", &answers_str,
                "generate-wallet", "Create a new wallet", &generate_wallet,
                "health", "Healthcheck the node", &check_health,
                "unlock", "Remove lock from all local bills", &unlock_bills,
                "nossl", "Disable ssl encryption", &none_ssl_socket,
    */

                

        );
    }
    catch (GetOptException e) {
        stderr.writeln(e.msg);
        return 1;
    }
    if (version_switch) {
        revision_text.writeln;
        return 0;
    }
    if (main_args.helpWanted) {
        //            writeln(logo);
        defaultGetoptPrinter(
                [
                // format("%s version %s", program, REVNO),
                "Documentation: https://tagion.org/",
                "",
                "Usage:",
                format("%s [<option>...] <config.json> <files>", program),
                "",

                "<option>:",

                ].join("\n"),
                main_args.options);
        return 0;
    }
    const new_config = (!config_file.exists || overwrite_switch);
    if (path) {
        if (!new_config) {
            writefln("To change the path you need to use the overwrite switch -O");
            return 10;
        }
        options.walletfile.set_path(path);
        options.quizfile.set_path(path);
        options.devicefile.set_path(path);
        options.accountfile.set_path(path);
        options.billsfile.set_path(path);
        options.paymentrequestsfile.set_path(path);
        const dir = options.walletfile.dirName;
        if (!dir.exists) {
            dir.mkdir;
        }
    }
    if (new_config) {
        options.save(config_file);
        if (overwrite_switch) {
            return 0;
        }
    }
    auto wallet_interface = WalletInterface(options);
    if (!wallet_interface.load) {
        create_account = true;
        writefln("Wallet dont't exists");
        WalletInterface.pressKey;
        wallet_interface.quiz.questions = standard_questions.dup;
    }
    if (create_account) {
        wallet_interface.generateSeed(standard_questions.idup, false);
    }
    else if (change_pin) {
        wallet_interface.changePin;
    }

    if (wallet_interface.secure_wallet != WalletInterface.StdSecureWallet.init) {
        if (pincode) {
            const flag = wallet_interface.secure_wallet.login(pincode);
            if (!flag) {
                stderr.writefln("%sWrong pincode%s", RED, RESET);
                return 3;
            }
        }
        else if (!wallet_interface.loginPincode) {
            wallet_ui = true;
            writefln("Wallet not loggedin");
            WalletInterface.pressKey;

            return 4;
        }
    }

    return 0;
}