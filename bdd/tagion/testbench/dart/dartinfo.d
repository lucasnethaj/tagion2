module tagion.testbench.dart.dartinfo;
import tagion.crypto.SecureInterfaceNet : SecureNet;
import tagion.communication.HiRPC : HiRPC;
import tagion.utils.Random;
import std.range;
import std.stdio;

import std.algorithm.iteration : each;

struct DartInfo {
    const string dartfilename;
    const string module_path;
    const SecureNet net;
    const HiRPC hirpc;
    const string dartfilename2;


    const ulong[] table = [
        0xABB9_13ab_cdef_1234,
        0xABB9_14ab_cdef_1234,
        0xABB9_15ab_cdef_1234
    ];

    const ulong[] deep_table = [
        0xABB9_13ab_10ef_1234,
        0xABB9_13ab_11ef_1234,
        0xABB9_14ab_cdef_1234,
    ];

    const enum FAKE = "$fake#";

    auto generateStates(const uint from, const uint to) {
       auto rnd = RandomT(0x1234);
       return recurrence!(
            (a, n) =>
            a[n-1].progress(rnd.value(from,to))
        )(SequenceT(rnd.save, from));
    }
    SequenceT[] states;
    


}

alias RandomT = Random!ulong;
alias SequenceT = Sequence!ulong;

