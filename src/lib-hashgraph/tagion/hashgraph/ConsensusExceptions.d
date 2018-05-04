module tagion.hashgraph.ConsensusExceptions;

import std.format : format;

enum ConsensusFailCode {
    NON,
    NO_MOTHER,
    MOTHER_AND_FATHER_SAME_SIZE,
    MOTHER_AND_FATHER_CAN_NOT_BE_THE_SAME,
    // PACKAGE_SIZE_OVERFLOW,
    // EVENT_PACKAGE_MISSING_PUBLIC_KEY,
    // EVENT_PACKAGE_MISSING_EVENT,
    // EVENT_PACKAGE_BAD_SIGNATURE,
    EVENT_NODE_ID_UNKNOWN,
    EVENT_SIGNATURE_BAD,
//    EVENT_MISSING_BODY,

    SECURITY_SIGN_FAULT,
    SECURITY_PUBLIC_KEY_CREATE_FAULT,
    SECURITY_PUBLIC_KEY_PARSE_FAULT,
    SECURITY_DER_SIGNATURE_PARSE_FAULT,
    SECURITY_SIGNATURE_SIZE_FAULT,

    SECURITY_PRIVATE_KEY_TWEAK_ADD_FAULT,
    SECURITY_PRIVATE_KEY_TWEAK_MULT_FAULT,
    SECURITY_PUBLIC_KEY_TWEAK_ADD_FAULT,
    SECURITY_PUBLIC_KEY_TWEAK_MULT_FAULT,
    SECURITY_PUBLIC_KEY_COMPRESS_SIZE_FAULT,
    SECURITY_PUBLIC_KEY_UNCOMPRESS_SIZE_FAULT,

    NETWORK_BAD_PACKAGE_TYPE
};

@safe
class ConsensusException : Exception {
    immutable ConsensusFailCode code;
    string toText() pure const nothrow {
        if ( code == ConsensusFailCode.NON ) {
            return msg;
        }
        else {
            return consensus_error_messages[code];
        }
    }

    this(string msg, string file = __FILE__, size_t line = __LINE__ ) {
        code=ConsensusFailCode.NON;
        super( msg, file, line );
    }

    this( ConsensusFailCode code, string file = __FILE__, size_t line = __LINE__ ) {
        super( consensus_error_messages[code], file, line );
        this.code=code;
    }
}

@safe
class EventConsensusException : ConsensusException {
    this( ConsensusFailCode code, string file = __FILE__, size_t line = __LINE__ ) {
        super( code, file, line );
    }
}

@safe
class SecurityConsensusException : ConsensusException {
    this( ConsensusFailCode code, string file = __FILE__, size_t line = __LINE__ ) {
        super( code, file, line );
    }
}

@safe
class GossipConsensusException : ConsensusException {
    this( ConsensusFailCode code, string file = __FILE__, size_t line = __LINE__ ) {
        super( code, file, line );
    }
}

@safe
class HashGraphConsensusException : ConsensusException {
    this( ConsensusFailCode code, string file = __FILE__, size_t line = __LINE__ ) {
        super( code, file, line );
    }
}


@trusted
static this() {
    with (ConsensusFailCode) {
        string[ConsensusFailCode] _consensus_error_messages=[
            NON : "Non",
            NO_MOTHER: "If an event has no mother it can not have a father",
            MOTHER_AND_FATHER_SAME_SIZE : "Mother and Father must user the same hash function",
            MOTHER_AND_FATHER_CAN_NOT_BE_THE_SAME : "The mother and father can not be the same event",

            EVENT_NODE_ID_UNKNOWN : "Public is not mapped to a Node ID",
            EVENT_SIGNATURE_BAD : "Bad signature for event",
//            EVENT_MISSING_BODY : "Event is missing eventbody",

            SECURITY_SIGN_FAULT : "Sign of message failed",
            SECURITY_PUBLIC_KEY_CREATE_FAULT : "Failed to create public key",
            SECURITY_PUBLIC_KEY_PARSE_FAULT : "Failed to parse public key",
            SECURITY_DER_SIGNATURE_PARSE_FAULT : "Failed to parse DER signature",
            SECURITY_SIGNATURE_SIZE_FAULT : "The size of the signature is wrong",

            SECURITY_PUBLIC_KEY_COMPRESS_SIZE_FAULT : "Wrong size of compressed Public key",
            SECURITY_PUBLIC_KEY_UNCOMPRESS_SIZE_FAULT : "Wrong size of uncompressed Public key",

            SECURITY_PRIVATE_KEY_TWEAK_ADD_FAULT : "Failed to tweak add private key",
            SECURITY_PRIVATE_KEY_TWEAK_MULT_FAULT : "Failed to tweak mult private key",
            SECURITY_PUBLIC_KEY_TWEAK_ADD_FAULT   : "Failed to tweak add public key",
            SECURITY_PUBLIC_KEY_TWEAK_MULT_FAULT  : "Failed to tweak mult public key",

            NETWORK_BAD_PACKAGE_TYPE : "Illegal package type",
            ];
        version(none) {
            import std.stdio;
            writefln("ConsensusFailCode.max=%d consensus_error_messages.length=%d" ,
                ConsensusFailCode.max, _consensus_error_messages.length );
        }
        import std.exception : assumeUnique;
        consensus_error_messages = assumeUnique(_consensus_error_messages);
        assert(
            ConsensusFailCode.max+1 == consensus_error_messages.length,
            "Some error messages in "~consensus_error_messages.stringof~" is missing");
    }
}



static public immutable(string[ConsensusFailCode]) consensus_error_messages;
