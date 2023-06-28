module tagion.testbench.hashgraph.synchron_network;
// Default import list for bdd
import tagion.behaviour;
import tagion.hibon.Document;
import std.typecons : Tuple;
import tagion.testbench.tools.Environment;
import std.stdio;
import tagion.testbench.hashgraph.hashgraph_test_network;
import std.algorithm;
import std.datetime;
import tagion.crypto.Types : Pubkey;
import tagion.hashgraph.HashGraph;
import std.array;
import core.sys.posix.sys.resource;
import std.path : buildPath;
import std.path : setExtension, extension;
import tagion.basic.Types : FileExtension;
import std.range;
import std.array;
import tagion.utils.Miscellaneous : cutHex;
import tagion.hashgraph.HashGraphBasic;
import tagion.hashgraphview.Compare;
import tagion.hashgraph.Event;
import std.format;
import std.exception;
import std.conv;
import tagion.hibon.HiBONJSON;
import tagion.utils.Miscellaneous : toHexString;
import tagion.basic.basic;

enum feature = Feature(
            "Bootstrap of hashgraph",
            []);

alias FeatureContext = Tuple!(
        StartNetworkWithNAmountOfNodes, "StartNetworkWithNAmountOfNodes",
        FeatureGroup*, "result"
);

@safe @Scenario("Start network with n amount of nodes",
        [])
class StartNetworkWithNAmountOfNodes {
    string[] node_names;
    TestNetwork network;
    string module_path;
    const(uint) MAX_CALLS = 5000;
    this(string[] node_names, const(string) module_path) {
        this.node_names = node_names;
        this.module_path = module_path;
    }

    bool coherent;

    bool allCoherent() {
        writeln(node_names);    
        return network.networks
                .byValue
                .map!(n => n._hashgraph.owner_node.sticky_state)
                .all!(s => s == ExchangeState.COHERENT);
    }

    void printStates() {
        foreach(channel; network.channels) {
            writeln("----------------------");
            foreach (channel_key; network.channels) {
                const current_hashgraph = network.networks[channel_key]._hashgraph;
                writef("%16s %10s ingraph:%5s|", channel_key.cutHex, current_hashgraph.owner_node.sticky_state, current_hashgraph.areWeInGraph);
                foreach (receiver_key; network.channels) {
                    const node = current_hashgraph.nodes.get(receiver_key, null);                
                    const state = (node is null) ? ExchangeState.NONE : node.state;
                    writef("%15s %s", state, node is null ? "X" : " ");
                }
                writeln;
            }
        }
    
    }

    bool event_error(const Event e1, const Event e2, const Compare.ErrorCode code) @safe nothrow {
        static string print(const Event e) nothrow {
            if (e) {
                const round_received = (e.round_received) ? e.round_received.number.to!string : "#";
                return assumeWontThrow(format("(%d:%d:%d:r=%d:rr=%s:%s)",
                        e.id, e.node_id, e.altitude, e.round.number, round_received,
                        e.fingerprint.cutHex));
            }
            return assumeWontThrow(format("(%d:%d:%s:%s)", 0, -1, 0, "nil"));
        }

        assumeWontThrow(writefln("Event %s and %s %s", print(e1), print(e2), code));
        return false;
    }

    
    @Given("i have a HashGraph TestNetwork with n number of nodes")
    Document nodes() {
        rlimit limit;
        (() @trusted { getrlimit(RLIMIT_STACK, &limit); })();
        writefln("RESOURCE LIMIT = %s", limit);

        network = new TestNetwork(node_names);
        network.networks.byValue.each!((ref _net) => _net._hashgraph.scrap_depth = 0);
        network.random.seed(123456789);
        writeln(network.random);

        network.global_time = SysTime.fromUnixTime(1_614_355_286);

        return result_ok;
    }

    @When("the network has started")
    Document started() {

        try {
            foreach (channel; network.channels) {
                auto current = network.networks[channel];
                (() @trusted { current.call; })();
            }
        }
        catch (Exception e) {
            check(false, e.msg);
        }
        return result_ok;

    }

    @When("all nodes are sending ripples")
    Document ripples() {
        try {
            foreach (i; 0 .. 1000) {
                const channel_number = network.random.value(0, network.channels.length);
                const channel = network.channels[channel_number];
                auto current = network.networks[channel];
                (() @trusted { current.call; })();

                printStates();
                if (allCoherent) {
                    coherent = true;
                    break;
                }
            }
        }
        catch (Exception e) {
            check(false, e.msg);
        }
        


        return result_ok;
    }

    @When("all nodes are coherent")
    Document _coherent() {
        check(coherent, "Nodes not coherent");
        return result_ok;
    }

    @Then("wait until the first epoch")
    Document epoch() @trusted
    {

        try {
            uint i = 0;
            while(i < MAX_CALLS) {
            
                const channel_number = network.random.value(0, network.channels.length);
                network.current = Pubkey(network.channels[channel_number]);
                auto current = network.networks[network.current];
                (() @trusted { current.call; })();

                // if (network.epoch_events.length == node_names.length) {
                //     // all nodes have created at least one epoch
                //     break;
                // }
                printStates();
                i++;
            }
            check(network.epoch_events.length == node_names.length, 
                format("Max calls %d reached, not all nodes have created epochs only %d", 
                MAX_CALLS, network.epoch_events.length));

        }
        catch (Exception e) {
            check(false, e.msg);
        }


        // compare ordering
        auto names = network.networks.byValue
            .map!((net) => net._hashgraph.name)
            .array.dup
            .sort
            .array;

        HashGraph[string] hashgraphs;
        foreach (net; network.networks) {
            hashgraphs[net._hashgraph.name] = net._hashgraph;
        }
        foreach (i, name_h1; names[0 .. $ - 1]) {
            const h1 = hashgraphs[name_h1];
            foreach (name_h2; names[i + 1 .. $]) {
                const h2 = hashgraphs[name_h2];
                auto comp = Compare(h1, h2, &event_error);
                // writefln("%s %s round_offset=%d order_offset=%d",
                //     h1.name, h2.name, comp.round_offset, comp.order_offset);
                const result = comp.compare;
                check(result, format("HashGraph %s and %s is not the same", h1.name, h2.name));
            }
        }
        // compare epochs
        foreach(i, compare_epoch; network.epoch_events.byKeyValue.front.value) {
            auto compare_events = compare_epoch
                                            .events
                                            .map!(e => e.event_package.fingerprint)
                                            .array;
            // compare_events.sort!((a,b) => a < b);
            // compare_events.each!writeln;
            writefln("%s", compare_events.map!(f => f.cutHex));
            foreach(channel_epoch; network.epoch_events.byKeyValue) {
                writefln("epoch: %s", i);
                auto events = channel_epoch.value[i]
                                            .events
                                            .map!(e => e.event_package.fingerprint)
                                            .array;
                // events.sort!((a,b) => a < b);

                writefln("%s", events.map!(f => f.cutHex));
                // events.each!writeln;
                writefln("channel %s time: %s", channel_epoch.key.cutHex, channel_epoch.value[i].epoch_time);
                               
                check(compare_events.length == events.length, "event_packages not the same length");

                const isSame = equal(compare_events, events);
                writefln("isSame: %s", isSame);
                check(isSame, "event_packages not the same");            
            
            }
        }        

        return result_ok;
    }

    @Then("stop the network")
    Document _network() {
        // create ripple files.
        Pubkey[string] node_labels;
        foreach (channel, _net; network.networks) {
            node_labels[_net._hashgraph.name] = channel;
        }
        foreach (_net; network.networks) {
            const filename = buildPath(module_path, "ripple-" ~ _net._hashgraph.name.setExtension(FileExtension.hibon));
            writeln(filename);
            _net._hashgraph.fwrite(filename, node_labels);
        }
        return result_ok;
    }

}
