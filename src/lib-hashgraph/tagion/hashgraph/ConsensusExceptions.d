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
    EVENT_NOT_FOUND,

    GOSSIPNET_EVNET_HAS_BEEN_CACHED,
    GOSSIPNET_ILLEGAL_EXCHANGE_STATE,
    GOSSIPNET_EXPECTED_EXCHANGE_STATE,
    GOSSIPNET_EXPECTED_OR_EXCHANGE_STATE,
//    GOSSIPNET_BAD_EXCHNAGE_STATE,
    GOSSIPNET_REPLICATED_PUBKEY,
    GOSSIPNET_EVENTPACKAGE_NOT_FOUND,
    GOSSIPNET_MISSING_EVENTS,
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

    DART_ARCHIVE_ALREADY_ADDED,
    DART_ARCHIVE_DOES_NOT_EXIST,
    DART_ARCHIVE_SECTOR_NOT_FOUND,

    NETWORK_BAD_PACKAGE_TYPE,

    SCRIPTING_ENGINE_HBSON_FORMAT_FAULT,
    SCRIPTING_ENGINE_DATA_VALIDATION_FAULT,
    SCRIPTING_ENGINE_SIGNATUR_FAULT
};

@safe
class ConsensusException : Exception {
    immutable ConsensusFailCode code;
    this(string msg, ConsensusFailCode code=ConsensusFailCode.NON, string file = __FILE__, size_t line = __LINE__ ) {
        this.code=code;
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
    this( string msg, ConsensusFailCode code, string file = __FILE__, size_t line = __LINE__ ) {
        super( msg, code, file, line );
    }
}

@safe
class HashGraphConsensusException : ConsensusException {
    this( ConsensusFailCode code, string file = __FILE__, size_t line = __LINE__ ) {
        super( code, file, line );
    }
}


@safe
class DARTConsensusException : ConsensusException {
    this( ConsensusFailCode code, string file = __FILE__, size_t line = __LINE__ ) {
        super( code, file, line );
    }
}


@safe
class ScriptingEngineConsensusException : ConsensusException {
    this( ConsensusFailCode code, string file = __FILE__, size_t line = __LINE__ ) {
        super( code, file, line );
    }
}

@safe
class SSLSocketFiberConsensusException : ConsensusException {
    this( ConsensusFailCode code, string file = __FILE__, size_t line = __LINE__ ) {
        super( code, file, line );
    }
}


@trusted
static this() {
    with (ConsensusFailCode) {
        string[ConsensusFailCode] _consensus_error_messages=[
            NON                                         : "Non",
            NO_MOTHER                                   : "If an event has no mother it can not have a father",
            MOTHER_AND_FATHER_SAME_SIZE                 : "Mother and Father must user the same hash function",
            MOTHER_AND_FATHER_CAN_NOT_BE_THE_SAME       : "The mother and father can not be the same event",

            EVENT_NODE_ID_UNKNOWN                       : "Public key is not mapped to a Node ID",
            EVENT_SIGNATURE_BAD                         : "Bad signature for event",
            EVENT_NOT_FOUND                             : "Event not found",

//            EVENT_MISSING_BODY                        : "Event is missing eventbody",

            GOSSIPNET_EVNET_HAS_BEEN_CACHED             : "Gossip net has already cached event",
            GOSSIPNET_ILLEGAL_EXCHANGE_STATE            : "Gossip exchange state is illegal %s",
            GOSSIPNET_EXPECTED_EXCHANGE_STATE           : "Gossip exchange state is illegal %s expected %s",
            GOSSIPNET_EXPECTED_OR_EXCHANGE_STATE        : "Gossip exchange state is illegal %s expected %s or %s",
            GOSSIPNET_REPLICATED_PUBKEY                 : "The public key of the received package is the same as the nodes public key",
            GOSSIPNET_EVENTPACKAGE_NOT_FOUND            : "Event package not found in the event package cache",
            GOSSIPNET_MISSING_EVENTS                    : "Gossip network missing events",

            SECURITY_SIGN_FAULT                         : "Sign of message failed",
            SECURITY_PUBLIC_KEY_CREATE_FAULT            : "Failed to create public key",
            SECURITY_PUBLIC_KEY_PARSE_FAULT             : "Failed to parse public key",
            SECURITY_DER_SIGNATURE_PARSE_FAULT          : "Failed to parse DER signature",
            SECURITY_SIGNATURE_SIZE_FAULT               : "The size of the signature is wrong",

            SECURITY_PUBLIC_KEY_COMPRESS_SIZE_FAULT     : "Wrong size of compressed Public key",
            SECURITY_PUBLIC_KEY_UNCOMPRESS_SIZE_FAULT   : "Wrong size of uncompressed Public key",

            SECURITY_PRIVATE_KEY_TWEAK_ADD_FAULT        : "Failed to tweak add private key",
            SECURITY_PRIVATE_KEY_TWEAK_MULT_FAULT       : "Failed to tweak mult private key",
            SECURITY_PUBLIC_KEY_TWEAK_ADD_FAULT         : "Failed to tweak add public key",
            SECURITY_PUBLIC_KEY_TWEAK_MULT_FAULT        : "Failed to tweak mult public key",

            DART_ARCHIVE_ALREADY_ADDED                  : "DART Failed archive is already added",
            DART_ARCHIVE_DOES_NOT_EXIST                 : "DART Failed archive does not exist",
            DART_ARCHIVE_SECTOR_NOT_FOUND               : "DART Failed sector is not maintained by this node",
            NETWORK_BAD_PACKAGE_TYPE                    : "Illegal package type",

            SCRIPTING_ENGINE_HBSON_FORMAT_FAULT         : "The data is not a HBSON format",
            SCRIPTING_ENGINE_DATA_VALIDATION_FAULT      : "Transaction object does not contain the right elements",
            SCRIPTING_ENGINE_SIGNATUR_FAULT             : "Signatures are not correct"
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