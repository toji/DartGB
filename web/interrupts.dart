part of dartgb;

typedef void InterruptFunc();

class Interrupts {
  List<InterruptFunc> interrupts = new List<InterruptFunc>(32);
  Gameboy gb = null;
  bool enabled = true;  
  bool halt = false;

  Interrupts(this.gb) {
    for (var i = 0; i < 32; ++i) {
      if ((i&1) == 1) interrupts[i] = vblank;
      else if ((i&2) == 1) interrupts[i] = stat;
      else if ((i&4) == 1) interrupts[i] = timer;
      else if ((i&8) == 1) interrupts[i] = serial;
      else if ((i&16) == 1) interrupts[i] = buttons;
      else interrupts[i] = () {};
    }
  }
  
  void run() {
    if (enabled)
      interrupts[gb.memory.IE & gb.memory.IF]();
  }
  
  void pushPC() {
    gb.memory.W(--gb.cpu.r['sp'], gb.cpu.r['pc']>>8);
    gb.memory.W(--gb.cpu.r['sp'], gb.cpu.r['pc']&0xFF);
  }
  
  // TODO: test if writing to memory.IF does the right thing.
  void vblank() {
    enabled = halt = false;
    gb.memory.W(gb.memory.IF, gb.memory.IF&0xFE);
    pushPC();
    gb.cpu.r['pc'] = 0x0040;
    gb.cpu.ticks += 32;
  }
  
  void stat() {
    enabled = halt = false;
    gb.memory.W(gb.memory.IF, gb.memory.IF&0xFD);
    pushPC();
    gb.cpu.r['pc'] = 0x0048;
    gb.cpu.ticks += 32;
  }

  void timer() {
    enabled = halt = false;
    gb.memory.W(gb.memory.IF, gb.memory.IF&0xFB);
    pushPC();
    gb.cpu.r['pc'] = 0x0050;
    gb.cpu.ticks += 32;
  }
  
  void serial() {
    enabled = halt = false;
    gb.memory.W(gb.memory.IF, gb.memory.IF&0xF7);
    pushPC();
    gb.cpu.r['pc'] = 0x0058;
    gb.cpu.ticks += 32;
  }
  
  void buttons() {
    enabled = halt = false;
    gb.memory.W(gb.memory.IF, gb.memory.IF&0xEF);
    pushPC();
    gb.cpu.r['pc'] = 0x0060;
    gb.cpu.ticks += 32;
  }
}
