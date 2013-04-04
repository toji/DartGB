part of dartgb;

typedef void InterruptFunc();

class Interrupts {
  List<InterruptFunc> interrupts = new List<InterruptFunc>();
  CPU cpu = null;
  Memory memory = null;
  bool enabled = false;
  bool halt = false;

  Interrupts(this.cpu, this.memory) {
    for (var i = 0; i < 32; ++i) {
      if (i&1) interrupts[i] = vblank;
      else if (i&2) interrupts[i] = stat;
      else if (i&4) interrupts[i] = timer;
      else if (i&8) interrupts[i] = serial;
      else if (i&16) interrupts[i] = buttons;
      else interrupts[i] = () {};
    }
  }
  
  void run() {
    if (enabled)
      interrupts[memory.IE & memory.IF]();
  }
  
  void pushPC() {
    memory.W(--cpu.r['sp'], cpu.r['pc']>>8);
    memory.W(--cpu.r['sp'], cpu.r['pc']&0xFF);
  }
  
  // TODO: test if writing to memory.IF does the right thing.
  void vblank() {
    enabled = halt = false;
    memory.W(memory.IF, memory.IF&0xFE);
    pushPC();
    cpu.r['pc'] = 0x0040;
    cpu.ticks += 32;
  }
  
  void stat() {
    enabled = halt = false;
    memory.W(memory.IF, memory.IF&0xFD);
    pushPC();
    cpu.r['pc'] = 0x0048;
    cpu.ticks += 32;
  }

  void timer() {
    enabled = halt = false;
    memory.W(memory.IF, memory.IF&0xFB);
    pushPC();
    cpu.r['pc'] = 0x0050;
    cpu.ticks += 32;
  }
  
  void serial() {
    enabled = halt = false;
    memory.W(memory.IF, memory.IF&0xF7);
    pushPC();
    cpu.r['pc'] = 0x0058;
    cpu.ticks += 32;
  }
  
  void buttons() {
    enabled = halt = false;
    memory.W(memory.IF, memory.IF&0xF7);
    pushPC();
    cpu.r['pc'] = 0x0060;
    cpu.ticks += 32;
  }
}
