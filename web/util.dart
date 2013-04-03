part of dartgb;

class Util {
  static int signed(int byte) {
    if (byte > 127) {
      return (byte & 127) - 128;
    } else {
      return byte;
    }
  }
}