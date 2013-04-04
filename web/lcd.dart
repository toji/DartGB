part of dartgb;

class LCD {
  // Really gl should have a _ in front, but I don't want to type that over and over again. :P
  GL.RenderingContext gl;
  CanvasElement _canvas;
  Memory memory;
  
  TextureHelper _frontBuffer;
  GL.Buffer _quadBuffer;
  ShaderHelper _blitShader;
  
  String _blitVS = """
    attribute vec2 Position;
    attribute vec2 TexCoord0;

    varying vec2 vTexCoord0;

    void main() {
        vTexCoord0 = TexCoord0;
        gl_Position = vec4(Position, 1.0, 1.0);
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
  
  Float32Array _clipMat = new Float32Array(9);
  Float32Array _imgMat = new Float32Array(9);

  LCD(CanvasElement this._canvas, Memory this.memory) {
    // Initializes a few useful data structures.
    _canvas.width = (_canvas.clientWidth * window.devicePixelRatio).toInt();
    _canvas.height = (_canvas.clientHeight * window.devicePixelRatio).toInt();
    
    gl = _canvas.getContext3d(alpha: true, depth: false, antialias: false, preserveDrawingBuffer: true);
    gl.viewport(0, 0, gl.drawingBufferWidth, gl.drawingBufferHeight);
    
    gl.clearColor(0.0, 0.0, 1.0, 1.0);
    gl.clear(GL.COLOR_BUFFER_BIT);
    gl.clearColor(0.0, 0.0, 0.0, 0.0);
    
    // Allocate the front buffer
    _frontBuffer = new TextureHelper(gl, 256, 256, false);
    _blitShader = new ShaderHelper(gl, _blitVS, _blitFS);
    
    _quadBuffer = gl.createBuffer();
    gl.bindBuffer(GL.ARRAY_BUFFER, _quadBuffer);
    
    Float32Array verts = new Float32Array.fromList([
       -1.0,  -1.0,  0.0, 1.0,
       1.0,  -1.0,  1.0, 1.0,
       1.0,  1.0,  1.0, 0.0,
      
       -1.0,  -1.0,  0.0, 1.0,
       1.0,  1.0,  1.0, 0.0,
       -1.0,  1.0,  0.0, 0.0
    ]);
    
    gl.bufferData(GL.ARRAY_BUFFER, verts, GL.STATIC_DRAW);
    
    present();
  }
  
  // 0xFF40  LCD and GPU control Read/write
  // 0xFF47  Background palette  Write only
  
  int get ScrollX => memory.SCX;
  int get ScrollY => memory.SCY;
  int get ScanLine => memory.LY;
  
  int Pallet(int index) {
    return (memory.BGP >> (index * 2)) & 0x3;
  }

  Uint8Array _scanline = new Uint8Array(512);
  void renderScan() {
    int y = ScanLine;
    int scanlineOffset = 0;
    
    //print("Rendering Scanline $ScanLine");
    
    int backgroundMapOffset = 0x9800; // for looping through the tile maps
    
    for(int x = 0; x < 32; ++x) {
      int backgroundIndex = x + ((y / 8).toInt() * 32);
      int tileIndex = memory.R(backgroundMapOffset + backgroundIndex);
      int tileOffset = 0x8000 + (tileIndex * 16) + ((y % 8) * 2);
      
      int rowLow = memory.R(tileOffset);
      int rowHigh = memory.R(tileOffset+1) << 1;
      for(int i = 0; i < 8; ++i) {
        int tileValue = ((rowLow >> i) & 0x01) + ((rowHigh >> i) & 0x02);
        tileValue = Pallet(tileValue);
        //int tileValue = (i + j) % 4; // For Great Debugging!
        
        // TODO: Pallet lookup
        if(tileValue == 0) {
          _scanline[scanlineOffset++] = 255;
          _scanline[scanlineOffset++] = 0;
        } else if(tileValue == 1) {
          _scanline[scanlineOffset++] = 192;
          _scanline[scanlineOffset++] = 255;
        } else if(tileValue == 2) {
          _scanline[scanlineOffset++] = 96;
          _scanline[scanlineOffset++] = 255;
        } else {
          _scanline[scanlineOffset++] = 0;
          _scanline[scanlineOffset++] = 255;
        }
      }
    }
    
    gl.bindTexture(GL.TEXTURE_2D, _frontBuffer.texture);
    gl.texSubImage2D(GL.TEXTURE_2D, 0, 0, y, 256, 1, GL.LUMINANCE_ALPHA, GL.UNSIGNED_BYTE, _scanline);
  }
  
  void clearScan() {
    int y = ScanLine;
    
    //print("Clearing Scanline $ScanLine");
    
    _scanline.forEach((el) => el = 0);
    gl.bindTexture(GL.TEXTURE_2D, _frontBuffer.texture);
    gl.texSubImage2D(GL.TEXTURE_2D, 0, 0, y, 256, 1, GL.LUMINANCE_ALPHA, GL.UNSIGNED_BYTE, _scanline);
  }
  
  void present() {
    gl.viewport(0, 0, 256, 256);
    
    //print("Presenting w/ Scroll ($ScrollX, $ScrollY)");
    
    gl.useProgram(_blitShader.program);
    
    gl.bindBuffer(GL.ARRAY_BUFFER, _quadBuffer);
    gl.enableVertexAttribArray(_blitShader.attributes["Position"]);
    gl.enableVertexAttribArray(_blitShader.attributes["TexCoord0"]);
    gl.vertexAttribPointer(_blitShader.attributes["Position"], 2, GL.FLOAT, false, 16, 0);
    gl.vertexAttribPointer(_blitShader.attributes["TexCoord0"], 2, GL.FLOAT, false, 16, 8);
    
    gl.activeTexture(GL.TEXTURE0);
    gl.uniform1i(_blitShader.uniforms["texture0"], 0);
    gl.bindTexture(GL.TEXTURE_2D, _frontBuffer.texture);
    
    gl.drawArrays(GL.TRIANGLES, 0, 6);
  }

  void clear() {
    //print("Clearing");
    gl.clear(GL.COLOR_BUFFER_BIT);
  }
}