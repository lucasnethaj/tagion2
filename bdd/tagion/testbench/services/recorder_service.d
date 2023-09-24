module tagion.testbench.services.recorder_service;
// Default import list for bdd
import tagion.behaviour;
import tagion.hibon.Document;
import std.typecons : Tuple;
import tagion.testbench.tools.Environment;
import tagion.services.replicator;
import tagion.crypto.SecureInterfaceNet;
import tagion.crypto.SecureNet : StdSecureNet;
import tagion.actor;
import tagion.utils.pretend_safe_concurrency;
import tagion.testbench.dart.dart_helper_functions;
import tagion.services.messages;
import tagion.crypto.Types;
import tagion.dart.Recorder;
import tagion.hibon.HiBONRecord;
import tagion.recorderchain.RecorderChainBlock : RecorderChainBlock;
import tagion.recorderchain.RecorderChain;

import std.algorithm;
import std.random;
import std.array;
import std.stdio;

enum feature = Feature(
            "Recorder chain service",
            [
        "This services should store the recorder for each epoch in chain as a file.",
        "This is an extension of the Recorder backup chain."
]);

alias FeatureContext = Tuple!(
        StoreOfTheRecorderChain, "StoreOfTheRecorderChain",
        FeatureGroup*, "result"
);

@safe @Scenario("store of the recorder chain",
        [])
class StoreOfTheRecorderChain {
    immutable(ReplicatorOptions) replicator_opts;
    SecureNet replicator_net;
    ReplicatorServiceHandle handle;
    Mt19937 gen;
    RandomArchives random_archives;
    RecordFactory.Recorder insert_recorder;
    Document[] docs;
    RecordFactory record_factory;
    RecorderChainBlock block;

    struct SimpleDoc {
        ulong n;
        mixin HiBONRecord!(q{
            this(ulong n) {
                this.n = n;
            }
        });
    }

    this(immutable(ReplicatorOptions) replicator_opts) {
        this.replicator_opts = replicator_opts;
        replicator_net = new StdSecureNet();
        record_factory = RecordFactory(replicator_net);
        replicator_net.generateKeyPair("recordernet very secret");
        gen = Mt19937(4321);
    }
    

    @Given("a epoch recorder with epoch number has been received")
    Document received() {
        thisActor.task_name = "recorder_supervisor";
        register(thisActor.task_name, thisTid);
        handle = (() @trusted => spawn!ReplicatorService("ReplicatorService", replicator_opts, cast(immutable) replicator_net))();
        waitforChildren(Ctrl.ALIVE);


        random_archives = RandomArchives(gen.front, 4, 10);
        insert_recorder = record_factory.recorder;
        docs = (() @trusted => cast(Document[]) random_archives.values.map!(a => SimpleDoc(a).toDoc).array)();

        insert_recorder.insert(docs, Archive.Type.ADD);
        auto send_recorder = SendRecorder();

        Fingerprint dummy_bullseye = Fingerprint([1,2,3,4]);
        block = new RecorderChainBlock(insert_recorder.toDoc, Fingerprint.init, dummy_bullseye,0, replicator_net);


        (() @trusted => handle.send(send_recorder, cast(immutable) insert_recorder, dummy_bullseye, immutable int(0)))();

        import core.thread;
        import core.time;
        (() @trusted => Thread.sleep(5.msecs))();

        return result_ok;
    }

    @When("the recorder has been store to a file")
    Document file() @trusted {
        RecorderChainStorage storage = new RecorderChainFileStorage(replicator_opts.folder_path, replicator_net);
        RecorderChain recorder_chain = new RecorderChain(storage);

        check(recorder_chain.getLastBlock.getHash == block.getHash, "read block not the same");
        return result_ok;
    }

    @Then("the file should be checked")
    Document checked() {
        handle.send(Sig.STOP);
        waitforChildren(Ctrl.END);
        return result_ok;
    }

}
