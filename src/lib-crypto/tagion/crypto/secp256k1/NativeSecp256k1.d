module tagion.crypto.secp256k1.NativeSecp256k1;

@safe:
private import tagion.crypto.secp256k1.c.secp256k1;
private import tagion.crypto.secp256k1.c.secp256k1_ecdh;
private import tagion.crypto.secp256k1.c.secp256k1_schnorrsig;
private import tagion.crypto.secp256k1.c.secp256k1_extrakeys;
import tagion.crypto.random.random;
import std.algorithm;
import std.array;
import tagion.basic.ConsensusExceptions;

enum SECP256K1 : uint {
    FLAGS_TYPE_MASK = SECP256K1_FLAGS_TYPE_MASK,
    FLAGS_TYPE_CONTEXT = SECP256K1_FLAGS_TYPE_CONTEXT,
    FLAGS_TYPE_COMPRESSION = SECP256K1_FLAGS_TYPE_COMPRESSION,
    /** The higher bits contain the actual data. Do not use directly. */
    FLAGS_BIT_CONTEXT_VERIFY = SECP256K1_FLAGS_BIT_CONTEXT_VERIFY,
    FLAGS_BIT_CONTEXT_SIGN = SECP256K1_FLAGS_BIT_CONTEXT_SIGN,
    FLAGS_BIT_COMPRESSION = FLAGS_BIT_CONTEXT_SIGN,

    /** Flags to pass to secp256k1_context_create. */
    CONTEXT_VERIFY = SECP256K1_CONTEXT_VERIFY,
    CONTEXT_SIGN = SECP256K1_CONTEXT_SIGN,
    CONTEXT_NONE = SECP256K1_CONTEXT_NONE,

    /** Flag to pass to secp256k1_ec_pubkey_serialize and secp256k1_ec_privkey_export. */
    EC_COMPRESSED = SECP256K1_EC_COMPRESSED,
    EC_UNCOMPRESSED = SECP256K1_EC_UNCOMPRESSED,

    /** Prefix byte used to tag various encoded curvepoints for specific purposes */
    TAG_PUBKEY_EVEN = SECP256K1_TAG_PUBKEY_EVEN,
    TAG_PUBKEY_ODD = SECP256K1_TAG_PUBKEY_ODD,
    TAG_PUBKEY_UNCOMPRESSED = SECP256K1_TAG_PUBKEY_UNCOMPRESSED,
    TAG_PUBKEY_HYBRID_EVEN = SECP256K1_TAG_PUBKEY_HYBRID_EVEN,
    TAG_PUBKEY_HYBRID_ODD = SECP256K1_TAG_PUBKEY_HYBRID_ODD
}

/++
 + <p>This class holds native methods to handle ECDSA verification.</p>
 +
 + <p>You can find an example library that can be used for this at https://github.com/bitcoin/secp256k1</p>
 +
 + <p>To build secp256k1 for use with bitcoinj, run
 + `./configure --enable-jni --enable-experimental --enable-module-ecdh`
 + and `make` then copy `.libs/libsecp256k1.so` to your system library path
 + or point the JVM to the folder containing it with -Djava.library.path
 + </p>
 +/
class NativeSecp256k1 {
    enum TWEAK_SIZE = 32;
    enum SIGNATURE_SIZE = 64;
    enum SECKEY_SIZE = 32;
    enum XONLY_PUBKEY_SIZE = 32;
    enum PUBKEY_SIZE = 33;
    enum MESSAGE_SIZE = 32;
    static void check(bool flag, ConsensusFailCode code, string file = __FILE__, size_t line = __LINE__) pure {
        if (!flag) {
            throw new SecurityConsensusException(code, file, line);
        }
    }

    enum KEYPAIR_SIZE = secp256k1_keypair.data.length;

    protected secp256k1_context* _ctx;

    @trusted
    this(const SECP256K1 flag = SECP256K1.CONTEXT_SIGN | SECP256K1.CONTEXT_VERIFY) nothrow {
        _ctx = secp256k1_context_create(flag);
        scope (exit) {
            randomizeContext;
        }
    }

    /++
     + libsecp256k1 Cleanup - This destroys the secp256k1 context object
     + This should be called at the end of the program for proper cleanup of the context.
     +/
    @trusted ~this() {
        secp256k1_context_destroy(_ctx);
    }

    @trusted
    secp256k1_context* cloneContext() {
        return secp256k1_context_clone(_ctx);
    }

    /++
     + libsecp256k1 PubKey Tweak-Mul - Tweak pubkey by multiplying to it
     +
     + @param tweak some bytes to tweak with
     + @param pubkey 32-byte seckey
     +/
    @trusted
    final void privTweak(
            scope const(ubyte[]) keypair,
            scope const(ubyte[]) tweak,
            out ubyte[] tweakked_keypair) const
    in (keypair.length == secp256k1_keypair.data.length)
    in (tweak.length == TWEAK_SIZE)
    do {
        scope (exit) {
            randomizeContext;
        }
        static assert(secp256k1_keypair.data.offsetof == 0);
        tweakked_keypair = keypair.dup;
        auto _keypair = cast(secp256k1_keypair*)(&tweakked_keypair[0]);
        {
            const ret = secp256k1_keypair_xonly_tweak_add(_ctx, _keypair, &tweak[0]);
            check(ret == 1, ConsensusFailCode.SECURITY_PUBLIC_KEY_TWEAK_MULT_FAULT);
        }

    }

    @trusted
    final immutable(ubyte[]) pubTweak(scope const(ubyte[]) pubkey, scope const(ubyte[]) tweak) const//in (pubkey.length == PUBKEY_SIZE)
    in (tweak.length == TWEAK_SIZE)
    do {
        secp256k1_pubkey xy_pubkey;
        {
            const ret = secp256k1_ec_pubkey_parse(_ctx, &xy_pubkey, &pubkey[0], pubkey.length);
            check(ret == 1, ConsensusFailCode.SECURITY_PUBLIC_KEY_SERIALIZE);

        }
        secp256k1_xonly_pubkey xonly_pubkey;
        {
            const ret = secp256k1_xonly_pubkey_from_pubkey(_ctx, &xonly_pubkey, null, &xy_pubkey);
            check(ret == 1, ConsensusFailCode.SECURITY_PUBLIC_KEY_SERIALIZE);
        }
        secp256k1_pubkey output_pubkey;
        {
            const ret = secp256k1_xonly_pubkey_tweak_add(_ctx, &output_pubkey, &xonly_pubkey, &tweak[0]);
            check(ret == 1, ConsensusFailCode.SECURITY_PUBLIC_KEY_TWEAK_MULT_FAULT);

        }
        ubyte[PUBKEY_SIZE] pubkey_result;

        {
            size_t len = PUBKEY_SIZE;
            const ret = secp256k1_ec_pubkey_serialize(_ctx, &pubkey_result[0], &len, &output_pubkey, SECP256K1
                    .EC_COMPRESSED);
            check(ret == 1, ConsensusFailCode.SECURITY_PUBLIC_KEY_PARSE_FAULT);

        }

        return pubkey_result.idup;
    }
    /++
     + libsecp256k1 create ECDH secret - constant time ECDH calculation
     +
     + @param seckey byte array of secret key used in exponentiaion
     + @param pubkey byte array of public key used in exponentiaion
     +/
    @trusted
    final immutable(ubyte[]) createECDHSecret(
            scope const(ubyte[]) seckey,
            const(ubyte[]) pubkey) const
    in (seckey.length == SECKEY_SIZE)
    do {
        scope (exit) {
            randomizeContext;
        }
        secp256k1_pubkey pubkey_result;
        ubyte[32] result;
        {
            const ret = secp256k1_ec_pubkey_parse(_ctx, &pubkey_result, &pubkey[0], pubkey.length);
            check(ret == 1, ConsensusFailCode.SECURITY_PUBLIC_KEY_PARSE_FAULT);
        }
        {
            const ret = secp256k1_ecdh(_ctx, &result[0], &pubkey_result, &seckey[0], null, null);
            check(ret == 1, ConsensusFailCode.SECURITY_EDCH_FAULT);
        }
        return result.idup;
    }

    /++
     + libsecp256k1 randomize - updates the context randomization
     +
     + @param seed 32-byte random seed
     +/
    @trusted
    bool randomizeContext() nothrow const {
        import tagion.crypto.random.random;

        ubyte[] ctx_randomize;
        ctx_randomize.length = 32;
        getRandom(ctx_randomize);
        auto __ctx = cast(secp256k1_context*) _ctx;
        return secp256k1_context_randomize(__ctx, &ctx_randomize[0]) == 1;
    }

    @trusted
    final void createKeyPair(
            scope const(ubyte[]) seckey,
            ref secp256k1_keypair keypair) const
    in (seckey.length == SECKEY_SIZE)

    do {
        scope (exit) {
            randomizeContext;
        }
        const rt = secp256k1_keypair_create(_ctx, &keypair, &seckey[0]);
        check(rt == 1, ConsensusFailCode.SECURITY_FAILD_TO_CREATE_KEYPAIR);

    }

    @trusted
    final void createKeyPair(
            const(ubyte[]) seckey,
            out ubyte[] keypair) const
    in (seckey.length == SECKEY_SIZE || seckey.length == secp256k1_keypair.data.length)
    do {
        if (seckey.length == secp256k1_keypair.data.length) {
            keypair = seckey.dup;
            return;
        }
        keypair.length = secp256k1_keypair.data.length;
        auto _keypair = cast(secp256k1_keypair*)(&keypair[0]);
        createKeyPair(seckey, *_keypair);
    }

    @trusted
    final void getSecretKey(
            ref scope const(ubyte[]) keypair,
            out ubyte[] seckey) nothrow const
    in (keypair.length == secp256k1_keypair.data.length)

    do {
        seckey.length = SECKEY_SIZE;
        const _keypair = cast(secp256k1_keypair*)&keypair[0];
        const ret = secp256k1_keypair_sec(_ctx, &seckey[0], _keypair);
        assert(ret is 1);
    }

    @trusted
    final void getPubkey(
            ref scope const(secp256k1_keypair) keypair,
            ref scope secp256k1_pubkey pubkey) const nothrow {
        secp256k1_keypair_pub(_ctx, &pubkey, &keypair);
    }

    /**
       Takes both a seckey and keypair 
*/
    @trusted
    final immutable(ubyte[]) getPubkey(scope const(ubyte[]) keypair_seckey) const
    in (keypair_seckey.length == secp256k1_keypair.data.length ||
            keypair_seckey.length == SECKEY_SIZE)

    do {
        static assert(secp256k1_keypair.data.offsetof == 0);
        if (keypair_seckey.length == SECKEY_SIZE) {
            secp256k1_keypair tmp_keypair;
            scope (exit) {
                tmp_keypair.data[] = 0;
            }
            createKeyPair(keypair_seckey, tmp_keypair);
            return getPubkey(tmp_keypair);

        }
        const _keypair = cast(secp256k1_keypair*)(&keypair_seckey[0]);
        return getPubkey(*_keypair);
    }

    @trusted
    final immutable(ubyte[]) getPubkey(ref scope const(secp256k1_keypair) keypair) const {
        secp256k1_pubkey xy_pubkey;
        {
            const rt = secp256k1_keypair_pub(_ctx, &xy_pubkey, &keypair);
            check(rt == 1, ConsensusFailCode.SECURITY_FAILD_PUBKEY_FROM_KEYPAIR);
        }
        ubyte[PUBKEY_SIZE] pubkey;
        {
            size_t len = PUBKEY_SIZE;
            const rt = secp256k1_ec_pubkey_serialize(_ctx, &pubkey[0], &len, &xy_pubkey, SECP256K1.EC_COMPRESSED);
            check(rt == 1, ConsensusFailCode.SECURITY_FAILD_PUBKEY_FROM_KEYPAIR);
        }
        return pubkey.idup;

    }

    /++
     + libsecp256k1 Create an Schnorr signature.
     +
     + @param msg Message hash, 32 bytes
     + @param key Secret key, 32 bytes
     +
     + Return values
     + @param sig byte array of signature
     +/
    @trusted
    final immutable(ubyte[]) sign(
            const(ubyte[]) msg,
            ref scope const(secp256k1_keypair) keypair,
            scope const(ubyte[]) aux_random) const
    in (msg.length == MESSAGE_SIZE)
    in (aux_random.length == MESSAGE_SIZE || aux_random.length == 0)

    do {
        scope (exit) {
            randomizeContext;
        }
        ubyte[SIGNATURE_SIZE] signature;
        const rt = secp256k1_schnorrsig_sign32(_ctx, &signature[0], &msg[0], &keypair, &aux_random[0]);
        check(rt == 1, ConsensusFailCode.SECURITY_FAILD_TO_SIGN_MESSAGE);
        return signature.idup;
    }

    @trusted
    final immutable(ubyte[]) sign(
            const(ubyte[]) msg,
            scope const(ubyte[]) keypair,
            scope const(ubyte[]) aux_random) const
    in (keypair.length == secp256k1_keypair.data.length)
    do {
        const _keypair = cast(secp256k1_keypair*)(&keypair[0]);
        return sign(msg, *_keypair, aux_random);
    }

    final immutable(ubyte[]) sign(
            const(ubyte[]) msg,
            scope const(ubyte[]) keypair) const {
        ubyte[MESSAGE_SIZE] _aux_random;
        ubyte[] aux_random = _aux_random;
        getRandom(aux_random);
        return sign(msg, keypair, aux_random);
    }

    /++
     + Verifies the given secp256k1 signature in native code.
     + Calling when enabled == false is undefined (probably library not loaded)

     + Params:
     +       msg            = The message which was signed, must be exactly 32 bytes
     +       signature      = The signature
     +       pub            = The public key which did the signing
     +/
    @trusted
    final bool verify(
            const(ubyte[]) msg,
            const(ubyte[]) signature,
            const(ubyte[]) pubkey) const nothrow
    in (pubkey.length == PUBKEY_SIZE)

    do {
        secp256k1_pubkey xy_pubkey;
        secp256k1_ec_pubkey_parse(_ctx, &xy_pubkey, &pubkey[0], pubkey.length);
        return verify(signature, msg, xy_pubkey);
    }

    @trusted
    final bool verify(
            const(ubyte[]) signature,
            const(ubyte[]) msg,
            ref scope const(secp256k1_pubkey) pubkey) const nothrow
    in (signature.length == SIGNATURE_SIZE)
    in (msg.length == MESSAGE_SIZE)

    do {
        secp256k1_xonly_pubkey xonly_pubkey;
        int ret = secp256k1_xonly_pubkey_from_pubkey(_ctx, &xonly_pubkey, null, &pubkey);

        if (ret != 0) {
            ret = secp256k1_schnorrsig_verify(_ctx, &signature[0], &msg[0], MESSAGE_SIZE, &xonly_pubkey);
        }
        return ret != 0;

    }
}

version (unittest) {
    import std.string : representation;
    import tagion.utils.Miscellaneous : decode;

    const(ubyte[]) sha256(scope const(ubyte[]) data) {
        import std.digest;
        import std.digest.sha : SHA256;

        return digest!SHA256(data).dup;
    }
}

unittest { /// Schnorr test generated from the secp256k1/examples/schnorr.c 
    const aux_random = "b0d8d9a460ddcea7ae5dc37a1b5511eb2ab829abe9f2999e490beba20ff3509a".decode;
    const msg_hash = "1bd69c075dd7b78c4f20a698b22a3fb9d7461525c39827d6aaf7a1628be0a283".decode;
    const secret_key = "e46b4b2b99674889342c851f890862264a872d4ac53a039fbdab91fd68ed4e71".decode;
    const expected_pubkey = "02ecd21d66cf97843d467c9d02c5781ec1ec2b369620605fd847bd23472afc7e74".decode;
    const expected_signature = "021e9a32a12ead3144bb230a81794913a856296ed369159d01b8f57d6d7e7d3630e34f84d49ec054d5251ff6539f24b21097a9c39329eaab2e9429147d6d82f8"
        .decode;
    const expected_keypair = decode("e46b4b2b99674889342c851f890862264a872d4ac53a039fbdab91fd68ed4e71747efc2a4723bd47d85f602096362becc11e78c5029d7c463d8497cf661dd2eca89c1820ccc2dd9b0e0e5ab13b1454eb3c37c31308ae20dd8d2aca2199ff4e6b");
    auto crypt = new NativeSecp256k1;
    //secp256k1_keypair keypair;
    ubyte[] keypair;
    crypt.createKeyPair(secret_key, keypair);
    assert(keypair == expected_keypair);
    const signature = crypt.sign(msg_hash, keypair, aux_random);
    assert(signature == expected_signature);
    const pubkey = crypt.getPubkey(keypair);
    assert(pubkey == expected_pubkey);
    const signature_ok = crypt.verify(msg_hash, signature, pubkey);
    assert(signature_ok, "Schnorr signing failded");

}

unittest { /// Schnorr tweak
    const aux_random = "b0d8d9a460ddcea7ae5dc37a1b5511eb2ab829abe9f2999e490beba20ff3509a".decode;
    const msg_hash = "1bd69c075dd7b78c4f20a698b22a3fb9d7461525c39827d6aaf7a1628be0a283".decode;
    const secret_key = "e46b4b2b99674889342c851f890862264a872d4ac53a039fbdab91fd68ed4e71".decode;
    auto crypt = new NativeSecp256k1;
    //secp256k1_keypair keypair;
    ubyte[] keypair;
    crypt.createKeyPair(secret_key, keypair);

    const pubkey = crypt.getPubkey(keypair);
    const tweak = sha256("Some tweak".representation);
    ubyte[] tweakked_keypair;
    crypt.privTweak(keypair, tweak, tweakked_keypair);
    assert(tweakked_keypair != keypair);
    const tweakked_pubkey = crypt.pubTweak(pubkey, tweak);

    assert(tweakked_pubkey != pubkey);

    const tweakked_pubkey_from_keypair = crypt.getPubkey(tweakked_keypair);

    assert(tweakked_pubkey == tweakked_pubkey_from_keypair, "The tweakked pubkey should be the same as the keypair tweakked pubkey");

    const signature = crypt.sign(msg_hash, keypair, aux_random);
    const tweakked_signature = crypt.sign(msg_hash, tweakked_keypair, aux_random);

    assert(signature != tweakked_signature, "The signature and the tweakked signature should not be the same");
    {
        const tweakked_signature_ok = crypt.verify(msg_hash, tweakked_signature, tweakked_pubkey);
        assert(tweakked_signature, "Tweakked signature should be correct");
    }
    {
        const signature_not_ok = crypt.verify(msg_hash, tweakked_signature, pubkey);
        assert(!signature_not_ok, "None tweakked signature should not be correct");
    }
    {
        const signature_not_ok = crypt.verify(msg_hash, signature, tweakked_pubkey);
        assert(!signature_not_ok, "None tweakked signature should not be correct");
    }
}
