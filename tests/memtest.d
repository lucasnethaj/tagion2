import std.stdio;
import std.conv;
import std.file;
import std.path;
import std.string;
import std.json;
import std.concurrency;
import std.exception;
import core.thread;
import std.datetime.systime;
import core.stdc.string;
import core.stdc.stdlib : exit;

import libnng;

shared string _WD;

static double timestamp()
{
    auto ts = Clock.currTime().toTimeSpec();
    return ts.tv_sec + ts.tv_nsec/1e9;
}

static void log(A...)(A a){
    writeln(format("%.6f ",timestamp),a);
}

static JSONValue scandir(string path){
    JSONValue j = parseJSON("{}");
    foreach (DirEntry entry; dirEntries(path, SpanMode.shallow))
    {
        try{
            auto n = entry.name.replace(path~"/","");
            j[n] = entry.size;
            if(entry.isDir){
                j[n] = scandir(entry.name);
            }
        }
        catch (FileException fe) { continue; }
    }   
    return j;
}


int reprocess( char **buf, size_t *sz ){
    
    JSONValue jr = parseJSON("{}");
    jr["time"] = Clock.currTime().toSimpleString();
    string rstr = jr.toString();
    
    *sz = rstr.length;
    *buf = cast(char*)nng_alloc(rstr.length);
    
    memcpy(*buf, rstr.ptr, rstr.length);

    return 0;
}

void time_handler(nng_aio* aio) {
    int rc = 0;
    nng_http_res *res;
    void *reqbody;
    size_t reqbodylen;

    char *buf;
    size_t buflen;

    scope(failure){
        nng_http_res_free(res);
        nng_aio_finish(aio, rc);
        log("RH:ERROR: ",rc);
        return;
    }

    nng_http_req *req = cast(nng_http_req*)nng_aio_get_input(aio, 0);
        enforce(req != null);
    
    nng_http_req_get_data(req, &reqbody, &reqbodylen);
    
    rc = nng_http_res_alloc(&res);
        enforce(rc == 0);

//    rc = nng_http_res_set_header(res,"Content-type","application/json; charset=UTF-8");
//        enforce(rc == 0);

/*    
    auto s1 = nng_http_req_get_uri(req);
    string ruri = to!string(s1);
    auto s2 = nng_http_req_get_header(req, "Content-type");
    string rtype = to!string(s2);
*/

//    reprocess(&buf, &buflen);

    string lala = "asdcjkascpoasidjfvopiasdjvopsidfvjasiodfvjaopidfvjopsidfvjospidfjvsoidfvj sdofv sdopifvjsodifv sodifjvosdifjvosidfjv osidjv osdivj sodifvj sodifvj sodifvj sdof";

    immutable(char)*labuf = lala.toStringz;
    
    const char* istr = "{\"this\":\"is\"}";

   
    rc = nng_http_res_copy_data(res, istr, strlen(istr));
        enforce(rc == 0);
    
    //rc = nng_http_res_copy_data(res, buf, buflen);
    //    enforce(rc == 0);

//    nng_free(buf, buflen);

    nng_http_res_set_status(res, nng_http_status.NNG_HTTP_STATUS_OK);
    nng_aio_set_output(aio, 0, res);
    nng_aio_finish(aio, 0);

    return;
}



int main()
{
    writeln("Hello LIBNNG HTTP Server!");
    
    const string uri = "http://localhost:8088";
    const string prefix = "";
    string wd = __FILE__.absolutePath.dirName;
    _WD = wd;

    int rc;

    nng_http_server  *s;

    nng_url *url;

    rc = nng_url_parse(&url, uri.toStringz());
    if( rc < 0 ) { log("H ",nng_errstr(rc)); exit(1); };


    rc = nng_http_server_hold(&s, url);
    if( rc < 0 ) { log("H ",nng_errstr(rc)); exit(1); };
    
    scope(exit){
        nng_http_server_release(s);
        nng_url_free(url);
    }

    // handle REST API
    
    nng_http_handler *h;
    rc = nng_http_handler_alloc(&h, toStringz(prefix~"/api/v1/time"), &time_handler);
    if( rc < 0 ) { log("H ",nng_errstr(rc)); exit(1); };
    rc = nng_http_server_add_handler(s, h);
    if( rc < 0 ) { log("H ",nng_errstr(rc)); exit(1); };


    // run server
    rc = nng_http_server_start(s);
    if( rc < 0 ) { log("H ",nng_errstr(rc)); exit(1); };

    while(true) Thread.sleep(1000.msecs);

    return 0;
}





/*

    if(jd["todo"].str == "time"){
    }

    if(jd["todo"].str == "dir"){
        jr["dir"] = buildPath(_WD,"htdocs");
        jr["tree"] = scandir(buildPath(_WD,"htdocs"));
    }
  
*/  
