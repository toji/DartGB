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
    //gl.enable(GL.BLEND);
    //gl.blendFunc(GL.ZERO, GL.DST_ALPHA);
    
    gl.clearColor(0.0, 0.0, 0.0, 0.0);
    
    // Allocate the front buffer
    _frontBuffer = new TextureHelper(gl, 160, 144, false);
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
  
  // 0xFF40  LCD and GPU control Read/write memory.LCDC
  // 0xFF47  Background palette  Write only
  
  int get ScrollX => memory.SCX;
  int get ScrollY => memory.SCY;
  int get ScanLine => memory.LY;
  
  bool get BackgroundEnabled => (memory.LCDC & 0x01) == 1;
  bool get SpritesEnabled => (memory.LCDC & 0x02) == 1;
  int get SpriteHeight => (memory.LCDC & 0x04) == 0 ? 8 : 16;
  int get BackgroundOffset => (memory.LCDC & 0x08) == 0 ? 0x9800 : 0x9C00;
  int get BackgroundTileSet => (memory.LCDC & 0x10) == 0 ? 1 : 0;
  bool get WindowEnabled => (memory.LCDC & 0x20) == 1;
  int get WindowTiles => (memory.LCDC & 0x40) == 0 ? 0 : 1;
  bool get DisplayEnabled => (memory.LCDC & 0x80) == 1;
  
  int Pallet(int index) {
    return (memory.BGP >> (index * 2)) & 0x3;
  }
  
  int BackgroundTile(int index) {
    int tile0 = memory.R(BackgroundOffset + index);
    
    if(BackgroundTileSet == 1) {
      int tile1 = Util.signed(tile0);
      return tile1 < 128 ? tile1 += 256 : tile1;
    }
    return tile0;
  }

  Uint8Array _scanline = new Uint8Array(512);
  
  void SetScanline(int offset, int value) {
    int scanlineOffset = offset * 2;
    if(value == 0) {
      _scanline[scanlineOffset] = 0;
      _scanline[scanlineOffset+1] = 0;
    } else if(value == 1) {
      _scanline[scanlineOffset] = 0;
      _scanline[scanlineOffset+1] = 96;
    } else if(value == 2) {
      _scanline[scanlineOffset] = 0;
      _scanline[scanlineOffset+1] = 192;
    } else {
      _scanline[scanlineOffset] = 0;
      _scanline[scanlineOffset+1] = 255;
    }
  }
  
  void renderScan() {
    int y = ScanLine;
    int scanlineOffset = 0;
    
    //print("Rendering Scanline $ScanLine");

    for(int x = 0; x < 32; ++x) {
      int backgroundIndex = x + ((y / 8).toInt() * 32);
      int tileIndex = BackgroundTile(backgroundIndex);
      int tileOffset = 0x8000 + (tileIndex * 16) + ((y % 8) * 2);
      
      int rowLow = memory.R(tileOffset);
      int rowHigh = memory.R(tileOffset+1) << 1;
      for(int i = 0; i < 8; ++i) {
        int tileValue = ((rowLow >> i) & 0x01) + ((rowHigh >> i) & 0x02);
        tileValue = Pallet(tileValue);
        
        SetScanline((x * 8) + (8 - i), tileValue);
      }
    }
    
    gl.bindTexture(GL.TEXTURE_2D, _frontBuffer.texture);
    gl.texSubImage2D(GL.TEXTURE_2D, 0, 0, y, 160, 1, GL.LUMINANCE_ALPHA, GL.UNSIGNED_BYTE, _scanline);
  }
  
  void clearScan() {
    int y = ScanLine;
    
    //print("Clearing Scanline $ScanLine");
    
    _scanline.forEach((el) => el = 0);
    gl.bindTexture(GL.TEXTURE_2D, _frontBuffer.texture);
    gl.texSubImage2D(GL.TEXTURE_2D, 0, 0, y, 160, 1, GL.LUMINANCE_ALPHA, GL.UNSIGNED_BYTE, _scanline);
  }
  
  void present() {
    gl.viewport(0, 0, gl.drawingBufferWidth, gl.drawingBufferHeight);
    
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