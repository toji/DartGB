part of dartgb;

class LCD {
  // Really gl should have a _ in front, but I don't want to type that over and over again. :P
  GL.RenderingContext gl;
  CanvasElement _canvas;
  Memory memory;
  
  RenderTarget _frontBuffer;
  TextureHelper _tiles;
  
  GL.Buffer _quadBuffer;
  
  ShaderHelper _blitShader;
  
  List<List<List<int>>> tileData = null;
  List<List<int>> backgroundData = null;
  
  String _blitVS = """
    attribute vec2 Position;
    attribute vec2 TexCoord0;

    varying vec2 vTexCoord0;
    
    uniform mat3 clipMat;
    uniform mat3 imgMat;
    uniform vec2 srcOffset;
    uniform vec2 srcScale;
    uniform vec2 dstOffset;
    uniform vec2 dstScale; 

    void main() {
        vec2 srcBlitPos = (TexCoord0 * srcScale) + srcOffset;
        vTexCoord0 = (imgMat * vec3(srcBlitPos, 1.0)).xy;
        vec2 dstBlitPos = (Position * dstScale) + dstOffset;
        gl_Position = vec4(clipMat * vec3(dstBlitPos, 1.0), 1.0);
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
    initLCD();
    
    _canvas.width = (_canvas.clientWidth * window.devicePixelRatio).toInt();
    _canvas.height = (_canvas.clientHeight * window.devicePixelRatio).toInt();
    
    gl = _canvas.getContext3d(alpha: true, depth: false, antialias: false, preserveDrawingBuffer: true);
    gl.viewport(0, 0, gl.drawingBufferWidth, gl.drawingBufferHeight);
    
    gl.clearColor(0.0, 0.0, 1.0, 1.0);
    gl.clear(GL.COLOR_BUFFER_BIT);
    gl.clearColor(0.0, 0.0, 0.0, 0.0);
    //gl.pixelStorei(GL.UNPACK_FLIP_Y_WEBGL, 1);
    
    // Allocate the front buffer
    _frontBuffer = new RenderTarget(gl, 256, 256, true);
    _tiles = new TextureHelper(gl, 24, 1024);
    
    _blitShader = new ShaderHelper(gl, _blitVS, _blitFS);
    
    _quadBuffer = gl.createBuffer();
    gl.bindBuffer(GL.ARRAY_BUFFER, _quadBuffer);
    
    Float32Array verts = new Float32Array.fromList([
       0.0,  0.0,  0.0, 1.0,
       1.0,  0.0,  1.0, 1.0,
       1.0,  1.0,  1.0, 0.0,
      
       0.0,  0.0,  0.0, 1.0,
       1.0,  1.0,  1.0, 0.0,
       0.0,  1.0,  0.0, 0.0
    ]);
    
    gl.bufferData(GL.ARRAY_BUFFER, verts, GL.STATIC_DRAW);
    
    for(int i = 0; i < 384; ++i) {
      updateTile(i);
    }
    
    blitTile(0, 0, 0);
    blitTile(16, 8, 8);
    blitTile(32, 16, 16);
    blitTile(64, 32, 32);
    blitTile(128, 130, 130);
    
    blit(_tiles, _frontBuffer, 0, 0, 0, 128, 24, 256);
    
    blit(_tiles, null, 0, 0, 256, 0, 24, 1024); 
    blit(_tiles, null, 8, 8, 280, 8, 8, 8);
    
    present(64, 64);
  }
  
  Uint8Array _tileBuffer = new Uint8Array(256);
  
  void updateTile(int tileOffset) {
    for(int i = 0; i < 256; i+=4) {
      _tileBuffer[i] = (tileOffset % 256);
      _tileBuffer[i+1] = (tileOffset % 256);
      _tileBuffer[i+2] = (tileOffset % 256);
      _tileBuffer[i+3] = 255;
    }
    
    int tileX = 8 * (tileOffset / 128).toInt();
    int tileY = 8 * (tileOffset % 128);
    
    gl.bindTexture(GL.TEXTURE_2D, _tiles.texture);
    gl.texSubImage2D(GL.TEXTURE_2D, 0, tileX, tileY, 8, 8, GL.RGBA, GL.UNSIGNED_BYTE, _tileBuffer);
  }
  
  void blitTile(int tileOffset, int x, int y) {
    int tileX = 8 * (tileOffset / 128).toInt();
    int tileY = 8 * (tileOffset % 128);
    blit(_tiles, _frontBuffer, tileX, tileY, x, y, 8, 8);  
  }
  
  void blit(TextureHelper source, RenderTarget dest, int srcX, int srcY, int dstX, int dstY, int width, int height) {
    int dstWidth = dest != null ? dest.width : gl.drawingBufferWidth;
    int dstHeight = dest != null ? dest.height : gl.drawingBufferHeight;
    
    if(dest != null) {
      gl.bindTexture(GL.TEXTURE_2D, null);
      gl.bindFramebuffer(GL.FRAMEBUFFER, dest.framebuffer);
    } else {
      gl.bindFramebuffer(GL.FRAMEBUFFER, null);
    }
    
    gl.viewport(0, 0, dstWidth, dstHeight);
    
    gl.useProgram(_blitShader.program);
    
    gl.bindBuffer(GL.ARRAY_BUFFER, _quadBuffer);
    gl.enableVertexAttribArray(_blitShader.attributes["Position"]);
    gl.enableVertexAttribArray(_blitShader.attributes["TexCoord0"]);
    gl.vertexAttribPointer(_blitShader.attributes["Position"], 2, GL.FLOAT, false, 16, 0);
    gl.vertexAttribPointer(_blitShader.attributes["TexCoord0"], 2, GL.FLOAT, false, 16, 8);
    
    gl.activeTexture(GL.TEXTURE0);
    gl.uniform1i(_blitShader.uniforms["texture0"], 0);
    gl.bindTexture(GL.TEXTURE_2D, source.texture);
    
    _clipMat[0] = 2.0 / dstWidth;
    _clipMat[4] = -2.0 / dstHeight;
    _clipMat[6] = -1.0;
    _clipMat[7] = 1.0;
    _clipMat[8] = 1.0;
    
    _imgMat[0] = 1.0 / source.width;
    _imgMat[4] = -1.0 / source.height;
    _imgMat[6] = 0.0;
    _imgMat[7] = 0.0;
    _imgMat[8] = 1.0;
    
    gl.uniformMatrix3fv(_blitShader.uniforms["clipMat"], false, _clipMat);
    gl.uniformMatrix3fv(_blitShader.uniforms["imgMat"], false, _imgMat);
    gl.uniform2f(_blitShader.uniforms["dstOffset"], dstX, dstY);
    gl.uniform2f(_blitShader.uniforms["dstScale"], width, height);
    gl.uniform2f(_blitShader.uniforms["srcOffset"], srcX, srcY);
    gl.uniform2f(_blitShader.uniforms["srcScale"], width, height);
    
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
  
  void present(int ScrollX, int ScrollY) {
    blit(_frontBuffer.texture, null, ScrollX, ScrollY, 0, 0, 256, 256);
  }
}