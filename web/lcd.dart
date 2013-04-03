part of dartgb;

class LCD {
  // Technically gl should have a _ in front, but I don't want to type that over and over again. :P
  GL.RenderingContext gl;
  CanvasElement _canvas;
  
  GL.Texture _frontBuffer;
  GL.Buffer _quadBuffer;
  
  ShaderHelper _blitProgram;
  
  String _blitVS = """
    attribute vec3 Position;
    attribute vec2 TexCoord0;

    varying vec2 vTexCoord0;

    void main() {
        vTexCoord0 = TexCoord0;
        gl_Position = vec4(Position, 1.0);
    }
  """;
  
  String _blitFS = """
    precision highp float;

    uniform sampler2D texture0;
    varying vec2 vTexCoord0;

    void main() {
      
      gl_FragColor = texture2D(texture0, vTexCoord0);
    }
  """;
  
  LCD(CanvasElement this._canvas) {
    gl = _canvas.getContext3d(alpha: true, depth: false, antialias: false, preserveDrawingBuffer: true);
    gl.clearColor(0.0, 0.0, 1.0, 1.0);
    gl.clear(GL.COLOR_BUFFER_BIT);
    gl.clearColor(0.0, 0.0, 0.0, 0.0);
    
    // Allocate a texture for the front buffer
    _frontBuffer = gl.createTexture();
    gl.bindTexture(GL.TEXTURE_2D, _frontBuffer);
    gl.texImage2D(GL.TEXTURE_2D, 0, GL.RGBA, 160, 144, 0, GL.RGBA, GL.UNSIGNED_BYTE, null);
    gl.texParameteri(GL.TEXTURE_2D, GL.TEXTURE_MIN_FILTER, GL.NEAREST);
    gl.texParameteri(GL.TEXTURE_2D, GL.TEXTURE_MAG_FILTER, GL.NEAREST);
    
    
    _blitProgram = new ShaderHelper(gl, _blitVS, _blitFS);
    
    _quadBuffer = gl.createBuffer();
    gl.bindBuffer(GL.ARRAY_BUFFER, _quadBuffer);
    
    Float32Array verts = new Float32Array.fromList([
      -1.0, -1.0,  0.0, 1.0,
       1.0, -1.0,  1.0, 1.0,
       1.0,  1.0,  1.0, 0.0,
      
      -1.0, -1.0,  0.0, 1.0,
       1.0,  1.0,  1.0, 0.0,
      -1.0,  1.0,  0.0, 0.0
    ]);
    
    gl.bufferData(GL.ARRAY_BUFFER, verts, GL.STATIC_DRAW);
    
  }
  
  void blit(GL.Texture source) {
    gl.clear(GL.COLOR_BUFFER_BIT);
    
    gl.useProgram(_blitProgram);
    gl.bindTexture(GL.TEXTURE_2D, source);
    gl.bindBuffer(GL.ARRAY_BUFFER, _quadBuffer);
    
    gl.drawArrays(GL.TRIANGLES, 0, 6);
  }
}