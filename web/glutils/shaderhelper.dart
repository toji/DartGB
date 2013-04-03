part of glutils;

class ShaderHelper {
  GL.RenderingContext gl;
  GL.Program program;
  
  Map<String, int> attributes;
  Map<String, GL.UniformLocation> uniforms;
  
  ShaderHelper(GL.RenderingContext this.gl, String vs, String fs) {
    program = _buildProgram(vs, fs);
    if(program != null) {
      attributes = _queryAttributes(program);
      uniforms = _queryUniforms(program);
    }
  }
  
  GL.Program _buildProgram(String vs, String fs) {
    GL.Shader vertex = _compileShader(GL.VERTEX_SHADER, vs);
    GL.Shader fragment = _compileShader(GL.FRAGMENT_SHADER, fs);
    
    if(vertex == null || fragment == null) {
      gl.deleteShader(vertex);
      gl.deleteShader(fragment);
      return null; 
    }
    
    GL.Program program = gl.createProgram();
    gl.attachShader(program, vertex);
    gl.attachShader(program, fragment);
    gl.linkProgram(program);
    
    if (!gl.getProgramParameter(program, GL.LINK_STATUS)) {
      print("Shader program failed to link");
      gl.deleteProgram(program);
      gl.deleteShader(vertex);
      gl.deleteShader(fragment);
      return null;
    }
    
    return program;
  }
  
  GL.Shader _compileShader(int type, String source) {
    GL.Shader shader = gl.createShader(type);
    gl.shaderSource(shader, source);
    gl.compileShader(shader);

    if (!gl.getShaderParameter(shader, GL.COMPILE_STATUS)) {
      String typeString = "";
      switch(type) {
        case GL.VERTEX_SHADER: typeString = "Vertex"; break;
        case GL.FRAGMENT_SHADER: typeString = "Fragment"; break;
      }
      String infoLog = gl.getShaderInfoLog(shader);
      print("Error Compiling $typeString shader $infoLog");
      gl.deleteShader(shader);
      return null;
    }
    
    return shader;
  }
  
  Map<String, int> _queryAttributes(GL.Program program) {
    int count = gl.getProgramParameter(program, GL.ACTIVE_ATTRIBUTES);
    Map<String, int> attributes = new Map<String, int>();
    for (int i = 0; i < count; i++) {
      GL.ActiveInfo info = gl.getActiveAttrib(program, i);
      attributes[info.name] = gl.getAttribLocation(program, info.name);
    }
    return attributes;
  }
  
  Map<String, Object> _queryUniforms(GL.Program program) {
    int count = gl.getProgramParameter(program, GL.ACTIVE_UNIFORMS);
    Map<String, GL.UniformLocation> uniforms = new Map<String, GL.UniformLocation>();
    for (int i = 0; i < count; i++) {
      GL.ActiveInfo info = gl.getActiveUniform(program, i);
      String name = info.name.replaceAll("[0]", "");
      uniforms[name] = gl.getUniformLocation(program, name);
    }
    
    return uniforms;
  }
}

