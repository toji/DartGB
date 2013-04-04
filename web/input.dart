part of dartgb;

class Input {
  Memory memory = null;
  int pin14 = 0xEF;
  int pin15 = 0xDF;
  
  Input(this.memory) {
    window.onKeyDown.listen(onKeyDownEvent);
    window.onKeyUp.listen(onKeyUpEvent);
  }
  
  void read(int v) {
    switch ((v >> 4) & 3) {
      case 0:
        memory.P1 = pin14 & pin15;
        break;
      case 1:
        memory.P1 = pin15;
        break;
      case 2:
        memory.P1 = pin14;
        break;
      case 3:
        memory.P1 = 0xFF;
        break;
    };
  }
  
  void onKeyDownEvent(KeyboardEvent e) {
    switch (e.keyCode) {
      case 40:  // down
        pin14 &= 0xF7;
        memory.W(memory.IF, memory.IF|16);
        e.defaultPrevented = true;
        break;
      case 38:  // up
        pin14 &= 0xFB;
        memory.W(memory.IF, memory.IF|16);
        e.defaultPrevented = true;
        break;
      case 37:  // left
        pin14 &= 0xFD;
        memory.W(memory.IF, memory.IF|16);
        e.defaultPrevented = true;
        break;
      case 39:  // right
        pin14 &= 0xFE;
        memory.W(memory.IF, memory.IF|16);
        e.defaultPrevented = true;
        break;
      case 65:  // start
        pin15 &= 0xF7;
        memory.W(memory.IF, memory.IF|16);
        e.defaultPrevented = true;
        break;
      case 83:  // select
        pin15 &= 0xFB;
        memory.W(memory.IF, memory.IF|16);
        e.defaultPrevented = true;
        break;
      case 90:  // B
        pin15 &= 0xFD;
        memory.W(memory.IF, memory.IF|16);
        e.defaultPrevented = true;
        break;
      case 88:  // A
        pin15 &= 0xFE;
        memory.W(memory.IF, memory.IF|16);
        e.defaultPrevented = true;
        break;
    }
  }
  
  void onKeyUpEvent(KeyboardEvent e) {
    switch (e.keyCode) {
      case 40:  // down
        pin14 |= 0x8;
        memory.W(memory.IF, memory.IF|16);
        e.defaultPrevented = true;
        break;
      case 38:  // up
        pin14 |= 0x4;
        memory.W(memory.IF, memory.IF|16);
        e.defaultPrevented = true;
        break;
      case 37:  // left
        pin14 |= 0x2;
        memory.W(memory.IF, memory.IF|16);
        e.defaultPrevented = true;
        break;
      case 39:  // right
        pin14 |= 0x1;
        memory.W(memory.IF, memory.IF|16);
        e.defaultPrevented = true;
        break;
      case 65:  // start
        pin15 |= 0x8;
        memory.W(memory.IF, memory.IF|16);
        e.defaultPrevented = true;
        break;
      case 83:  // select
        pin15 |= 0x4;
        memory.W(memory.IF, memory.IF|16);
        e.defaultPrevented = true;
        break;
      case 90:  // B
        pin15 |= 0x2;
        memory.W(memory.IF, memory.IF|16);
        e.defaultPrevented = true;
        break;
      case 88:  // A
        pin15 |= 0x1;
        memory.W(memory.IF, memory.IF|16);
        e.defaultPrevented = true;
        break;
    }
  }
}
