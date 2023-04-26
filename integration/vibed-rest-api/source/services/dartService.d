module services.dartService;

import tagion.dart.DART;
import tagion.dart.DARTFile;
import tagion.dart.Recorder;
import tagion.dart.DARTBasic : DARTIndex;

import tagion.hibon.Document;
import tagion.dart.DARTFakeNet;
import tagion.crypto.SecureInterfaceNet : SecureNet, HashNet;
import tagion.crypto.SecureNet : StdSecureNet;


struct DartService {
    SecureNet net;
    DART db;

    this(const(string) filename, const(string) password) {
        net = new StdSecureNet();
        net.generateKeyPair(password);
        // net = new DARTFakeNet;


        db = new DART(net, filename);
    }

    ~this() {
        db.close;
    }

    const(DARTIndex) dartModify(const(Document) doc) {
        auto recorder = db.recorder();
        recorder.add(doc);
        const fingerprint = recorder[].front.fingerprint;
        db.modify(recorder);
        return fingerprint;
    }
}


