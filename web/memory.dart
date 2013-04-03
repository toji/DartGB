part of dartgb;

class Memory {
  _mem = new Uint8List(0x10000);
  int get P1 =>   _mem[0xFF00];
  int get SC =>   _mem[0xFF02];
  int get DIV =>  _mem[0xFF04];
  int get TIMA => _mem[0xFF05];
  int get TMA =>  _mem[0xFF06];
  int get TAC =>  _mem[0xFF07];
  int get IF =>   _mem[0xFF0F];
  int get LCDC => _mem[0xFF40];
  int get STAT => _mem[0xFF41];
  int get SCY =>  _mem[0xFF42];
  int get SCX =>  _mem[0xFF43];
  int get LY =>   _mem[0xFF44];
  int get LYC =>  _mem[0xFF45];
  int get DMA =>  _mem[0xFF46];
  int get BGP =>  _mem[0xFF47];
  int get OBP0 => _mem[0xFF48];
  int get OBP1 => _mem[0xFF49];
  int get WY =>   _mem[0xFF4A];
  int get WX =>   _mem[0xFF4B];
  int get IE =>   _mem[0xFFFF];
  
  List<int> BackPal = new List<int>(4);
  List<List<int>> SpritePal = [new List<int>(4), new List<int>(4)];
    
  
  int R(int addr) {
    return _mem[addr]; 
  }
  
  void W(int addr, int val) {
    // Zero-page.
    if (addr >= 0xFF00) {
      switch (addr & 0xFF) {
        case 0x00:
          // TODO: handle joypad IO.
          return;
        case 0x02:
          // Serial cable not implemented.
          return;
        case 0x04:
          // Resets divider clock.
          _mem[addr] = 0;
          return;
        case 0x07:
          // Controls clocks.
          _mem[addr] = val;
          // TODO: timer on = val & 4
          // TODO: timer frequency = val & 3
        case 0x0F:
          // Interrupt flags.
          _mem[addr] = val & 31;
          return;
        case 0x40:
          // TODO: LCDC?
          _mem[addr] = val;
          return;
        case 0x41:
          // TODO: STAT?
          _mem[addr] = val;
          return;
        case 0x44:
          _mem[addr] = 0;
          return;
        case 0x46:
          // DMA transfer not implemented.
          return;
        case 0x47:
          // Background palettes.
          _mem[addr] = val;
          BackPal[0] = val & 3;
          BackPal[1] = (val >> 2) & 3;
          BackPal[2] = (val >> 4) & 3;
          BackPal[3] = (val >> 6) & 3;
          return;
        case 0x48:
          // Sprite palette 0.
          _mem[addr] = val;
          SpritePal[0][0] = val & 3;
          SpritePal[0][1] = (val >> 2) & 3;
          SpritePal[0][2] = (val >> 4) & 3;
          SpritePal[0][3] = (val >> 6) & 3;
          return;
        case 0x49:
          // Sprite palette 1.
          _mem[addr] = val;
          SpritePal[0][0] = val & 3;
          SpritePal[0][1] = (val >> 2) & 3;
          SpritePal[0][2] = (val >> 4) & 3;
          SpritePal[0][3] = (val >> 6) & 3;
          return;
        case 0xFF:
          // Interrupt enable.
          _mem[addr] = val & 31;
          return;
        default:
          _mem[addr] = val;
          return;
      }
    }
    
    // Writing to ROM?
    else if (addr < 0x800) {
      return; // TODO: support banked ROMs.
    }
    
    // Note updates to some locations.
    else if (_mem[addr] != val) {
      // 8000-97FF: Tile data.
      if (addr < 0x9800) {
        // TODO: Update tiles.
        _mem[addr] = val;
      // 9800-9FFF: Tile maps.
      } else if (addr < 0xA000) {
        // TODO: Update background tile maps.
        _mem[addr] = val;
      // A000-BFFF: Switchable RAM.
      } else if (addr < 0xC000) {
        _mem[addr] = val;
      // C000-DFFF: Internal RAM.
      } else if (addr < 0xE000) {
        _mem[addr] = val;
        if (addr < 0xDE00) { // Write to shadow RAM.
          _mem[addr + 0x2000] = val;
        }
      }
      // E000-FDFF: Shadow RAM.
      else if (addr < 0xFE00) {
        _mem[addr] = val;
        _mem[addr - 0x2000] = val;
      }
      // This last segment isn't part of shadow RAM.
      else {
        _mem[addr] = val;
      }
    }
  }
}