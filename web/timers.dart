part of dartgb;

class Timers {
  int DIVTicks = 0;
  int CPUTicks = 0;
  int LCDTicks = 0;
  int timerTicks = 0;
  int FPS = 0;
  bool endFrame = false;

  Memory memory;
  
  Timers(this.memory);
  
  void control() {
    // DIV control.
    if ((DIVTicks += CPUTicks) >= 256) {
      DIVTicks -= 256;
      memory.DIV = (memory.DIV + 1) & 0xFF; // inc DIV
    }
    
    // LCD timing.
    LCDTicks += CPUTicks;
    if (LCDTicks >= 456) { // 1 scan line with h-blank is 456 ticks.
      LCDTicks -= 456;
      compareLYandLYC();
      if ((++memory.LY) >= 154) {
        memory.LY -= 154; // inc LY (current scanline)
      }
      if (memory.LY == 144) {
        mode1(); // 4560 ticks.
      } else if (memory.LY == 0) {
        endFrame = true;
        FPS++;
      }
    }
    if (memory.LY < 144) { // If not in v-blank.
      if (LCDTicks <= 204) {
        mode0(); // 204 cycles.
      } else if (LCDTicks <= 284) {
        mode2(); // 80 cycles.
      } else {
        mode3();
      }
    }
    
    // Internal timer.
    if (memory.TAC_timerOn) {
      if ((timerTicks += CPUTicks) >= memory.timerPeriod) {
        timerTicks -= memory.timerPeriod;
        if ((++memory.TIMA) >= 256) {
          memory.TIMA = memory.TMA;
          memory.IF |= 4;
        }
      }
    }
  }
  
  // h-blank.
  void mode0() {
    if (memory.STAT_mode != 0) {
      memory.STAT_mode = 0;
      if (memory.STAT_mode0) { // Toggles whether to use this interrupt.
        memory.IF |= 2;
      }
    }
  }
  
  // v-blank.
  void mode1() {
    memory.STAT_mode = 1;
    if (memory.STAT_mode1) { // Toggles whether to use this interrupt.
      memory.IF |= 2;
    }
    if (memory.LCDC_displayOn) {
      // TODO: display framebuffer.
    } else {
      // TODO: display blank screen?
    }
  }
  
  // OAM in use.
  void mode2() {
    if (memory.STAT_mode != 2) {
      memory.STAT_mode = 2;
      if (memory.STAT_mode2) {
        memory.IF |= 2;
      }
    }
  }
  
  // OAM + VRAM busy.
  void mode3() {
    if (memory.STAT_mode != 3) {
      memory.STAT_mode = 3;
      if (memory.STAT_mode2) {
        memory.IF |= 2;
      }
    }
  }
    
  void compareLYandLYC() {
    if (memory.LY == memory.LYC) {
      memory.STAT |= 0x04; // Set LY-LYC coincidence flag to 1.
      if (memory.STAT_LYLC) { // Toggles whether to use this interrupt.
        memory.IF |= 2; // Set second IF bit.
      }
    } else {
      memory.STAT &= 0xFB; // Set LY-LYC coincidence flag to 0.
    }
  }
}
