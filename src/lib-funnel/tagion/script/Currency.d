module tagion.script.Currency;
import std.algorithm.searching : canFind;

import std.traits : isIntegral, isNumeric, isFloatingPoint;
import std.range : only;
import std.format;
import tagion.hibon.HiBONRecord : HiBONRecord, label, recordType;

@safe
struct Currency(string _UNIT, long _BASE_UNIT = 1_000_000_000, long MAX_VALUE_IN_BASE_UNITS = 1_000_000_000) {
    static assert(_BASE_UNIT > 0, "Base unit must be positive");
    static assert(UNIT_MAX > 0, "Max unit mist be positive");
    enum long BASE_UNIT = _BASE_UNIT;
    enum long UNIT_MAX = MAX_VALUE_IN_BASE_UNITS * BASE_UNIT;
    enum UNIT = _UNIT;
    enum type_name = _UNIT;
    protected {
        @label("$v") long _units;
    }

    mixin HiBONRecord!(
            q{
            this(T)(T tagions) pure if (isFloatingPoint!T) {
                scope(exit) {
                    check_range;
                }
                _units = cast(long)(tagions * BASE_UNIT);
            }

            this(T)(const T units) pure if (isIntegral!T) {
                scope(exit) {
                    check_range;
                }
                _units = units;
            }
        });

    bool verify() const pure nothrow {
        return _units > -UNIT_MAX && _units < UNIT_MAX;
    }

    void check_range() const pure {
        import tagion.script.ScriptException : scriptCheck = check;

        scriptCheck(_units > -UNIT_MAX && _units < UNIT_MAX,
                format("Value out of range [%s:%s] value is %s",
                toTagion(-UNIT_MAX),
                toTagion(UNIT_MAX),
                toTagion(_units)));
    }

    Currency opBinary(string OP)(const Currency rhs) const pure
    if (
        ["+", "-", "%"].canFind(OP)) {
        enum code = format(q{return Currency(_units %1$s rhs._units);}, OP);
        mixin(code);
    }

    Currency opBinary(string OP, T)(T rhs) const pure
    if (isIntegral!T && (["+", "-", "*", "%", "/"].canFind(OP))) {
        enum code = format(q{return Currency(_units %s rhs);}, OP);
        mixin(code);
    }

    Currency opBinaryRight(string OP, T)(T left) const pure
    if (isIntegral!T && (["+", "-", "*"].canFind(OP))) {
        enum code = format(q{return Currency(left %s _units);}, OP);
        mixin(code);
    }

    Currency opUnary(string OP)() const pure if (OP == "-" || OP == "-") {
        static if (OP == "-") {
            return Currency(-_units);
        }
        else {
            return Currency(_units);
        }
    }

    void opOpAssign(string OP)(const Currency rhs) pure
    if (["+", "-", "%"].canFind(OP)) {
        scope (exit) {
            check_range;
        }
        enum code = format(q{_units %s= rhs._units;}, OP);
        mixin(code);
    }

    void opOpAssign(string OP, T)(const T rhs) pure
    if (isIntegral!T && (["+", "-", "*", "%", "/"].canFind(OP))) {
        scope (exit) {
            check_range;
        }
        enum code = format(q{_units %s= rhs;}, OP);
        mixin(code);
    }

    void opOpAssign(string OP, T)(const T rhs) pure
    if (isFloatingPoint!T && (["*", "%", "/"].canFind(OP))) {
        scope (exit) {
            check_range;
        }
        enum code = format(q{_units %s= rhs;}, OP);
        mixin(code);
    }

    pure const nothrow @nogc {

        bool opEquals(const Currency x) {
            return _units == x._units;
        }

        bool opEquals(T)(T x) if (isNumeric!T) {
            import std.math;

            static if (isFloatingPoint!T) {
                return isClose(value, x, 1e-9);
            }
            else {
                return _units == x;
            }
        }

        int opCmp(const Currency x) {
            if (_units < x._units) {
                return -1;
            }
            else if (_units > x._units) {
                return 1;
            }
            return 0;
        }

        int opCmp(T)(T x) if (isNumeric!T) {
            if (_units < x) {
                return -1;
            }
            else if (_units > x) {
                return 1;
            }
            return 0;
        }

        long axios() {
            if (_units < 0) {
                return -(-_units % BASE_UNIT);
            }
            return _units % BASE_UNIT;
        }

        long tagions() {
            if (_units < 0) {
                return -(-_units / BASE_UNIT);
            }
            return _units / BASE_UNIT;
        }

        double value() {
            return double(_units) / BASE_UNIT;
        }

        T opCast(T)() {
            static if (is(Unqual!T == double)) {
                return value;
            }
            else {
                static assert(0, format("%s casting is not supported", T.stringof));
            }
        }

    }

    static string toTagion(const long units) pure {
        long value = units;
        if (units < 0) {
            value = -value;
        }
        const sign = (units < 0) ? "-" : "";
        return only(sign, (value / BASE_UNIT).to!string, ".", (value % BASE_UNIT).to!string).join;
    }

    string toString() {
        return toTagion(_units);
    }
}
