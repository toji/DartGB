part of dartgb;

class Input {
  Gameboy gb = null;
  int pin14 = 0xEF;
  int pin15 = 0xDF;
  
  Input(this.gb) {
    window.document.onKeyDown.listen(onKeyDownEvent);
    window.document.onKeyUp.listen(onKeyUpEvent);
  }
  
  void read(int v) {
    switch ((v >> 4) & 3) {
      case 0:
        gb.memory.P1 = pin14 & pin15;
        break;
      case 1:
        gb.memory.P1 = pin15;
        break;
      case 2:
        gb.memory.P1 = pin14;
        break;
      case 3:
        gb.memory.P1 = 0xFF;
        break;
    };
  }
  
  void onKeyDownEvent(KeyboardEvent e) {
    switch (e.keyCode) {
      case 40:  // down
        pin14 &= 0xF7;
        gb.memory.W(gb.memory.IF, gb.memory.IF|16);
        e.defaultPrevented = true;
        break;
      case 38:  // up
        pin14 &= 0xFB;
        gb.memory.W(gb.memory.IF, gb.memory.IF|16);
        e.defaultPrevented = true;
        break;
      case 37:  // left
        pin14 &= 0xFD;
        gb.memory.W(gb.memory.IF, gb.memory.IF|16);
        e.defaultPrevented = true;
        break;
      case 39:  // right
        pin14 &= 0xFE;
        gb.memory.W(gb.memory.IF, gb.memory.IF|16);
        e.defaultPrevented = true;
        break;
      case 65:  // start
        pin15 &= 0xF7;
        gb.memory.W(gb.memory.IF, gb.memory.IF|16);
        e.defaultPrevented = true;
        break;
      case 83:  // select
        pin15 &= 0xFB;
        gb.memory.W(gb.memory.IF, gb.memory.IF|16);
        e.defaultPrevented = true;
        break;
      case 90:  // B
        pin15 &= 0xFD;
        gb.memory.W(gb.memory.IF, gb.memory.IF|16);
        e.defaultPrevented = true;
        break;
      case 88:  // 
        pin15 &= 0xFE;
        gb.memory.W(gb.memory.IF, gb.memory.IF|16);
        e.defaultPrevented = true;
        break;
    }
  }
  
  void onKeyUpEvent(KeyboardEvent e) {
    switch (e.keyCode) {
      case 40:  // down
        pin14 |= 0x8;
        gb.memory.W(gb.memory.IF, gb.memory.IF|16);
        e.defaultPrevented = true;
        break;
      case 38:  // up
        pin14 |= 0x4;
        gb.memory.W(gb.memory.IF, gb.memory.IF|16);
        e.defaultPrevented = true;
        break;
      case 37:  // left
        pin14 |= 0x2;
        gb.memory.W(gb.memory.IF, gb.memory.IF|16);
        e.defaultPrevented = true;
        break;
      case 39:  // right
        pin14 |= 0x1;
        gb.memory.W(gb.memory.IF, gb.memory.IF|16);
        e.defaultPrevented = true;
        break;
      case 65:  // start
        pin15 |= 0x8;
        gb.memory.W(gb.memory.IF, gb.memory.IF|16);
        e.defaultPrevented = true;
        break;
      case 83:  // select
        pin15 |= 0x4;
        gb.memory.W(gb.memory.IF, gb.memory.IF|16);
        e.defaultPrevented = true;
        break;
      case 90:  // B
        pin15 |= 0x2;
        gb.memory.W(gb.memory.IF, gb.memory.IF|16);
        e.defaultPrevented = true;
        break;
      case 88:  // A
        pin15 |= 0x1;
        gb.memory.W(gb.memory.IF, gb.memory.IF|16);
        e.defaultPrevented = true;
        break;
    }
  }
}
