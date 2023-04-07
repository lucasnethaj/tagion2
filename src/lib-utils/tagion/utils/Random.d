/// Pseudo random range
module tagion.utils.Random;
import std.format;
import std.range;


/// Generates a pseudo random sequence
@safe @nogc
struct Random(T = uint) {
    @nogc {
        private T m_z;
        private T m_w;
        this(const T seed_value) pure nothrow {
            seed(seed_value);
        }

        private this(T m_z, T m_w) pure nothrow {
            this.m_z = m_z;
            this.m_w = m_w;
        }

    /**
     * 
     * Params:
     *   seed_value = is the seend of the pseudo random
     */
        void seed(const T seed_value) pure nothrow {
            m_z = 13 * seed_value;
            m_w = 7 * seed_value;
        }

        /**
         *  
         * Returns: next random value 
         */
        T value() {
            popFront;
            return front;
        }

        /**
         * 
         * Params:
         *   max = sets the max value
         * Returns: 
         *   next random value less than max
         */
        T value(const(T) max) {
            return value % max;
        }

        /**
         * 
         * Params:
         *   from = start value
         *   to = until value
         * Returns: random value in the range from..to
         */
        T value(const(T) from, const(T) to)
        in {
            assert(to > from);
        }
        do {
            immutable range = to - from;
            return (value % range) + from;
        }

        /**
         * pops the next random value
         */
        void popFront() pure nothrow {
            m_z = 36_969 * (m_z & T.max) + (m_z >> 16);
            m_w = 18_000 * (m_w & T.max) + (m_w >> 16);
        }

        /**
         * 
         * Returns: current random value 
         */
        T front() const pure nothrow {
            return (m_z << 16) + m_w;
        }

        enum bool empty = false;

        /**
         * Saves the forward range
         * Returns: new random 
         */
        Random save() const pure nothrow {
            return Random(m_z, m_w);
        }

        import std.range.primitives : isInputRange, isForwardRange, isInfinite;

        static assert(isInputRange!(Random));
        static assert(isForwardRange!(Random));
        static assert(isInfinite!(Random));
    }
    /**
     * 
     * Returns: inner parameter for the random sequnece 
     */
    string toString() const pure {
        return format("m_z %s, m_w %s, value %s", m_z, m_w, front);
    }

}


///
@safe
unittest {
    import std.range : take, drop;
    import std.algorithm.comparison : equal;

    auto r = Random!uint(1234);
    auto r_forward = r.save;

    assert(equal(r.take(5), r_forward.take(5)));

    r = r.drop(7);
    assert(r != r_forward);
    r_forward = r.save;
    assert(r == r_forward);
    assert(equal(r.take(4), r_forward.take(4)));
}

/// This data type can be used to group a sequence of pseudo random sequency
@nogc @safe
struct Sequence(T = uint) {
    import std.range;

    Random!T rand;
    T size;
    /** 
     * Returns: sequence of random numbers
     */
    auto list() const pure nothrow {
        return rand.save.take(size);
    }

    /**
     * Progress the random sequency next_size creates a new sequency
     * Params:
     *   next_size = the number of random to the next sequency 
     * Returns: 
     *   the net sequence after next_size randoms
     */
    Sequence progress(T next_size) const pure nothrow {
        Sequence result;
        result.rand = rand.save.drop(size);
        result.size = next_size;
        return result;
    }
}

///
@safe
unittest {
    import std.stdio;
    import std.range;
    import std.algorithm;

    alias RandomT = Random!uint;

    enum sample = 5;
    { // Simple range of sequences with fixed size

        auto start = RandomT(1234);
        auto rand_range = recurrence!(q{
        a[n-1].drop(3)
        })(start);
        assert(equal(
                rand_range
                .take(sample)
                .map!q{a.take(3)}
                .joiner,
                start.save
                .take(sample * 3)));
    }

    { // Range of sequences with random size
        auto start = RandomT(1234);
        // Generate sequency range with variable size in the range 4..8
        auto rand_range = recurrence!(
                (a, n) =>
                a[n - 1].progress(start.value(4, 8))
        )(Sequence!uint(start.save, 5));

        // Store the begen of the random start
        auto begin = start;
        const total_number = rand_range.take(sample).map!q{a.size}.sum;
        // restore start random
        auto expected = start = begin;
        assert(equal(expected.take(total_number),
                rand_range.take(sample).map!q{a.list}.joiner));

    }

}



struct RandomArchives {
    import std.random;
    import std.random : Random;

    uint seed;
    bool in_dart;
    uint number_of_archives;

    this(const uint _seed, const uint from = 1, const uint to = 10) pure const {
        seed = _seed;
        auto rnd = Random(seed);
        number_of_archives = uniform(from, to, rnd);
    }

    auto getValues() pure nothrow @nogc {
        auto gen = Mt19937_64(seed);
        return gen.take(number_of_archives);
    }



}

unittest {
    import std.stdio;
    import std.algorithm;
    const seed = 12345UL;
    auto r = RandomArchives(seed, 1, 10);
    auto t = RandomArchives(seed, 1, 10);

    assert(r.getValues == t.getValues);
}