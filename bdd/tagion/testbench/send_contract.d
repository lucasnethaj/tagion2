module tagion.testbench.send_contract;
import tagion.tools.Basic;
import tagion.behaviour.Behaviour;
import tagion.testbench.services;
import tagion.testbench.tools.Environment;
import std.file;

import std.path : setExtension, buildPath;
import tagion.basic.Types : FileExtension;

import tagion.services.options;
import core.time;
import core.thread;
import std.stdio;

import neuewelle = tagion.tools.neuewelle;

import tagion.utils.pretend_safe_concurrency;
import tagion.GlobalSignals;

mixin Main!(_main);

void wrap_neuewelle(immutable(string)[] args) {
    neuewelle._main(cast(string[]) args);
}


int _main(string[] args) {
    auto module_path = env.bdd_log.buildPath(__MODULE__);
    if (module_path.exists) {
        rmdirRecurse(module_path);
    }
    mkdirRecurse(module_path);
    string config_file = buildPath(module_path, "tagionwave.json");

    scope Options local_options = Options.defaultOptions;
    local_options.dart.folder_path = buildPath(module_path);
    local_options.replicator.folder_path = buildPath(module_path);
    local_options.save(config_file);

    import std.format;
    import std.range;
    import std.array;
    import std.algorithm;
    import std.stdio;
    import tagion.crypto.SecureNet : StdSecureNet;
    import tagion.crypto.SecureInterfaceNet;
    import tagion.dart.DARTFile;
    import tagion.dart.DART;
    import tagion.wallet.SecureWallet;
    import tagion.script.common : TagionBill;
    import tagion.testbench.services.sendcontract;
    import tagion.script.TagionCurrency;
    import tagion.dart.Recorder;

    StdSecureWallet[] wallets;
    // create the wallets
    foreach(i; 0..10) {
        StdSecureWallet secure_wallet;
        secure_wallet = StdSecureWallet.createWallet(
            iota(0,5).map!(n => format("%dquestion%d", i, n)).array,
            iota(0,5).map!(n => format("%danswer%d", i, n)).array,
            4,
            format("%04d", i),
        );
        wallets ~= secure_wallet;
    }

    // bills for the dart on startup
    TagionBill[] bills;
    foreach(ref wallet; wallets) {
        auto bill = wallet.requestBill(1000.TGN);
        bills ~= bill;
    }

    // create the recorder
    SecureNet net = new StdSecureNet();
    net.generateKeyPair("very_secret");

    auto factory = RecordFactory(net);
    auto recorder = factory.recorder;
    recorder.insert(bills, Archive.Type.ADD);

    string dart_interface_sock_addr;
    string inputvalidator_sock_addr;
    // create the databases
    foreach(i; 0..local_options.wave.number_of_nodes) {
        immutable prefix = format(local_options.wave.prefix_format, i);

        if (i == 0) {
            auto _opts = Options(local_options);
            _opts.setPrefix(prefix);
            dart_interface_sock_addr = _opts.dart_interface.sock_addr;
            inputvalidator_sock_addr = _opts.inputvalidator.sock_addr;
        }        
        const path = buildPath(local_options.dart.folder_path, prefix ~ local_options.dart.dart_filename);
        writeln(path);
        DARTFile.create(path, net);
        auto db = new DART(net, path);
        db.modify(recorder);
    }

    
    import tagion.services.DARTInterface : dartinterface_dart;
    dartinterface_dart = "Node_0_dart";
    

    immutable neuewelle_args = [config_file];
    auto tid = spawn(&wrap_neuewelle, neuewelle_args);
    Thread.sleep(15.seconds);


    auto send_contract_feature = automation!(sendcontract);
    send_contract_feature.SendASingleTransactionFromAWalletToAnotherWallet(local_options, wallets, dart_interface_sock_addr, inputvalidator_sock_addr); 
    send_contract_feature.run();
    Thread.sleep(5.seconds);


    stopsignal.set;

    return 0;

}
