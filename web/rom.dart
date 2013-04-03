part of dartgb;

class ROM {
  Uint8List data = new Uint8List(0x8000); // Limited to 32k right now.
  
  ROM(String filename) {
    HttpRequest.getString(filename).then((s) => data.addAll(s.codeUnits));
  }
}