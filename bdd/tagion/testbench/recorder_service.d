module tagion.testbench.recorder_service;


import tagion.tools.Basic;
import tagion.behaviour.Behaviour;
import tagion.testbench.services;
import tagion.testbench.tools.Environment;
import std.file;
import std.path : buildPath;

import tagion.services.recorder : RecorderOptions;


mixin Main!(_main);


int _main(string [] args) {
    auto module_path = env.bdd_log.buildPath(__MODULE__);
    rmdirRecurse(module_path);
    mkdirRecurse(module_path);
    immutable opts = RecorderOptions(module_path);
    auto recorder_service_feature = automation!(recorder_service);
    recorder_service_feature.StoreOfTheRecorderChain(opts); 
    recorder_service_feature.run();
    return 0;


}