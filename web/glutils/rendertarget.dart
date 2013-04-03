part of glutils;

class RenderTarget {
  GL.RenderingContext gl;
  GL.Framebuffer framebuffer;
  TextureHelper texture;
  
  final int width;
  final int height;
  
  RenderTarget(GL.RenderingContext this.gl, int this.width, int this.height, [bool wrap = false]) {
    texture = new TextureHelper(gl, width, height, wrap);
    
    framebuffer = gl.createFramebuffer();
    gl.bindFramebuffer(GL.FRAMEBUFFER, framebuffer);
    gl.framebufferTexture2D(GL.FRAMEBUFFER, GL.COLOR_ATTACHMENT0, GL.TEXTURE_2D, texture.texture, 0);
    gl.bindFramebuffer(GL.FRAMEBUFFER, null);
  }
}
