part of dartgb;

class Timers {
  Gameboy gb = null;
  int DIVTicks = 0;
  int LCDTicks = 0;
  int timerTicks = 0;
  int FPS = 0;
  bool endFrame = false;
  
  Timers(this.gb);
  
  void control() {
    // DIV control.
    if ((DIVTicks += gb.cpu.ticks) >= 256) {
      DIVTicks -= 256;
      gb.memory.DIV = (gb.memory.DIV + 1) & 0xFF; // inc DIV
    }
    
    // LCD timing.
    LCDTicks += gb.cpu.ticks;
    if (LCDTicks >= 456) { // 1 scan line with h-blank is 456 ticks.
      LCDTicks -= 456;
      compareLYandLYC();
      if ((++gb.memory.LY) >= 154) {
        gb.memory.LY -= 154; // inc LY (current scanline)
      }
      if (gb.memory.LY == 144) {
        mode1(); // 4560 ticks.
      } else if (gb.memory.LY == 0) {
        endFrame = true;
        FPS++;
      }
    }
    if (gb.memory.LY < 144) { // If not in v-blank.
      if (LCDTicks <= 204) {
        mode0(); // 204 cycles.
      } else if (LCDTicks <= 284) {
        mode2(); // 80 cycles.
      } else {
        mode3();
      }
    }
    
    // Internal timer.
    if (gb.memory.TAC_timerOn) {
      if ((timerTicks += gb.cpu.ticks) >= gb.memory.timerPeriod) {
        timerTicks -= gb.memory.timerPeriod;
        if ((++gb.memory.TIMA) >= 256) {
          gb.memory.TIMA = gb.memory.TMA;
          gb.memory.IF |= 4;
        }
      }
    }
  }
  
  // h-blank.
  void mode0() {
    if (gb.memory.STAT_mode != 0) {
      gb.memory.STAT_mode = 0;
      if (gb.memory.STAT_mode0) { // Toggles whether to use this interrupt.
        gb.memory.IF |= 2;
      }
    }
  }
  
  // v-blank.
  void mode1() {
    gb.memory.STAT_mode = 1;
    if (gb.memory.STAT_mode1) { // Toggles whether to use this interrupt.
      gb.memory.IF |= 2;
    }
    if (gb.memory.LCDC_displayOn) {
      gb.lcd.present();
    } else {
      gb.lcd.clear();
    }
  }
  
  // OAM in use.
  void mode2() {
    if (gb.memory.STAT_mode != 2) {
      gb.memory.STAT_mode = 2;
      if (gb.memory.STAT_mode2) {
        gb.memory.IF |= 2;
      }
    }
  }
  
  // OAM + VRAM busy.
  void mode3() {
    if (gb.memory.STAT_mode != 3) {
      gb.memory.STAT_mode = 3;
      if (gb.memory.LCDC_displayOn) {
        gb.lcd.renderScan();
      } else {
        gb.lcd.clearScan();
      }
    }
  }
    
  void compareLYandLYC() {
    if (gb.memory.LY == gb.memory.LYC) {
      gb.memory.STAT |= 0x04; // Set LY-LYC coincidence flag to 1.
      if (gb.memory.STAT_LYLC) { // Toggles whether to use this interrupt.
        gb.memory.IF |= 2; // Set second IF bit.
      }
    } else {
      gb.memory.STAT &= 0xFB; // Set LY-LYC coincidence flag to 0.
    }
  }
}
