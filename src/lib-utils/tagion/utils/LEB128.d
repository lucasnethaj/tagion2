module tagion.utils.LEB128;

import traits=std.traits : isSigned, isUnsigned, isIntegral;
import std.typecons;
import std.format;
import tagion.basic.TagionExceptions;
import std.algorithm.comparison : min;
import std.algorithm.iteration : map, sum;
//import std.stdio;

@safe
class LEB128Exception : TagionException {
    this(string msg, string file = __FILE__, size_t line = __LINE__ ) pure {
        super( msg, file, line );
    }
}

alias check=Check!LEB128Exception;

@safe
size_t calc_size(const(ubyte[]) data) pure {
    foreach(i, d;data) {
        if ((d & 0x80) == 0) {
            check(i <= ulong.sizeof+1, "LEB128 overflow");
            return i+1;
        }
    }
    check(0, "LEB128 bad format");
    assert(0);
}

@safe
size_t calc_size(T)(const T v) pure if(isUnsigned!(T)) {
    size_t result;
    ulong value=v;
    do {
        result++;
        value >>= 7;
    } while (value);
    return result;
}

@safe
size_t calc_size(T)(const T v) pure if(isSigned!(T)) {
    if (v == T.min) {
        return T.sizeof+(is(T==int)?1:2);
    }
    ulong value=ulong((v < 0)?-v:v);
    static if (is(T==long)) {
        if ((value >> (long.sizeof*8 - 2)) == 1UL) {
            return long.sizeof+2;
        }
    }
    size_t result;
    auto uv=(v < 0)?-v:v;
    T nv=-v;

    do {
        result++;
        value >>= 7;
    } while (value);
    return result;
}

@safe
immutable(ubyte[]) encode(T)(const T v) pure if(isUnsigned!T && isIntegral!T) {
    ubyte[T.sizeof+2] data;
    alias BaseT=TypedefType!T;
    BaseT value=cast(BaseT)v;
    foreach(i, ref d; data) {
        d = value & 0x7f;
        value >>= 7;
        if (value == 0) {
            return data[0..i+1].idup;
        }
        d |= 0x80;
    }
    assert(0);
}

@safe
immutable(ubyte[]) encode(T)(const T v) pure if(isSigned!T && isIntegral!T) {
    enum DATA_SIZE=(T.sizeof*9+1)/8+1;
    ubyte[DATA_SIZE] data;
    if (v == T.min) {
        foreach(ref d; data[0..$-1]) {
            d=0x80;
        }
        data[$-1]=(T.min >> (7*(DATA_SIZE-1))) & 0x7F;
        return data.dup;
    }
    T value=v;
    foreach(i, ref d; data) {
        d = value & 0x7f;
        value >>= 7;
        /* sign bit of byte is second high order bit (0x40) */
        if (((value == 0) && !(d & 0x40)) || ((value == -1) && (d & 0x40))) {
            return data[0..i+1].idup;
        }
        d |= 0x80;
    }
    check(0, "Bad LEB128 format");
    assert(0);
}

alias DecodeLEB128(T)=Tuple!(T, "value", size_t, "size");

@safe
DecodeLEB128!T decode(T=ulong)(const(ubyte[]) data) pure if (isUnsigned!T) {
    alias BaseT=TypedefType!T;
    ulong result;
    uint shift;
    enum MAX_LIMIT=T.sizeof*8;
    size_t len;
    foreach(i, d; data) {
        check(shift < MAX_LIMIT,
            format("LEB128 decoding buffer over limit of %d %d", MAX_LIMIT, shift));

        result |= (d & 0x7FUL) << shift;
        if ((d & 0x80) == 0) {
            len=i+1;
            static if (!is(BaseT==ulong)) {
                check(result <= BaseT.max, format("LEB128 decoding overflow of %x for %s", result, T.stringof));
            }
            return DecodeLEB128!T(cast(BaseT)result, len);
        }
        shift+=7;
    }
    check(0, format("Bad LEB128 format for type %s data=%s", T.stringof, data[0..min(MAX_LIMIT,data.length)]));
    assert(0);
}

@safe
DecodeLEB128!T decode(T=long)(const(ubyte[]) data) pure if (isSigned!T) {
    alias BaseT=TypedefType!T;
    long result;
    uint shift;
    enum MAX_LIMIT=T.sizeof*8;
    size_t len;
    foreach(i, d; data) {
        check(shift < MAX_LIMIT, "LEB128 decoding buffer over limit");
        result |= (d & 0x7FL) << shift;
        shift+=7;
        if ((d & 0x80) == 0 ) {
            if ((shift < long.sizeof*8) && ((d & 0x40) != 0)) {
                result |= (~0L << shift);
            }
            len=i+1;
            static if (!is(BaseT==long)) {
                check((T.min <= result) && (result <= T.max),
                    format("LEB128 out of range %d for %s", result, T.stringof));
            }
            return DecodeLEB128!T(cast(BaseT)result, len);
        }
    }
    check(0, format("Bad LEB128 format for type %s data=%s", T.stringof, data[0..min(MAX_LIMIT,data.length)]));
    assert(0);
}

///
unittest {
    import std.algorithm.comparison : equal;
    void ok(T)(T x, const(ubyte[]) expected) {
        const encoded=encode(x);
        assert(equal(encoded, expected));
        assert(calc_size(x) == expected.length);
        assert(calc_size(expected) == expected.length);
        const decoded=decode!T(expected);
        assert(decoded.size == expected.length);
        assert(decoded.value == x);
    }

    {
        ok!int(int.max, [255, 255, 255, 255, 7]);
        ok!ulong(27, [27]);
        ok!ulong(2727, [167, 21]);
        ok!ulong(272727, [215, 210, 16]);
        ok!ulong(27272727,  [151, 204, 128, 13]);
        ok!ulong(1427449141, [181, 202, 212, 168, 5]);
        ok!ulong(ulong.max, [255, 255, 255, 255, 255, 255, 255, 255, 255, 1]);
    }

    {
        ok!int(-1, [127]);
        ok!int(int.max, [255, 255, 255, 255, 7]);
        ok!int(int.min, [128, 128, 128, 128, 120]);
        ok!int(int.max, [255, 255, 255, 255, 7]);
        ok!long(int.min, [128, 128, 128, 128, 120]);
        ok!long(int.max, [255, 255, 255, 255, 7]);

        ok!long(27, [27]);
        ok!long(2727, [167, 21]);
        ok!long(272727, [215, 210, 16]);
        ok!long(27272727,  [151, 204, 128, 13]);
        ok!long(1427449141, [181, 202, 212, 168, 5]);

        ok!int(-123456, [192, 187, 120]);
        ok!long(-27, [101]);
        ok!long(-2727,[217, 106]);
        ok!long(-272727, [169, 173, 111]);
        ok!long(-27272727,   [233, 179, 255, 114]);
        ok!long(-1427449141L, [203, 181, 171, 215, 122]);


        ok!long(-1L, [127]);
        ok!long(long.max-1, [254, 255, 255, 255, 255, 255, 255, 255, 255, 0]);
        ok!long(long.max, [255, 255, 255, 255, 255, 255, 255, 255, 255, 0]);
        ok!long(long.min+1, [129, 128, 128, 128, 128, 128, 128, 128, 128, 127]);
        ok!long(long.min  , [128, 128, 128, 128, 128, 128, 128, 128, 128, 127]);
    }

    {
        assert(decode!int([127]).value == -1);
    }
}
