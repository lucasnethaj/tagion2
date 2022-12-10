module tagion.network.SSLSocket;

import core.stdc.stdio;
import core.stdc.string : strerror;

import std.socket;
import std.range.primitives : isBidirectionalRange;
import std.string : format, toStringz;
import std.typecons : Tuple;
import std.array : join;
import std.algorithm.iteration : map;
import std.typecons : Flag, Yes, No;

import tagion.network.SSLSocketException;
import tagion.network.SSL;

import io = std.stdio;

enum EndpointType {
    Client,
    Server
}

/++
 Socket for OpenSSL & WolfSSL
+/
@safe
class SSLSocket : Socket {
    enum ERR_TEXT_SIZE = 256;
    static class MemoryLock {
        // empty
    }

    protected {
        static shared(MemoryLock) lock;
        SSL* _ssl;
        SSL_CTX* _ctx;
        static SSL_CTX* client_ctx;
		Flag!"EndPoint" endpoint;
    }

    /++
     Constructs a new socket
     +/
    this(AddressFamily af,
            SocketType type = SocketType.STREAM,
            string certificate_filename = null,
            string prvkey_filename = null) {
        ERR_clear_error;
        super(af, type);
        _init(certificate_filename, prvkey_filename);
    }

    this(AddressFamily af,
            EndpointType et,
            SocketType type = SocketType.STREAM,
            bool verifyPeer = true) {
        ERR_clear_error;
        super(af, type);
        //    _init(certificate_filename, prvkey_filename);
    }

    /// ditto
    this(socket_t sock,
            AddressFamily af,
            SSLSocket seed_socket = null) {
        ERR_clear_error;
        super(sock, af);
        if (seed_socket) {
            _ctx = seed_socket._ctx;
        }
        else {
            _init(null, null);
        }
        //        _init(certificate_filename, prvkey_filename);
    }

    shared static int client_count;
    static bool verifyPeer = false;
    /++
     The client use this configuration by default.
     +/
    protected final void _init(
            string certificate_filename = null,
            string prvkey_filename = null) {
        if (certificate_filename.length) {
            configureContext(certificate_filename, prvkey_filename);
        }
        synchronized (lock) {
            if (_ctx is null) {
                // If _ctx is null then it is uses a client SSL
                if (client_ctx is null) {
                    client_ctx = SSL_CTX_new(TLS_client_method);
                    atomicOp!"+="(client_count, 1);
                    io.writefln("new[%d]  client_ctx = %s", client_count, client_ctx);
                }
                _ctx = client_ctx;
                io.writefln("--- client = %s", _ctx);
            }
            _ssl = SSL_new(_ctx);
        }
        SSL_set_fd(_ssl, this.handle);
        if (isClient && verifyPeer) {
            SSL_set_verify(_ssl, SSL_VERIFY_NONE, null);
        }
    }

    bool isClient() nothrow const @nogc {
        return !endpoint;
    }

    import core.atomic : atomicOp;

    static shared int free_count;
    static shared int free_client_count;
    ~this() {
        io.writefln("%s", __FUNCTION__);
        synchronized (lock) {
            SSL_free(_ssl);
            io.writefln("dtor _ctx=%s client_ctx=%s", _ctx, client_ctx);
            if (!isClient) {
                atomicOp!"+="(free_count, 1);
                io.writefln("free[%d] free_ctx = %s", free_count, _ctx);
                SSL_CTX_free(_ctx);
                //_ctx = null;
            }
        }
    }

    static ~this() {
        io.writefln("%s", __FUNCTION__);
        synchronized (lock) {
            if (client_ctx) {
                atomicOp!"+="(free_client_count, 1);
                io.writefln("free[%d] client_ctx=%s", free_client_count, client_ctx);
                SSL_CTX_free(client_ctx);
                //client_ctx = null;
            }
        }
    }

    shared static this() {
        lock = new shared(MemoryLock);
    }

    static string errorText(const long error_code) @trusted nothrow {
        import core.stdc.string : strlen;
        import std.exception : assumeUnique;

        auto result = new char[ERR_TEXT_SIZE];
        ERR_error_string_n(error_code, result.ptr, result
                .length);
        return assumeUnique(result[0 .. strlen(result.ptr)]);
    }

    alias SSL_Error = Tuple!(long, "error_code", string, "msg");
    static const(SSL_Error[]) getErrors() nothrow {
        long error_code;
        SSL_Error[] result;
        while ((error_code = ERR_get_error) != 0) {
            result ~= SSL_Error(error_code, errorText(error_code));
        }
        return result;
    }

    static string getAllErrors() {
        return getErrors
            .map!(err => format("Err %d: %s", err.error_code, err.msg))
            .join("\n");
    }

    static shared int server_count;
    /++
     Configure the certificate for the SSL
     +/
    @trusted
    void configureContext(
            string certificate_filename,
            string prvkey_filename) {
        if (prvkey_filename.length is 0) {
            prvkey_filename = certificate_filename;
        }
        import std.file : exists;

        ERR_clear_error;
        _ctx = SSL_CTX_new(TLS_server_method);
	endpoint=Yes.EndPoint;
        atomicOp!"+="(server_count, 1);
        io.writefln("new[%d]  server _ctx=%s", server_count, _ctx);
        check(certificate_filename.exists,
                format("Certification file '%s' not found", certificate_filename));
        check(prvkey_filename.exists,
                format("Private key file '%s' not found", prvkey_filename));

        if (SSL_CTX_use_certificate_file(ctx, certificate_filename.toStringz,
                SSL_FILETYPE_PEM) <= 0) {
            throw new SSLSocketException(format("SSL Certificate: %s", getAllErrors));
        }

        if (SSL_CTX_use_PrivateKey_file(ctx, prvkey_filename.toStringz, SSL_FILETYPE_PEM) <= 0) {
            throw new SSLSocketException(format("SSL private key:\n %s", getAllErrors));
        }
        if (SSL_CTX_check_private_key(ctx) <= 0) {
            throw new SSLSocketException(format("Private key not set correctly:\n %s", getAllErrors));
        }
    }

    /++
     Cleans the SSL error que
     +/
    static void clearError() {
        ERR_clear_error();
    }

    /++
     Connect to an address
     +/
    override void connect(Address to) {
        super.connect(to);
        synchronized (lock) {
            const res = SSL_connect(_ssl);
            check_error(res, true);
        }
    }

    /++
	Params: how has no effect for the SSLSocket
	+/
    override void shutdown(SocketShutdown how) {
        SSL_shutdown(_ssl);
    }

    bool shutdown() nothrow {
        return SSL_shutdown(_ssl) != 0;
    }
    /++
     Send a buffer to the socket using the socket result
     +/
    @trusted
    override ptrdiff_t send(scope const(void)[] buf, SocketFlags flags) {
        auto res_val = SSL_write(_ssl, buf.ptr, cast(int) buf.length);
        check_error(res_val);
        return res_val;
    }

    /++
     Send a buffer to the socket with no result
     +/
    override ptrdiff_t send(scope const(void)[] buf) {
        return send(buf, SocketFlags.NONE);
    }

    /* Helper function to convert a ssl_error to an exception
     * This function should only called after an ssl function call
     * Throws: a SSLSocketException if the _ssl handler contains an error
     * Params:
     *   ssl_ret = Return code for SSL (ssl_ret > 0) means no error
     *   false = Enable ignore temporary errors for (Want to read or write)
     */
    protected void check_error(const int ssl_ret, const bool check_read_write = false) const {
        const ssl_error = cast(SSLErrorCodes) SSL_get_error(_ssl, ssl_ret);
        with (SSLErrorCodes) final switch (ssl_error) {
        case SSL_ERROR_NONE:
            // Ignore
            break;
        case SSL_ERROR_WANT_WRITE,
        SSL_ERROR_WANT_READ:
            if (check_read_write) {
                throw new SSLSocketException(str_error(ssl_error), ssl_error);
            }
            break;
        case SSL_ERROR_WANT_X509_LOOKUP,
            SSL_ERROR_SYSCALL,
            SSL_ERROR_ZERO_RETURN,
            SSL_ERROR_WANT_CONNECT,
            SSL_ERROR_WANT_ACCEPT,
            SSL_ERROR_WANT_ASYNC,
            SSL_ERROR_WANT_ASYNC_JOB,
        SSL_ERROR_SSL:
            throw new SSLSocketException(str_error(ssl_error), ssl_error);
            break;
        }

    }

    /++
     Returns:
     pending bytes in the socket que
     +/
    uint pending() {
        const result = SSL_pending(_ssl);
        return cast(uint) result;
    }

    /++
     Receive a buffer from the socket using the flags
     +/
    @trusted
    override ptrdiff_t receive(scope void[] buf, SocketFlags flags) {
        const res_val = SSL_read(_ssl, buf.ptr, cast(uint) buf.length);
        check_error(res_val);
        return res_val;
    }

    /++
     Receive a buffer from the socket with not flags
     +/
    override ptrdiff_t receive(scope void[] buf) {
        return receive(buf, SocketFlags.NONE);
    }

    /++
     Returns:
     the SSL system error message
     +/
    @trusted
    static string str_error(const int errornum) {
        const str = strerror(errornum);
        import std.string : fromStringz;

        return fromStringz(str).idup;
    }

    /++
       Create a SSL socket from a socket
       Returns:
       true of the ssl_socket is succesfully created
       a ssl_client for the client
       Params:
       client = Standard socket (non ssl socket)
       ssl_socket = The SSL
    +/
    bool acceptSSL(ref SSLSocket ssl_client, Socket client) {
        if (ssl_client is null) {
            if (!client.isAlive) {
                client.close;
                throw new SSLSocketException("Socket could not connect to client. Socket closed.");
            }
            client.blocking = false;
            ssl_client = new SSLSocket(client.handle, client.addressFamily, this);
            const fd_res = SSL_set_fd(ssl_client.ssl, client.handle);
            if (!fd_res) {
                return false;
            }
        }

        auto c_ssl = ssl_client.ssl;

        const res = SSL_accept(c_ssl);
        bool accepted;

        const ssl_error = cast(SSLErrorCodes) SSL_get_error(c_ssl, res);

        with (SSLErrorCodes) switch (ssl_error) {
        case SSL_ERROR_NONE:
            accepted = true;
            break;
        case SSL_ERROR_WANT_READ,
        SSL_ERROR_WANT_WRITE:
            // Ignore
            break;
        case SSL_ERROR_SSL,
            SSL_ERROR_WANT_X509_LOOKUP,
            SSL_ERROR_SYSCALL,
        SSL_ERROR_ZERO_RETURN:
            throw new SSLSocketException(str_error(ssl_error), ssl_error);
            break;
        default:
            throw new SSLSocketException(format("SSL Error. SSL error code: %d.", ssl_error),
                    SSL_ERROR_SSL);
            break;
        }
        return !SSL_pending(c_ssl) && accepted;
    }

    /++
       Reject a client connect and close the socket
     +/
    void rejectClient() {
        auto client = super.accept();
        client.close();
    }

    /++
     Returns:
     the SSL system handler
     +/
    @nogc
    SSL* ssl() pure nothrow {
        return _ssl;
    }

    @nogc
    SSL_CTX* ctx() pure nothrow {
        return _ctx;
    }

    unittest {
        import std.array;
        import std.string;
        import std.file;
        import std.exception : assertNotThrown, assertThrown, collectException;
        import tagion.basic.Basic : fileId;
        import std.stdio;

        import tagion.basic.Debug : testfile;

        immutable cert_path = testfile(__MODULE__ ~ ".pem");
        immutable key_path = testfile(__MODULE__ ~ ".key.pem");
        version (SSL_PEM_FILES) {
            /// This switch can beable of a new .pem should be created
            immutable stab = "stab";

            import tagion.network.SSLOptions;

            const OpenSSL ssl_options = {
                certificate: cert_path, /// Certificate file name
                private_key: key_path, /// Private key
                key_size: 1024, /// Key size (RSA 1024,2048,4096)
                days: 1, /// Number of days the certificate is valid
                country: "UA", /// Country Name two letters
                state: stab, /// State or Province Name (full name)
                city: stab, /// Locality Name (eg, city)
                organisation: stab, /// Organization Name (eg, company)
                unit: stab, /// Organizational Unit Name (eg, section)
                name: stab, /// Common Name (e.g. server FQDN or YOUR name)
                email: stab, /// Email Address

            
            };
            configureOpenSSL(ssl_options);
        }
        //! [Waiting for first acception]
        version (none) {
            SSLSocket item = new SSLSocket(AddressFamily.UNIX, EndpointType.Server);
            SSLSocket ssl_client = new SSLSocket(AddressFamily.UNIX, EndpointType.Client);
            Socket client = new Socket(AddressFamily.UNIX, SocketType.STREAM);
            bool result;
            const exception = collectException!SSLSocketException(
                    item.acceptSSL(ssl_client, client), result);
            assert(exception !is null);
            assert(exception.error_code == SSLErrorCodes.SSL_ERROR_SSL);
            assert(!result);
        }

        //! [File reading - incorrect certificate]
        {
            SSLSocket testItem_server;
            const exception = collectException!SSLSocketException(
                    new SSLSocket(AddressFamily.UNIX, SocketType.STREAM, "_", "_"),
                    testItem_server);
            scope (exit) {
                testItem_server.close;
            }
            assert(testItem_server is null);
        }

        //! [File reading - empty path]
        version (none) {

            SSLSocket testItem_server = new SSLSocket(AddressFamily.UNIX, EndpointType.Server);
            scope (exit) {
                testItem_server.close;
            }
            string empty_path = "";
            assertThrown!SSLSocketException(
                    testItem_server.configureContext(empty_path, empty_path)
            );
            //SSLSocket.reset();
        }

        //! [file loading correct]
        {
            SSLSocket testItem_server;
            assertNotThrown!SSLSocketException({
                testItem_server = new SSLSocket(AddressFamily.UNIX, SocketType.STREAM,
                    cert_path, key_path);
            });
            scope (exit) {
                testItem_server.close;
            }
            assert(testItem_server !is null);
        }

        //! [file loading key incorrect]
        {
            auto false_key_path = cert_path;
            SSLSocket testItem_server = new SSLSocket(AddressFamily.UNIX);
            const exception = collectException!SSLSocketException(
                    testItem_server.configureContext(cert_path, false_key_path)
            );
            assert(exception !is null);
            assert(exception.error_code == SSLErrorCodes.SSL_ERROR_NONE);
        }

        //! [correct acception]
        {
            SSLSocket empty_socket = null;
            SSLSocket ssl_client = new SSLSocket(AddressFamily.UNIX);
            Socket socket = new Socket(AddressFamily.UNIX, SocketType.STREAM);
            scope (exit) {
                ssl_client.close;
                socket.close;
            }
            bool result;
            const exception = collectException!SSLSocketException(
                    result = ssl_client.acceptSSL(empty_socket, socket)
            );
            assert(exception !is null);
            assert(exception.error_code == SSLErrorCodes.SSL_ERROR_SSL);
            assert(!result);
        }
    }
}
