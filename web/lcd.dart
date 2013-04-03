part of dartgb;

class LCD {
  // Really gl should have a _ in front, but I don't want to type that over and over again. :P
  GL.RenderingContext gl;
  CanvasElement _canvas;
  Memory memory;
  
  RenderTarget _frontBuffer;
  GL.Buffer _quadBuffer;
  
  ShaderHelper _blitShader;
  
  String _blitVS = """
    attribute vec2 Position;
    attribute vec2 TexCoord0;

    varying vec2 vTexCoord0;
    
    uniform mat3 clipMat;
    uniform vec2 srcOffset;
    uniform vec2 srcScale;
    uniform vec2 dstOffset;
    uniform vec2 dstScale; 

    void main() {
        vTexCoord0 = (TexCoord0 * srcScale) + srcOffset;
        vec2 blitPosition = (Position * dstScale) + dstOffset;
        gl_Position = vec4(clipMat * vec3(blitPosition, 1.0), 1.0);
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

  LCD(CanvasElement this._canvas, Memory this.memory) {
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
    
    present(0, 0);
  }
  
  void blit(TextureHelper source, RenderTarget dest, int srcX, int srcY, int dstX, int dstY, int width, int height) {
    int dstWidth = dest != null ? dest.width : gl.drawingBufferWidth;
    int dstHeight = dest != null ? dest.height : gl.drawingBufferHeight;
    
    int srcWidth = source.width;
    int srcHeight = source.height;
    
    if(dest != null) {
      gl.bindFramebuffer(GL.FRAMEBUFFER, dest.framebuffer);
    } else {
      gl.bindFramebuffer(GL.FRAMEBUFFER, null);
    }
    
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
    
    gl.uniformMatrix3fv(_blitShader.uniforms["clipMat"], false, _clipMat);
    gl.uniform2f(_blitShader.uniforms["dstOffset"], dstX, dstY);
    gl.uniform2f(_blitShader.uniforms["dstScale"], width, height);
    gl.uniform2f(_blitShader.uniforms["srcOffset"], srcX, srcY);
    gl.uniform2f(_blitShader.uniforms["srcScale"], width, height);
    
    gl.drawArrays(GL.TRIANGLES, 0, 6);
  }
  
  void present(int ScrollX, int ScrollY) {
    blit(_frontBuffer.texture, null, ScrollX, ScrollY, 0, 0, 160, 144);
  }
}