/// Consensus HashGraph main object 
module tagion.testbench.hashgraph.hashgraph_test_network;

import std.format;
import std.range;
import std.algorithm;

import tagion.logger.Logger : log;
import tagion.basic.Types : Buffer;
import tagion.crypto.Types;
import tagion.hashgraph.HashGraph;
import tagion.hashgraph.HashGraphBasic;
import tagion.hashgraph.Event;
import tagion.communication.HiRPC;
import tagion.utils.StdTime;
import tagion.utils.Miscellaneous : cutHex;
import tagion.hibon.Document;
import tagion.hibon.HiBONRecord;
import tagion.hibon.HiBON;
import std.stdio;
import std.exception : assumeWontThrow;
import core.memory : pageSize;
import tagion.utils.BitMask;
import std.conv;

/++
    This function makes sure that the HashGraph has all the events connected to this event
+/
@safe
static class TestNetwork { //(NodeList) if (is(NodeList == enum)) {
    import core.thread.fiber : Fiber;
    import tagion.crypto.SecureNet : StdSecureNet;

    import tagion.crypto.SecureInterfaceNet : SecureNet;
    import tagion.gossip.InterfaceNet : GossipNet;
    import tagion.utils.Random;
    import tagion.utils.Queue;
    import tagion.hibon.HiBONJSON;
    import std.datetime.systime : SysTime;
    import core.time;

    TestGossipNet authorising;
    Random!size_t random;
    SysTime global_time;
    enum timestep {
        MIN = 50,
        MAX = 150
    }

    Pubkey[int] excluded_nodes_history;

    static const(SecureNet) verify_net;
    static this() {
        verify_net = new StdSecureNet();
    }

    Pubkey current;

    alias ChannelQueue = Queue!Document;
    class TestGossipNet : GossipNet {
        import tagion.hashgraph.HashGraphBasic;

        ChannelQueue[Pubkey] channel_queues;
        sdt_t _current_time;

        void start_listening() {
            // empty
        }

        @property
        void time(const(sdt_t) t) {
            _current_time = sdt_t(t);
        }

        @property
        const(sdt_t) time() pure const {
            return _current_time;
        }

        bool isValidChannel(const(Pubkey) channel) const pure nothrow {
            return (channel in channel_queues) !is null;
        }

        void send(const(Pubkey) channel, const(HiRPC.Sender) sender) {
            const wave = Wavefront(verify_net, sender.method.params);
            // writefln("owner %s, state=%s", sender.pubkey.cutHex, wave.state);
            const doc = sender.toDoc;
            // assumeWontThrow(writefln("SENDER: send to %s, doc=%s", channel.cutHex, doc.toPretty));
            channel_queues[channel].write(doc);
        }

        void send(const(Pubkey) channel, const(Document) doc) nothrow {
            // assumeWontThrow(writefln("DOC: send to %s, document=%s", channel.cutHex, doc.toPretty));
            channel_queues[channel].write(doc);
        }

        final void send(T)(const(Pubkey) channel, T pack) if (isHiBONRecord!T) {
            send(channel, pack.toDoc);
        }

        const(Document) receive(const Pubkey channel) nothrow {
            return channel_queues[channel].read;
        }

        void close() {
            // Dummy empty
        }

        const(Pubkey) select_channel(ChannelFilter channel_filter) {
            foreach (count; 0 .. channel_queues.length / 2) {
                const node_index = random.value(0, channel_queues.length);
                const send_channel = channel_queues
                    .byKey
                    .dropExactly(node_index)
                    .front;
                if (channel_filter(send_channel)) {
                    return send_channel;
                }
            }
            return Pubkey();
        }

        const(Pubkey) gossip(
                ChannelFilter channel_filter,
                SenderCallBack sender) {
            const send_channel = select_channel(channel_filter);
            if (send_channel.length) {
                send(send_channel, sender());
            }
            return send_channel;
        }

        bool empty(const Pubkey channel) const pure nothrow {
            return channel_queues[channel].empty;
        }

        void add_channel(const Pubkey channel) {
            channel_queues[channel] = new ChannelQueue;
        }

        void remove_channel(const Pubkey channel) {
            channel_queues.remove(channel);
        }
    }

    class FiberNetwork : Fiber {
        HashGraph _hashgraph;
        //immutable(string) name;
        @trusted
        this(HashGraph h, const(ulong) stacksize = pageSize * Fiber.defaultStackPages) nothrow
        in {
            assert(_hashgraph is null);
        }
        do {
            super(&run, stacksize);
            _hashgraph = h;
        }

        const(HashGraph) hashgraph() const pure nothrow {
            return _hashgraph;
        }

        sdt_t time() {
            const systime = global_time + random.value(timestep.MIN, timestep.MAX).msecs;
            const sdt_time = sdt_t(systime.stdTime);
            return sdt_time;
        }

        private void run() {
            { // Eva Event
                immutable buf = cast(Buffer) _hashgraph.channel;
                const nonce = cast(Buffer) _hashgraph.hirpc.net.calcHash(buf);
                auto eva_event = _hashgraph.createEvaEvent(time, nonce);

                if (eva_event is null) {
                    log.error("The channel of this oner is not valid");
                    return;
                }
            }
            uint count;
            bool stop;
            const(Document) payload() @safe {
                auto h = new HiBON;
                h["node"] = format("%s-%d", _hashgraph.name, count);
                return Document(h);
            }

            while (!stop) {
                while (!authorising.empty(_hashgraph.channel)) {
                    const received = _hashgraph.hirpc.receive(
                            authorising.receive(_hashgraph.channel));

                    _hashgraph.wavefront(
                            received,
                            time,
                            (const(HiRPC.Sender) return_wavefront) @safe {
                        authorising.send(received.pubkey, return_wavefront);
                    },
                            &payload
                    );
                    count++;
                }
                (() @trusted { yield; })();
                //const onLine=_hashgraph.areWeOnline;
                const init_tide = random.value(0, 2) is 1;
                if (init_tide) {
                    _hashgraph.init_tide(
                            &authorising.gossip,
                            &payload,
                            time);
                    count++;
                }
            }
        }
    }

    @trusted
    const(Pubkey[]) channels() const pure nothrow {
        return networks.keys;
    }

    bool allCoherent() {
        return networks
            .byValue
            .map!(n => n._hashgraph.owner_node.sticky_state)
            .all!(s => s == ExchangeState.COHERENT);
    }

    FiberNetwork[Pubkey] networks;

    struct Epoch {
        const(Event)[] events;
        sdt_t epoch_time;
    }

    Epoch[][Pubkey] epoch_events;
    void epochCallback(const(Event[]) events, const sdt_t epoch_time) {
        pragma(msg, typeof(current));
        auto epoch = Epoch(events, epoch_time);
        epoch_events[current] ~= epoch;
    }

    @safe
    void excludedNodesCallback(ref BitMask excluded_mask, const(HashGraph) hashgraph) {
        import tagion.basic.Debug;

        if (excluded_nodes_history is null) { return; }
        
        
        const last_decided_round = hashgraph.rounds.last_decided_round.number;
        const exclude_channel = excluded_nodes_history.get(last_decided_round, Pubkey.init);
        if (exclude_channel !is Pubkey.init) {
            const node = hashgraph.nodes.get(exclude_channel, HashGraph.Node.init);
            if (node !is HashGraph.Node.init) {
                excluded_mask[node.node_id] = !excluded_mask[node.node_id]; 
            }
        }
        
        // const mask = excluded_nodes_history.get(last_decided_round, );
        // if (mask !is BitMask.init) {
        //     excluded_mask = mask;
        // }

        __write("callback<%s>", excluded_mask);

    }

    this(const(string[]) node_names) {
        authorising = new TestGossipNet;
        immutable N = node_names.length; //EnumMembers!NodeList.length;
        foreach (name; node_names) {
            immutable passphrase = format("very secret %s", name);
            auto net = new StdSecureNet();
            net.generateKeyPair(passphrase);
            auto h = new HashGraph(N, net, &authorising.isValidChannel, &epochCallback, null, &excludedNodesCallback, name);
            h.scrap_depth = 0;
            networks[net.pubkey] = new FiberNetwork(h, pageSize * 256);
        }
        networks.byKey.each!((a) => authorising.add_channel(a));
    }
}

import tagion.hashgraphview.Compare;
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



