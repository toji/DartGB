part of dartgb;

class LCD {
  // Technically gl should have a _ in front, but I don't want to type that over and over again. :P
  GL.RenderingContext gl;
  CanvasElement _canvas;
  Memory memory;
  
  GL.Texture _frontBuffer;
  GL.Buffer _quadBuffer;
  
  ShaderHelper _blitShader;
  
  List<List<List<int>>> tileData = null;
  List<List<int>> backgroundData = null;
  
  String _blitVS = """
    attribute vec2 Position;
    attribute vec2 TexCoord0;

    varying vec2 vTexCoord0;

    void main() {
        vTexCoord0 = TexCoord0;
        gl_Position = vec4(Position, 0.0, 1.0);
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
  
  LCD(CanvasElement this._canvas, Memory this.memory) {
    // Initializes a few useful data structures.
    initLCD();
    
    gl = _canvas.getContext3d(alpha: true, depth: false, antialias: false, preserveDrawingBuffer: true);
    gl.clearColor(0.0, 0.0, 1.0, 1.0);
    gl.clear(GL.COLOR_BUFFER_BIT);
    gl.clearColor(0.0, 0.0, 0.0, 0.0);
    
    int numBytes = 160 * 144 * 4;
    Uint8Array bytes = new Uint8Array(numBytes);
    Random rnd = new Random();
    for(int i = 0; i < numBytes; ++i) {
      bytes[i] = rnd.nextInt(255);
    }
    
    // Allocate a texture for the front buffer
    _frontBuffer = gl.createTexture();
    gl.bindTexture(GL.TEXTURE_2D, _frontBuffer);
    gl.texImage2D(GL.TEXTURE_2D, 0, GL.RGBA, 160, 144, 0, GL.RGBA, GL.UNSIGNED_BYTE, bytes);
    gl.texParameteri(GL.TEXTURE_2D, GL.TEXTURE_MIN_FILTER, GL.NEAREST);
    gl.texParameteri(GL.TEXTURE_2D, GL.TEXTURE_MAG_FILTER, GL.NEAREST);
    gl.texParameteri(GL.TEXTURE_2D, GL.TEXTURE_WRAP_S, GL.CLAMP_TO_EDGE);
    gl.texParameteri(GL.TEXTURE_2D, GL.TEXTURE_WRAP_T, GL.CLAMP_TO_EDGE);
    
    _blitShader = new ShaderHelper(gl, _blitVS, _blitFS);
    
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
    
    blit(_frontBuffer);
  }
  
  void blit(GL.Texture source) {
    gl.clear(GL.COLOR_BUFFER_BIT);
    
    gl.useProgram(_blitShader.program);
    
    gl.bindBuffer(GL.ARRAY_BUFFER, _quadBuffer);
    gl.enableVertexAttribArray(_blitShader.attributes["Position"]);
    gl.enableVertexAttribArray(_blitShader.attributes["TexCoord0"]);
    gl.vertexAttribPointer(_blitShader.attributes["Position"], 2, GL.FLOAT, false, 16, 0);
    gl.vertexAttribPointer(_blitShader.attributes["TexCoord0"], 2, GL.FLOAT, false, 16, 8);
    
    gl.activeTexture(GL.TEXTURE0);
    gl.uniform1i(_blitShader.uniforms["texture0"], 0);
    gl.bindTexture(GL.TEXTURE_2D, source);
    
    gl.drawArrays(GL.TRIANGLES, 0, 6);
  }

  void initLCD() {
    // backgroundData is a big pixel map, 4 times the size of the 
    // 256x256 screen.
    backgroundData = new List<List<int>>(512);
    for (var i = 0; i < 512; i++) {
      backgroundData[i] = new List<int>(512);
    }
    
    // tileData is an array of tiles, each of which is an array of 8
    // lines, which each have 8 pixels.
    tileData = new List<List<List<int>>>(384);
    for (var i = 0; i < 384; i++) {
      tileData[i] = new List<List<int>>(8);
      for (var j = 0; j < 8; j++) {
        tileData[i][j] = new List<int>(8);
      }
    }
  }
  
  // Generally following the API used by jsgb.
  void updateBackground() {
    int tile0 = 0; // tile index for tiledata at 8000+(unsigned byte)
    int tile1 = 1; // tile index for tiledata at 8800+(signed byte)
    int addr = 0x9800; // for looping through the tile maps
    
    int col = 0;
    int row = 0;
    int z = 0; // Pixel within a single row
    int rowOffset = 0; // row within a tile
    List<int> tileline = null;
    List<int> backline = null;
    
    for (int i = 0; i < 2048; i++) {
      tile0 = memory.R(addr++);
      tile1 = 256 + Util.signed(tile0);
      if (memory.updatedTiles[i] || memory.updatedBackground[tile0]) {
        rowOffset = 8;
        while (row-- != 0) {
          tileline = tileData[tile0][rowOffset]; // 8px long.
          backline = backgroundData[row + rowOffset]; // 512px long.
          backline.setRange(col, 8, tileline);
        }
      }
      if (memory.updatedTiles[i] || memory.updatedBackground[tile1]) {
        rowOffset = 8;
        while (row-- != 0) {
          tileline = tileData[tile1][rowOffset];
          backline = backgroundData[row + rowOffset];
          backline.setRange(256 + col, 8, tileline); // +256 => on the right
        }
      }
      memory.updatedBackground[i] = false;
      if ((col+= 8) >= 256) {
        col = 0;
        row += 8;
      }
    }
  }
}