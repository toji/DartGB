part of glutils;

class TextureHelper {
  GL.RenderingContext gl;
  GL.Texture texture;
  
  final int width;
  final int height;
  
  TextureHelper(GL.RenderingContext this.gl, int this.width, int this.height, [bool wrap = false]) {
    texture = gl.createTexture();
    gl.bindTexture(GL.TEXTURE_2D, texture);
    gl.texParameteri(GL.TEXTURE_2D, GL.TEXTURE_MAG_FILTER, GL.NEAREST);
    gl.texParameteri(GL.TEXTURE_2D, GL.TEXTURE_MIN_FILTER, GL.NEAREST);
    gl.texParameteri(GL.TEXTURE_2D, GL.TEXTURE_WRAP_S, wrap ? GL.REPEAT : GL.CLAMP_TO_EDGE);
    gl.texParameteri(GL.TEXTURE_2D, GL.TEXTURE_WRAP_T, wrap ? GL.REPEAT : GL.CLAMP_TO_EDGE);
    gl.texImage2D(GL.TEXTURE_2D, 0, GL.RGBA, width, height, 0, GL.RGBA, GL.UNSIGNED_BYTE, null);
    gl.bindTexture(GL.TEXTURE_2D, null);
  }
}
