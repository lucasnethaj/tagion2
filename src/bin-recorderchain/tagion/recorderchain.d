module tagion.recorderchain;

import std.stdio;
import std.getopt;
import std.path;
import std.format;
import std.array;
import std.file;

import tagion.basic.Basic : Control, Buffer;
import tagion.crypto.SecureNet;
import tagion.crypto.SecureInterfaceNet : SecureNet;
import tagion.dart.Recorder;
import tagion.dart.BlockFile;
import tagion.dart.DART;
import tagion.dart.DARTFile;
import tagion.hibon.HiBON;
import tagion.hibon.Document;
import tagion.services.Options : Options, setDefaultOption;
import tagion.services.RecorderService;
import tagion.services.LoggerService;
import tagion.logger.Logger;
import tagion.communication.HiRPC;

enum main_task = "recorderchain";

int main(string[] args) {
    writeln("bin-recorderchain run");

    const auto EXEC_NAME = baseName(args[0]);

    if (args.length == 1) {
        writeln("Error: No arguments provided for ", EXEC_NAME, "!");
        return 1;
    }

    Options options;
    setDefaultOption(options);

    auto logger_tid = spawn(&loggerTask, options);
    scope (exit) {
        logger_tid.send(Control.STOP);
        receiveOnly!Control;
    }

    const response = receiveOnly!Control;
    stderr.writeln("Logger started");
    if (response !is Control.LIVE) {
        stderr.writeln("ERROR:Logger %s", response);
    }

    log.register(main_task);

    bool print = false;
    bool clean = false;
    ulong rollback, init_count;

    auto cli_args_config = getopt(
            args,
            std.getopt.config.bundling,
            std.getopt.config.noPassThrough,
            "print|p", "Print recorder chain to console", &print,
            "rollback|r", "Rollback recorder chain on n steps backward", &rollback,
            "init|i", "Init n dummy blocks", &init_count,
            "clean|c", "Clean recorder chain folder after work", &clean,
    );

    // TODO: add argument for selecting folder
    auto folder_path = options.recorder.folder_path;
    string dartfilename = folder_path ~ "DummyDART";
    ushort fromAngle = 0;
    ushort toAngle = 1;
    string passphrase = "verysecret";
    SecureNet net = new StdSecureNet;
    net.generateKeyPair(passphrase);
    auto hirpc = HiRPC(net);

    int onHelp() {
        defaultGetoptPrinter(
                [
            "Documentation: https://tagion.org/",
            "",
            "Usage:",
            format("%s <command> [<option>...]\n", EXEC_NAME),
            "Where:",
            "<command> one of [--init, --print, --rollback]\n",
            "<options>:"
        ].join("\n"),
        cli_args_config.options
        );
        return 0;
    }

    void onInit() {
        if (!exists(folder_path))
            mkdirRecurse(folder_path);

        enum BLOCK_SIZE = 0x80;
        BlockFile.create(dartfilename, DARTFile.stringof, BLOCK_SIZE);

        DART db = new DART(net, dartfilename, fromAngle, toAngle);

        // Create dummy Recorder
        HiBON hibon = new HiBON;
        hibon["not_empty_db?"] = "NO:)";

        immutable hashnet = new StdHashNet;
        auto recordFactory = RecordFactory(hashnet);
        auto rec = recordFactory.recorder;
        rec.add(Document(hibon));
        immutable rec_im = cast(immutable) rec;

        // Spawn recorder task
        auto recorder_service_tid = spawn(&recorderTask, options);
        receiveOnly!Control;

        // Send recorder to service
        foreach (i; 0..init_count) {
            recorder_service_tid.send(rec_im, Fingerprint(db.fingerprint));
            addRecordToDB(db, rec_im, hirpc);
        }

        recorder_service_tid.send(Control.STOP);
        receiveOnly!Control;

        writeln(format("Initialized %d dummy records in '%s'", init_count, folder_path));
    }

    void onPrint() {
        auto blocks_info = EpochBlockFileDataBase.getBlocksInfo(folder_path);

        Buffer fingerprint = blocks_info.last.fingerprint;
        foreach (j; 0..blocks_info.amount) {
            const current_block = EpochBlockFileDataBase.readBlockFromFingerprint(fingerprint, folder_path);

            writeln(format(">> %s block start", blocks_info.amount-j));
            
            writeln("Fingerprint:\n", Fingerprint.format(current_block.fingerprint));
            const bullseye = current_block.bullseye;
            if (bullseye.empty)
                writeln("Bullseye: <empty>");
            else
                writeln("Bullseye:\n", Fingerprint.format(bullseye));

            writeln(format("<< %s block end\n", blocks_info.amount-j));

            fingerprint = current_block.chain;
        }
    }

    void onRollback() {
        auto blocks_info = EpochBlockFileDataBase.getBlocksInfo(folder_path);
        if (rollback > blocks_info.amount)
            rollback = blocks_info.amount;

        writeln("Rollback for ", rollback, " steps\n");

        if (!exists(folder_path)) {
            writeln(format("File '%s' don't exist, failed to rollback. Abort"));
        }

        DART db = new DART(net, dartfilename, fromAngle, toAngle);

        Buffer fingerprint = blocks_info.last.fingerprint;
        foreach (j; 0..rollback) {
            writefln("Current rollback: %d", rollback-j);

            const current_block = EpochBlockFileDataBase.readBlockFromFingerprint(fingerprint, folder_path);

            writeln("Current block bullseye:\n", Fingerprint.format(current_block.bullseye));
            writeln("DB fingerprint:\n", Fingerprint.format(db.fingerprint));

            // Add flipped recorder to DB
            addRecordToDB(db, EpochBlockFileDataBase.getFlippedRecorder(current_block), hirpc);
            // Remove local file with this block
            EpochBlockFileDataBase.makePath(fingerprint, folder_path).remove;

            fingerprint = current_block.chain;
        }
    }

    try {
        // Calling --help or -h
        if (cli_args_config.helpWanted)
            return onHelp;

        // Should be the first action
        if (init_count > 0) onInit;

        if (print) onPrint;

        if (rollback > 0) onRollback;

        // Last action in work
        if (clean) {
            rmdirRecurse(folder_path);
            writeln(format("Cleaned files in '%s'", folder_path));
        }
    }
    catch (Exception e) {
        // Might be:
        // std.getopt.GetOptException for unrecoginzed option
        // std.conv.ConvException for unexpected values for option recognized
        writeln(e);
        return 1;
    }
    return 0;
}