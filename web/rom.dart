part of dartgb;

class ROM {
  Uint8Array data = null;
  
  static Future<ROM> load(String filename) {
    var completer = new Completer();
    HttpRequest.request(filename, responseType: "arraybuffer")
        .then((req) {
            assert(req.response.byteLength == 0x8000);  // limited to 32kb for now.
            var rom = new ROM(new Uint8Array.fromBuffer(req.response));
            completer.complete(rom);
        })
        .catchError((error) {
            print(error.toString());
            assert(false);
            completer.complete(null);
        });
    return completer.future;
  }
  
  ROM(this.data);
}