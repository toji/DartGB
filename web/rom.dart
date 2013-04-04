part of dartgb;

class ROM {
  Uint8List data = new Uint8List(0x8000); // Limited to 32k right now.
  
  ROM(String filename) {
    // TODO: change the request so it doesn't return a string which
    // is NULL-terminated.
    HttpRequest.request(filename)
        .then((req) {
            assert(req.response.byteLength == data.lengthInBytes);
            var view = new Uint8Array.fromBuffer(req.response);
            data.setRange(0, data.length, view.asList());
        })
        .catchError((error) {
            print(error.toString());
            assert(false);
        });
  }
}