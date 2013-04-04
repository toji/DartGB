part of dartgb;

class ROM {
  Uint8Array data = null;
  
  static Future<ROM> load(String filename) {
    var completer = new Completer();
    HttpRequest.request(filename, responseType: "arraybuffer")
        .then((req) {
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

  String get name {
    List<int> name_list = data.sublist(0x0134,0x0143);
    return new String.fromCharCodes(name_list);
  }
}
