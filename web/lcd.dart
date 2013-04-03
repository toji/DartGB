part of dartgb;

class LCD {
  CanvasElement canvas;
  GL.RenderingContext gl;
  
  LCD(CanvasElement this.canvas) {
    gl = canvas.getContext3d(alpha: true, depth: false, antialias: false, preserveDrawingBuffer: true);
    gl.clearColor(0.0, 0.0, 1.0, 1.0);
    gl.clear(GL.COLOR_BUFFER_BIT);
  }
}