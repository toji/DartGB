part of dartgb;

class LCD {
  // Really gl should have a _ in front, but I don't want to type that over and over again. :P
  GL.RenderingContext gl;
  CanvasElement _canvas;
  Memory memory;
  
  RenderTarget _frontBuffer;
  RenderTarget _background;
  TextureHelper _tiles;
  
  GL.Buffer _quadBuffer;
  
  ShaderHelper _blitShader;
  
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
    _canvas.width = (_canvas.clientWidth * window.devicePixelRatio).toInt();
    _canvas.height = (_canvas.clientHeight * window.devicePixelRatio).toInt();
    
    gl = _canvas.getContext3d(alpha: true, depth: false, antialias: false, preserveDrawingBuffer: true);
    gl.viewport(0, 0, gl.drawingBufferWidth, gl.drawingBufferHeight);
    
    gl.clearColor(0.0, 0.0, 1.0, 1.0);
    gl.clear(GL.COLOR_BUFFER_BIT);
    gl.clearColor(0.0, 0.0, 0.0, 0.0);
    
    // Allocate the front buffer
    _frontBuffer = new RenderTarget(gl, 256, 256, true);
    _background = new RenderTarget(gl, 512, 512, true);
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
    
    blitTile(_background, 0, 0, 0);
    blitTile(_background, 16, 8, 8);
    blitTile(_background, 32, 16, 16);
    blitTile(_background, 64, 32, 32);
    blitTile(_background, 128, 130, 130);
    
    blit(_tiles, _background, 0, 0, 0, 128, 24, 256);
    
    blit(_tiles, null, 0, 0, 512, 0, 24, 1024); 
    
    present(64, 64);
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
  
  Uint8Array _tileByteBuffer = new Uint8Array(256);
  
  void updateTile(int tileIndex) {
    int tileOffset = 0x8000 + (tileIndex * 16);
    int bufferOffset = 0;

    // Tiles are read one row at a time
    for(int i = 0; i < 8; ++i) {
      int rowLow = memory.R(tileOffset++);
      int rowHigh = memory.R(tileOffset++) << 1;
      
      for(int j = 0; j < 8; ++j) {
        int tileValue = ((rowLow >> j) & 0x01) + ((rowHigh >> j) & 0x02);
        //int tileValue = (i + j) % 4; // For Great Debugging!

        if(tileValue == 0) {
          _tileByteBuffer[bufferOffset++] = 255;
          _tileByteBuffer[bufferOffset++] = 255;
          _tileByteBuffer[bufferOffset++] = 255;
          _tileByteBuffer[bufferOffset++] = 0;
        } else if(tileValue == 1) {
          _tileByteBuffer[bufferOffset++] = 192;
          _tileByteBuffer[bufferOffset++] = 192;
          _tileByteBuffer[bufferOffset++] = 192;
          _tileByteBuffer[bufferOffset++] = 255;
        } else if(tileValue == 2) {
          _tileByteBuffer[bufferOffset++] = 96;
          _tileByteBuffer[bufferOffset++] = 96;
          _tileByteBuffer[bufferOffset++] = 96;
          _tileByteBuffer[bufferOffset++] = 255;
        } else {
          _tileByteBuffer[bufferOffset++] = 0;
          _tileByteBuffer[bufferOffset++] = 0;
          _tileByteBuffer[bufferOffset++] = 0;
          _tileByteBuffer[bufferOffset++] = 255;
        }
      }
    }
    
    int tileX = 8 * (tileIndex / 128).toInt();
    int tileY = 8 * (tileIndex % 128);
    
    gl.bindTexture(GL.TEXTURE_2D, _tiles.texture);
    gl.texSubImage2D(GL.TEXTURE_2D, 0, tileX, tileY, 8, 8, GL.RGBA, GL.UNSIGNED_BYTE, _tileByteBuffer);
  }
  
  void blitTile(RenderTarget target, int tileIndex, int x, int y) {
    int tileX = 8 * (tileIndex / 128).toInt();
    int tileY = 8 * (tileIndex % 128);
    blit(_tiles, target, tileX, tileY, x, y, 8, 8);  
  }
  
  void blitBackgroundTile(int tileIndex, int backgroundIndex) {
    // TODO: This may be wrong! Possibly need to wrap at 32 tiles instead of 64
    int backgroundX = (tileIndex % 64) * 8;
    int backgroundY = (tileIndex / 64).toInt() * 8;
    blitTile(_background, tileIndex, backgroundX, backgroundY);
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
    
    for (int i = 0; i < 384; i++) {
      if(memory.updatedTiles[i]) {
        updateTile(i);
      }
    }
    
    for (int i = 0; i < 2048; i++) {
      tile0 = memory.R(addr++);
      tile1 = 256 + Util.signed(tile0);
      
      if (memory.updatedTiles[tile0] || memory.updatedBackground[i]) {
        blitBackgroundTile(tile0, i);
      }
      if (memory.updatedTiles[tile1] || memory.updatedBackground[i]) {
        blitBackgroundTile(tile1, i);
      }
      memory.updatedBackground[i] = false;
      if ((col+= 8) >= 256) {
        col = 0;
        row += 8;
      }
    }
  }
  
  void simpleDrawScanline() {
    int i = 0;
    int j = 0;
    int k = 0;
    int x = 0;
    int y = 0;
    int offset = memory.LY * 160; // framebuffer's offset.
  }
  
  void present(int ScrollX, int ScrollY) {
    blit(_background.texture, null, ScrollX, ScrollY, 0, 0, 512, 512);
  }
}