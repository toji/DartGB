part of dartgb;

typedef void OpFunc();
//typedef String Mnemonic();

class CPU {
  Gameboy gb = null;
  int ticks = 0;
  
  Uint16List daaTable = new Uint16List(256 * 8);
  List<OpFunc> op = new List<OpFunc>(256);
  List<OpFunc> opcb = new List<OpFunc>(256);
  
  Map<String, int> r = {
    'a': 0x01,
    'fz': 0x01,  // bit 7 - zero
    'fn': 0x00,  // bit 6 - sub
    'fh': 0x01,  // bit 5 - half carry
    'fc': 0x01,  // bit 4 - carry
    'b': 0x00,
    'c': 0x13,
    'd': 0x00,
    'e': 0xD8,
    'hl': 0x014D,
    'sp': 0xFFFE,  // stack pointer
    'pc': 0x0100,  // program counter
    't1': 0x00,  // temporary registers
    't2': 0x00,
  };
  
  CPU(this.gb) {
    buildDAATable();
    buildOpCodes();
    buildOpCodeCBs();
  }
  
  void next() {
    if (gb.interrupts.halt)
      ticks = 4;
    else {
      var opCode = gb.memory.R(r['pc']);
      //print('PC ${r['pc'].toRadixString(16)}: ${opCode.toRadixString(16)}');
      ++r['pc'];
      op[opCode]();
    }
  }

  void UNKNOWN() {
    print("UNKNOWN");
    assert(false);
  }
  
  void NOP() {
    ticks = 0;
  }

  int RL(var n) {
    r['t1'] = r['fc'];
    r['fc'] = (n >> 7) & 1;
    n = ((n << 1) & 0xff) | r['t1'];
    r['fn'] = r['fh'] = 0;
    r['fz'] = (n == 0 ? 1 : 0);
    ticks = 8;
    return n;
  }

  int RLC(var n) {
    r['fc'] = (n >> 7) & 1;
    n = ((n << 1) & 0xff) | r['fc'];
    r['fn'] = r['fh'] = 0;
    r['fz'] = (n == 0 ? 1 : 0);
    ticks = 8;
    return n;
  }

  int RR(var n) {
    r['t1'] = r['fc'];
    r['fc'] = n & 1;
    n = (n >> 1) | (r['t1'] << 7);
    r['fn'] = r['fh'] = 0;
    r['fz'] = (n == 0 ? 1 : 0);
    ticks = 8;
    return n;
  }

  int RRC(var n) {
    r['fc'] = n & 1;
    n = (n >> 1) | (r['fc'] << 7);
    r['fn'] = r['fh'] = 0;
    r['fz'] = (n == 0 ? 1 : 0);
    ticks = 8;
    return n;
  }

  void SWAP(String reg) {
    if (reg == 'h') {
      var hl = r['hl'];
      r['hl'] = ((hl & 0x0F00) << 4) | ((hl & 0xF000) >> 4) | (hl & 0x00FF);
    } else if (reg == 'l') {
      var hl = r['hl'];
      r['hl'] = ((hl & 0x000F) << 4) | ((hl & 0x00F0) >> 4) | (hl & 0xFF00);
    } else if (reg == 'hl') {
      var hl = r['hl'];
      r['t1'] = gb.memory.R(r['hl']);
      gb.memory.W(r['hl'], ((r['t1']<<4)|(r['t1']>>4)) & 0xFF);
    } else {
      var new_r = r[reg];
      r[reg] = ((new_r<<4) | (new_r>>4)) & 0xFF;
    }
    ticks = 8;
  }
  
  void ADD_A(String reg, int t) {
    r['fh'] = ((r['a'] & 0x0F) + (r[reg] & 0x0F)) > 0x0F ? 1 : 0;
    r['fc'] = ((r['a'] & 0xFF) + (r[reg] & 0xFF)) > 0xFF ? 1 : 0;
    r['a'] = (r['a'] + r[reg]) & 0xFF;
    r['fz'] = (r['a'] == 0 ? 1 : 0);
    r['fn'] = 0;
    ticks = t;
  }
  
  void ADC_A(String reg, int t) {
    r['t2'] = r['fc'];
    r['fh'] = ((r['a'] & 0x0F) + (r[reg] & 0x0F) + r['t2']) > 0x0F ? 1 : 0;
    r['fc'] = ((r['a'] & 0xFF) + (r[reg] & 0xFF) + r['t2']) > 0xFF ? 1 : 0;
    r['a'] = (r['a'] + r[reg] + r['t2']) & 0xFF;
    r['fz'] = (r['a'] == 0 ? 1 : 0);
    r['fn'] = 0;
    ticks = t;
  }
  
  void SUB_A(String reg, int t) {
    if (reg == 'a') {
      r['fh'] = 0;
      r['fc'] = 0;
      r['a'] = 0;
      r['fz'] = 1;
    } else {
      r['fh'] = (r['a'] & 0x0F) < (r[reg] & 0x0F) ? 1 : 0;
      r['fc'] = (r['a'] & 0xFF) < (r[reg] & 0xFF) ? 1 : 0;
      r['a'] = (r['a'] - r[reg]) & 0xFF;
      r['fz'] = (r['a'] == 0 ? 1 : 0);
    }
    r['fn'] = 1;
    ticks = t;
  }
  
  void SBC_A(String reg, int t) {
    r['t2'] = r['fc'];
    r['fh'] = (r['a'] & 0x0F) < ((r[reg] & 0x0F) + r['t2']) ? 1 : 0;
    r['fc'] = (r['a'] & 0xFF) < ((r[reg] & 0xFF) + r['t2']) ? 1 : 0;
    r['a'] = (r['a'] - r[reg] - r['t2']) & 0xFF;
    r['fz'] = (r['a'] == 0 ? 1 : 0);
    r['fn'] = 1;
    ticks = t;
  }
  
  void AND_A(String reg, int t) {
    if (reg != 'a')
      r['a'] &= r[reg];
    r['fz'] = r['a'] == 0 ? 1 : 0;
    r['fh'] = 1;
    r['fn'] = r['fc'] = 0;
    ticks = t;
  }
  
  void XOR_A(String reg, int t) {
    if (reg != 'a') {
      r['a'] = 0;
      r['fz'] = 1;
    } else {
      r['a'] ^= r[reg];
      r['fz'] = r['a'] == 0 ? 1 : 0;
    }
    r['fh'] = r['fn'] = r['fc'] = 0;
    ticks = t;
  }
  
  void CP_A(String reg, int t) {
    r['fz'] = r['a'] == r[reg] ? 1 : 0;
    r['fn'] = 1;
    r['fc'] = r['a'] < r[reg] ? 1 : 0;
    r['fh'] = (r['a'] & 0x0F) < (r[reg] & 0x0F) ? 1 : 0;
    ticks = t;
  }
  
  void OR_A(String reg, int t) {
    if (reg != 'a')
      r['a'] |= r[reg];
    r['fz'] = r['a'] == 0 ? 1 : 0;
    r['fh'] = r['fn'] = r['fc'] = 0;
    ticks = t;    
  }
  
  void SLA_R(String reg, int t) {
    r['fc'] = (r[reg] >> 7) & 1;
    r[reg] = (r[reg] << 1) & 0xFF;
    r['fn'] = r['fh'] = 0;
    r['fz'] = (r[reg] == 0 ? 1 : 0);
    ticks = t;
  }

  int INC16(int n) {
    ticks = 8;
    return (n + 1) & 0xFFFF;
  }

  void INC(String reg, int t) {
    r[reg] = (r[reg] + 1) & 0xFF;
    r['fz'] = r[reg] == 0 ? 1 : 0;
    r['fn'] = 0;
    r['fh'] = (r[reg] & 0xF) == 0 ? 1 : 0;
    ticks = t;
  }

  void DEC(String reg, int t) {
    r[reg] = (r[reg] - 1) & 0xFF;
    r['fz'] = (r[reg] == 0 ? 1 : 0);
    r['fn'] = 1;
    r['fh'] = (r[reg] & 0xF) == 0xF ? 1 : 0;
    ticks = t;
  }

  int ADD16(int n1, int n2) {
    r['fn'] = 0;
    r['fh'] = ((n1 & 0xFFF) + (n2 & 0xFFF)) > 0xFFF ? 1 : 0;
    n1 += n2;
    r['fc'] = (n1 > 0xFFFF ? 1 : 0);
    n1 &= 0xFFFF;
    ticks = 8;
    return n1;
  }

  void JR(bool c) {
    if (c) {
      r['pc'] += Util.signed(gb.memory.R(r['pc'])) + 1;
      ticks = 12;
    } else {
      r['pc']++;
      ticks = 8;
    }
  }

  void JP(bool c) {
    if (c) {
      var new_pc = (gb.memory.R(r['pc'] + 1) << 8) | gb.memory.R(r['pc']);
      r['pc'] = new_pc;
    } else {
      r['pc'] += 2;
    }
    ticks = 12;
  }

  void CALL(bool c) {
    if (c) {
      r['pc'] += 2;
      gb.memory.W(--r['sp'], r['pc'] >> 8);
      gb.memory.W(--r['sp'], r['pc'] & 0xFF);
      r['pc'] = (gb.memory.R(r['pc'] - 1) << 8) | gb.memory.R(r['pc'] - 2);
    } else {
      r['pc'] += 2;
    }
    ticks = 12;
  }

  void RST(int a) {
    gb.memory.W(--r['sp'], r['pc'] >> 8);
    gb.memory.W(--r['sp'], r['pc'] & 0xFF);
    r['pc'] = a;
    ticks = 32;
  }

  void RET(bool c) {
    if (c) {
      r['pc'] = (gb.memory.R(r['sp'] + 1) << 8) | gb.memory.R(r['sp']);
      r['sp'] += 2;
    }
    ticks = 8;
  }

  void RLA() {
    r['t1'] = r['fc'];
    r['fc'] = (r['a'] >> 7) & 1;
    r['a'] = ((r['a'] << 1) & 0xFF) | r['t1'];
    r['fn'] = r['fh'] = 0;
    r['fz'] = r['a'] == 0 ? 1 : 0;
    ticks = 4;
  }

  void HALT() {
    if (gb.interrupts.enabled)
      gb.interrupts.halt = true;
    else {
      print('HALT with interrupts disabled');
      assert(false);
    }
    ticks = 4;
  }

  void LD_MEM_R16(String reg, int t) {
    r['t1'] = (gb.memory.R(r['pc'] + 1) << 8) + gb.memory.R(r['pc']);
    gb.memory.W(r['t1'], r[reg] & 0xFF);
    gb.memory.W(r['t1'] + 1, r[reg] >> 8);
    r['pc'] += 2;
    ticks = t;
  }
  
  void DDA() {
    r['t1'] = r['a'];
    if (r['fc'] == 1)
      r['t1'] |= 256;
    if (r['fh'] == 1)
      r['t1'] |= 512;
    if (r['fn'] == 1)
      r['t1'] |= 1024;
    r['t1'] = daaTable[r['t1']];
    r['a'] = r['t1'] >> 8;
    r['fz'] = (r['t1'] >> 7) & 1;
    r['fn'] = (r['t1'] >> 6) & 1;
    r['fh'] = (r['t1'] >> 5) & 1;
    r['fc'] = (r['t1'] >> 4) & 1;
    ticks = 4;
  }
 
  void buildDAATable() {
    daaTable.setRange(0, daaTable.length, [
      0x0080,0x0100,0x0200,0x0300,0x0400,0x0500,0x0600,0x0700,
      0x0800,0x0900,0x1020,0x1120,0x1220,0x1320,0x1420,0x1520,
      0x1000,0x1100,0x1200,0x1300,0x1400,0x1500,0x1600,0x1700,
      0x1800,0x1900,0x2020,0x2120,0x2220,0x2320,0x2420,0x2520,
      0x2000,0x2100,0x2200,0x2300,0x2400,0x2500,0x2600,0x2700,
      0x2800,0x2900,0x3020,0x3120,0x3220,0x3320,0x3420,0x3520,
      0x3000,0x3100,0x3200,0x3300,0x3400,0x3500,0x3600,0x3700,
      0x3800,0x3900,0x4020,0x4120,0x4220,0x4320,0x4420,0x4520,
      0x4000,0x4100,0x4200,0x4300,0x4400,0x4500,0x4600,0x4700,
      0x4800,0x4900,0x5020,0x5120,0x5220,0x5320,0x5420,0x5520,
      0x5000,0x5100,0x5200,0x5300,0x5400,0x5500,0x5600,0x5700,
      0x5800,0x5900,0x6020,0x6120,0x6220,0x6320,0x6420,0x6520,
      0x6000,0x6100,0x6200,0x6300,0x6400,0x6500,0x6600,0x6700,
      0x6800,0x6900,0x7020,0x7120,0x7220,0x7320,0x7420,0x7520,
      0x7000,0x7100,0x7200,0x7300,0x7400,0x7500,0x7600,0x7700,
      0x7800,0x7900,0x8020,0x8120,0x8220,0x8320,0x8420,0x8520,
      0x8000,0x8100,0x8200,0x8300,0x8400,0x8500,0x8600,0x8700,
      0x8800,0x8900,0x9020,0x9120,0x9220,0x9320,0x9420,0x9520,
      0x9000,0x9100,0x9200,0x9300,0x9400,0x9500,0x9600,0x9700,
      0x9800,0x9900,0x00B0,0x0130,0x0230,0x0330,0x0430,0x0530,
      0x0090,0x0110,0x0210,0x0310,0x0410,0x0510,0x0610,0x0710,
      0x0810,0x0910,0x1030,0x1130,0x1230,0x1330,0x1430,0x1530,
      0x1010,0x1110,0x1210,0x1310,0x1410,0x1510,0x1610,0x1710,
      0x1810,0x1910,0x2030,0x2130,0x2230,0x2330,0x2430,0x2530,
      0x2010,0x2110,0x2210,0x2310,0x2410,0x2510,0x2610,0x2710,
      0x2810,0x2910,0x3030,0x3130,0x3230,0x3330,0x3430,0x3530,
      0x3010,0x3110,0x3210,0x3310,0x3410,0x3510,0x3610,0x3710,
      0x3810,0x3910,0x4030,0x4130,0x4230,0x4330,0x4430,0x4530,
      0x4010,0x4110,0x4210,0x4310,0x4410,0x4510,0x4610,0x4710,
      0x4810,0x4910,0x5030,0x5130,0x5230,0x5330,0x5430,0x5530,
      0x5010,0x5110,0x5210,0x5310,0x5410,0x5510,0x5610,0x5710,
      0x5810,0x5910,0x6030,0x6130,0x6230,0x6330,0x6430,0x6530,
      0x6010,0x6110,0x6210,0x6310,0x6410,0x6510,0x6610,0x6710,
      0x6810,0x6910,0x7030,0x7130,0x7230,0x7330,0x7430,0x7530,
      0x7010,0x7110,0x7210,0x7310,0x7410,0x7510,0x7610,0x7710,
      0x7810,0x7910,0x8030,0x8130,0x8230,0x8330,0x8430,0x8530,
      0x8010,0x8110,0x8210,0x8310,0x8410,0x8510,0x8610,0x8710,
      0x8810,0x8910,0x9030,0x9130,0x9230,0x9330,0x9430,0x9530,
      0x9010,0x9110,0x9210,0x9310,0x9410,0x9510,0x9610,0x9710,
      0x9810,0x9910,0xA030,0xA130,0xA230,0xA330,0xA430,0xA530,
      0xA010,0xA110,0xA210,0xA310,0xA410,0xA510,0xA610,0xA710,
      0xA810,0xA910,0xB030,0xB130,0xB230,0xB330,0xB430,0xB530,
      0xB010,0xB110,0xB210,0xB310,0xB410,0xB510,0xB610,0xB710,
      0xB810,0xB910,0xC030,0xC130,0xC230,0xC330,0xC430,0xC530,
      0xC010,0xC110,0xC210,0xC310,0xC410,0xC510,0xC610,0xC710,
      0xC810,0xC910,0xD030,0xD130,0xD230,0xD330,0xD430,0xD530,
      0xD010,0xD110,0xD210,0xD310,0xD410,0xD510,0xD610,0xD710,
      0xD810,0xD910,0xE030,0xE130,0xE230,0xE330,0xE430,0xE530,
      0xE010,0xE110,0xE210,0xE310,0xE410,0xE510,0xE610,0xE710,
      0xE810,0xE910,0xF030,0xF130,0xF230,0xF330,0xF430,0xF530,
      0xF010,0xF110,0xF210,0xF310,0xF410,0xF510,0xF610,0xF710,
      0xF810,0xF910,0x00B0,0x0130,0x0230,0x0330,0x0430,0x0530,
      0x0090,0x0110,0x0210,0x0310,0x0410,0x0510,0x0610,0x0710,
      0x0810,0x0910,0x1030,0x1130,0x1230,0x1330,0x1430,0x1530,
      0x1010,0x1110,0x1210,0x1310,0x1410,0x1510,0x1610,0x1710,
      0x1810,0x1910,0x2030,0x2130,0x2230,0x2330,0x2430,0x2530,
      0x2010,0x2110,0x2210,0x2310,0x2410,0x2510,0x2610,0x2710,
      0x2810,0x2910,0x3030,0x3130,0x3230,0x3330,0x3430,0x3530,
      0x3010,0x3110,0x3210,0x3310,0x3410,0x3510,0x3610,0x3710,
      0x3810,0x3910,0x4030,0x4130,0x4230,0x4330,0x4430,0x4530,
      0x4010,0x4110,0x4210,0x4310,0x4410,0x4510,0x4610,0x4710,
      0x4810,0x4910,0x5030,0x5130,0x5230,0x5330,0x5430,0x5530,
      0x5010,0x5110,0x5210,0x5310,0x5410,0x5510,0x5610,0x5710,
      0x5810,0x5910,0x6030,0x6130,0x6230,0x6330,0x6430,0x6530,
      0x0600,0x0700,0x0800,0x0900,0x0A00,0x0B00,0x0C00,0x0D00,
      0x0E00,0x0F00,0x1020,0x1120,0x1220,0x1320,0x1420,0x1520,
      0x1600,0x1700,0x1800,0x1900,0x1A00,0x1B00,0x1C00,0x1D00,
      0x1E00,0x1F00,0x2020,0x2120,0x2220,0x2320,0x2420,0x2520,
      0x2600,0x2700,0x2800,0x2900,0x2A00,0x2B00,0x2C00,0x2D00,
      0x2E00,0x2F00,0x3020,0x3120,0x3220,0x3320,0x3420,0x3520,
      0x3600,0x3700,0x3800,0x3900,0x3A00,0x3B00,0x3C00,0x3D00,
      0x3E00,0x3F00,0x4020,0x4120,0x4220,0x4320,0x4420,0x4520,
      0x4600,0x4700,0x4800,0x4900,0x4A00,0x4B00,0x4C00,0x4D00,
      0x4E00,0x4F00,0x5020,0x5120,0x5220,0x5320,0x5420,0x5520,
      0x5600,0x5700,0x5800,0x5900,0x5A00,0x5B00,0x5C00,0x5D00,
      0x5E00,0x5F00,0x6020,0x6120,0x6220,0x6320,0x6420,0x6520,
      0x6600,0x6700,0x6800,0x6900,0x6A00,0x6B00,0x6C00,0x6D00,
      0x6E00,0x6F00,0x7020,0x7120,0x7220,0x7320,0x7420,0x7520,
      0x7600,0x7700,0x7800,0x7900,0x7A00,0x7B00,0x7C00,0x7D00,
      0x7E00,0x7F00,0x8020,0x8120,0x8220,0x8320,0x8420,0x8520,
      0x8600,0x8700,0x8800,0x8900,0x8A00,0x8B00,0x8C00,0x8D00,
      0x8E00,0x8F00,0x9020,0x9120,0x9220,0x9320,0x9420,0x9520,
      0x9600,0x9700,0x9800,0x9900,0x9A00,0x9B00,0x9C00,0x9D00,
      0x9E00,0x9F00,0x00B0,0x0130,0x0230,0x0330,0x0430,0x0530,
      0x0610,0x0710,0x0810,0x0910,0x0A10,0x0B10,0x0C10,0x0D10,
      0x0E10,0x0F10,0x1030,0x1130,0x1230,0x1330,0x1430,0x1530,
      0x1610,0x1710,0x1810,0x1910,0x1A10,0x1B10,0x1C10,0x1D10,
      0x1E10,0x1F10,0x2030,0x2130,0x2230,0x2330,0x2430,0x2530,
      0x2610,0x2710,0x2810,0x2910,0x2A10,0x2B10,0x2C10,0x2D10,
      0x2E10,0x2F10,0x3030,0x3130,0x3230,0x3330,0x3430,0x3530,
      0x3610,0x3710,0x3810,0x3910,0x3A10,0x3B10,0x3C10,0x3D10,
      0x3E10,0x3F10,0x4030,0x4130,0x4230,0x4330,0x4430,0x4530,
      0x4610,0x4710,0x4810,0x4910,0x4A10,0x4B10,0x4C10,0x4D10,
      0x4E10,0x4F10,0x5030,0x5130,0x5230,0x5330,0x5430,0x5530,
      0x5610,0x5710,0x5810,0x5910,0x5A10,0x5B10,0x5C10,0x5D10,
      0x5E10,0x5F10,0x6030,0x6130,0x6230,0x6330,0x6430,0x6530,
      0x6610,0x6710,0x6810,0x6910,0x6A10,0x6B10,0x6C10,0x6D10,
      0x6E10,0x6F10,0x7030,0x7130,0x7230,0x7330,0x7430,0x7530,
      0x7610,0x7710,0x7810,0x7910,0x7A10,0x7B10,0x7C10,0x7D10,
      0x7E10,0x7F10,0x8030,0x8130,0x8230,0x8330,0x8430,0x8530,
      0x8610,0x8710,0x8810,0x8910,0x8A10,0x8B10,0x8C10,0x8D10,
      0x8E10,0x8F10,0x9030,0x9130,0x9230,0x9330,0x9430,0x9530,
      0x9610,0x9710,0x9810,0x9910,0x9A10,0x9B10,0x9C10,0x9D10,
      0x9E10,0x9F10,0xA030,0xA130,0xA230,0xA330,0xA430,0xA530,
      0xA610,0xA710,0xA810,0xA910,0xAA10,0xAB10,0xAC10,0xAD10,
      0xAE10,0xAF10,0xB030,0xB130,0xB230,0xB330,0xB430,0xB530,
      0xB610,0xB710,0xB810,0xB910,0xBA10,0xBB10,0xBC10,0xBD10,
      0xBE10,0xBF10,0xC030,0xC130,0xC230,0xC330,0xC430,0xC530,
      0xC610,0xC710,0xC810,0xC910,0xCA10,0xCB10,0xCC10,0xCD10,
      0xCE10,0xCF10,0xD030,0xD130,0xD230,0xD330,0xD430,0xD530,
      0xD610,0xD710,0xD810,0xD910,0xDA10,0xDB10,0xDC10,0xDD10,
      0xDE10,0xDF10,0xE030,0xE130,0xE230,0xE330,0xE430,0xE530,
      0xE610,0xE710,0xE810,0xE910,0xEA10,0xEB10,0xEC10,0xED10,
      0xEE10,0xEF10,0xF030,0xF130,0xF230,0xF330,0xF430,0xF530,
      0xF610,0xF710,0xF810,0xF910,0xFA10,0xFB10,0xFC10,0xFD10,
      0xFE10,0xFF10,0x00B0,0x0130,0x0230,0x0330,0x0430,0x0530,
      0x0610,0x0710,0x0810,0x0910,0x0A10,0x0B10,0x0C10,0x0D10,
      0x0E10,0x0F10,0x1030,0x1130,0x1230,0x1330,0x1430,0x1530,
      0x1610,0x1710,0x1810,0x1910,0x1A10,0x1B10,0x1C10,0x1D10,
      0x1E10,0x1F10,0x2030,0x2130,0x2230,0x2330,0x2430,0x2530,
      0x2610,0x2710,0x2810,0x2910,0x2A10,0x2B10,0x2C10,0x2D10,
      0x2E10,0x2F10,0x3030,0x3130,0x3230,0x3330,0x3430,0x3530,
      0x3610,0x3710,0x3810,0x3910,0x3A10,0x3B10,0x3C10,0x3D10,
      0x3E10,0x3F10,0x4030,0x4130,0x4230,0x4330,0x4430,0x4530,
      0x4610,0x4710,0x4810,0x4910,0x4A10,0x4B10,0x4C10,0x4D10,
      0x4E10,0x4F10,0x5030,0x5130,0x5230,0x5330,0x5430,0x5530,
      0x5610,0x5710,0x5810,0x5910,0x5A10,0x5B10,0x5C10,0x5D10,
      0x5E10,0x5F10,0x6030,0x6130,0x6230,0x6330,0x6430,0x6530,
      0x00C0,0x0140,0x0240,0x0340,0x0440,0x0540,0x0640,0x0740,
      0x0840,0x0940,0x0440,0x0540,0x0640,0x0740,0x0840,0x0940,
      0x1040,0x1140,0x1240,0x1340,0x1440,0x1540,0x1640,0x1740,
      0x1840,0x1940,0x1440,0x1540,0x1640,0x1740,0x1840,0x1940,
      0x2040,0x2140,0x2240,0x2340,0x2440,0x2540,0x2640,0x2740,
      0x2840,0x2940,0x2440,0x2540,0x2640,0x2740,0x2840,0x2940,
      0x3040,0x3140,0x3240,0x3340,0x3440,0x3540,0x3640,0x3740,
      0x3840,0x3940,0x3440,0x3540,0x3640,0x3740,0x3840,0x3940,
      0x4040,0x4140,0x4240,0x4340,0x4440,0x4540,0x4640,0x4740,
      0x4840,0x4940,0x4440,0x4540,0x4640,0x4740,0x4840,0x4940,
      0x5040,0x5140,0x5240,0x5340,0x5440,0x5540,0x5640,0x5740,
      0x5840,0x5940,0x5440,0x5540,0x5640,0x5740,0x5840,0x5940,
      0x6040,0x6140,0x6240,0x6340,0x6440,0x6540,0x6640,0x6740,
      0x6840,0x6940,0x6440,0x6540,0x6640,0x6740,0x6840,0x6940,
      0x7040,0x7140,0x7240,0x7340,0x7440,0x7540,0x7640,0x7740,
      0x7840,0x7940,0x7440,0x7540,0x7640,0x7740,0x7840,0x7940,
      0x8040,0x8140,0x8240,0x8340,0x8440,0x8540,0x8640,0x8740,
      0x8840,0x8940,0x8440,0x8540,0x8640,0x8740,0x8840,0x8940,
      0x9040,0x9140,0x9240,0x9340,0x9440,0x9540,0x9640,0x9740,
      0x9840,0x9940,0x3450,0x3550,0x3650,0x3750,0x3850,0x3950,
      0x4050,0x4150,0x4250,0x4350,0x4450,0x4550,0x4650,0x4750,
      0x4850,0x4950,0x4450,0x4550,0x4650,0x4750,0x4850,0x4950,
      0x5050,0x5150,0x5250,0x5350,0x5450,0x5550,0x5650,0x5750,
      0x5850,0x5950,0x5450,0x5550,0x5650,0x5750,0x5850,0x5950,
      0x6050,0x6150,0x6250,0x6350,0x6450,0x6550,0x6650,0x6750,
      0x6850,0x6950,0x6450,0x6550,0x6650,0x6750,0x6850,0x6950,
      0x7050,0x7150,0x7250,0x7350,0x7450,0x7550,0x7650,0x7750,
      0x7850,0x7950,0x7450,0x7550,0x7650,0x7750,0x7850,0x7950,
      0x8050,0x8150,0x8250,0x8350,0x8450,0x8550,0x8650,0x8750,
      0x8850,0x8950,0x8450,0x8550,0x8650,0x8750,0x8850,0x8950,
      0x9050,0x9150,0x9250,0x9350,0x9450,0x9550,0x9650,0x9750,
      0x9850,0x9950,0x9450,0x9550,0x9650,0x9750,0x9850,0x9950,
      0xA050,0xA150,0xA250,0xA350,0xA450,0xA550,0xA650,0xA750,
      0xA850,0xA950,0xA450,0xA550,0xA650,0xA750,0xA850,0xA950,
      0xB050,0xB150,0xB250,0xB350,0xB450,0xB550,0xB650,0xB750,
      0xB850,0xB950,0xB450,0xB550,0xB650,0xB750,0xB850,0xB950,
      0xC050,0xC150,0xC250,0xC350,0xC450,0xC550,0xC650,0xC750,
      0xC850,0xC950,0xC450,0xC550,0xC650,0xC750,0xC850,0xC950,
      0xD050,0xD150,0xD250,0xD350,0xD450,0xD550,0xD650,0xD750,
      0xD850,0xD950,0xD450,0xD550,0xD650,0xD750,0xD850,0xD950,
      0xE050,0xE150,0xE250,0xE350,0xE450,0xE550,0xE650,0xE750,
      0xE850,0xE950,0xE450,0xE550,0xE650,0xE750,0xE850,0xE950,
      0xF050,0xF150,0xF250,0xF350,0xF450,0xF550,0xF650,0xF750,
      0xF850,0xF950,0xF450,0xF550,0xF650,0xF750,0xF850,0xF950,
      0x00D0,0x0150,0x0250,0x0350,0x0450,0x0550,0x0650,0x0750,
      0x0850,0x0950,0x0450,0x0550,0x0650,0x0750,0x0850,0x0950,
      0x1050,0x1150,0x1250,0x1350,0x1450,0x1550,0x1650,0x1750,
      0x1850,0x1950,0x1450,0x1550,0x1650,0x1750,0x1850,0x1950,
      0x2050,0x2150,0x2250,0x2350,0x2450,0x2550,0x2650,0x2750,
      0x2850,0x2950,0x2450,0x2550,0x2650,0x2750,0x2850,0x2950,
      0x3050,0x3150,0x3250,0x3350,0x3450,0x3550,0x3650,0x3750,
      0x3850,0x3950,0x3450,0x3550,0x3650,0x3750,0x3850,0x3950,
      0x4050,0x4150,0x4250,0x4350,0x4450,0x4550,0x4650,0x4750,
      0x4850,0x4950,0x4450,0x4550,0x4650,0x4750,0x4850,0x4950,
      0x5050,0x5150,0x5250,0x5350,0x5450,0x5550,0x5650,0x5750,
      0x5850,0x5950,0x5450,0x5550,0x5650,0x5750,0x5850,0x5950,
      0x6050,0x6150,0x6250,0x6350,0x6450,0x6550,0x6650,0x6750,
      0x6850,0x6950,0x6450,0x6550,0x6650,0x6750,0x6850,0x6950,
      0x7050,0x7150,0x7250,0x7350,0x7450,0x7550,0x7650,0x7750,
      0x7850,0x7950,0x7450,0x7550,0x7650,0x7750,0x7850,0x7950,
      0x8050,0x8150,0x8250,0x8350,0x8450,0x8550,0x8650,0x8750,
      0x8850,0x8950,0x8450,0x8550,0x8650,0x8750,0x8850,0x8950,
      0x9050,0x9150,0x9250,0x9350,0x9450,0x9550,0x9650,0x9750,
      0x9850,0x9950,0x9450,0x9550,0x9650,0x9750,0x9850,0x9950,
      0xFA60,0xFB60,0xFC60,0xFD60,0xFE60,0xFF60,0x00C0,0x0140,
      0x0240,0x0340,0x0440,0x0540,0x0640,0x0740,0x0840,0x0940,
      0x0A60,0x0B60,0x0C60,0x0D60,0x0E60,0x0F60,0x1040,0x1140,
      0x1240,0x1340,0x1440,0x1540,0x1640,0x1740,0x1840,0x1940,
      0x1A60,0x1B60,0x1C60,0x1D60,0x1E60,0x1F60,0x2040,0x2140,
      0x2240,0x2340,0x2440,0x2540,0x2640,0x2740,0x2840,0x2940,
      0x2A60,0x2B60,0x2C60,0x2D60,0x2E60,0x2F60,0x3040,0x3140,
      0x3240,0x3340,0x3440,0x3540,0x3640,0x3740,0x3840,0x3940,
      0x3A60,0x3B60,0x3C60,0x3D60,0x3E60,0x3F60,0x4040,0x4140,
      0x4240,0x4340,0x4440,0x4540,0x4640,0x4740,0x4840,0x4940,
      0x4A60,0x4B60,0x4C60,0x4D60,0x4E60,0x4F60,0x5040,0x5140,
      0x5240,0x5340,0x5440,0x5540,0x5640,0x5740,0x5840,0x5940,
      0x5A60,0x5B60,0x5C60,0x5D60,0x5E60,0x5F60,0x6040,0x6140,
      0x6240,0x6340,0x6440,0x6540,0x6640,0x6740,0x6840,0x6940,
      0x6A60,0x6B60,0x6C60,0x6D60,0x6E60,0x6F60,0x7040,0x7140,
      0x7240,0x7340,0x7440,0x7540,0x7640,0x7740,0x7840,0x7940,
      0x7A60,0x7B60,0x7C60,0x7D60,0x7E60,0x7F60,0x8040,0x8140,
      0x8240,0x8340,0x8440,0x8540,0x8640,0x8740,0x8840,0x8940,
      0x8A60,0x8B60,0x8C60,0x8D60,0x8E60,0x8F60,0x9040,0x9140,
      0x9240,0x9340,0x3450,0x3550,0x3650,0x3750,0x3850,0x3950,
      0x3A70,0x3B70,0x3C70,0x3D70,0x3E70,0x3F70,0x4050,0x4150,
      0x4250,0x4350,0x4450,0x4550,0x4650,0x4750,0x4850,0x4950,
      0x4A70,0x4B70,0x4C70,0x4D70,0x4E70,0x4F70,0x5050,0x5150,
      0x5250,0x5350,0x5450,0x5550,0x5650,0x5750,0x5850,0x5950,
      0x5A70,0x5B70,0x5C70,0x5D70,0x5E70,0x5F70,0x6050,0x6150,
      0x6250,0x6350,0x6450,0x6550,0x6650,0x6750,0x6850,0x6950,
      0x6A70,0x6B70,0x6C70,0x6D70,0x6E70,0x6F70,0x7050,0x7150,
      0x7250,0x7350,0x7450,0x7550,0x7650,0x7750,0x7850,0x7950,
      0x7A70,0x7B70,0x7C70,0x7D70,0x7E70,0x7F70,0x8050,0x8150,
      0x8250,0x8350,0x8450,0x8550,0x8650,0x8750,0x8850,0x8950,
      0x8A70,0x8B70,0x8C70,0x8D70,0x8E70,0x8F70,0x9050,0x9150,
      0x9250,0x9350,0x9450,0x9550,0x9650,0x9750,0x9850,0x9950,
      0x9A70,0x9B70,0x9C70,0x9D70,0x9E70,0x9F70,0xA050,0xA150,
      0xA250,0xA350,0xA450,0xA550,0xA650,0xA750,0xA850,0xA950,
      0xAA70,0xAB70,0xAC70,0xAD70,0xAE70,0xAF70,0xB050,0xB150,
      0xB250,0xB350,0xB450,0xB550,0xB650,0xB750,0xB850,0xB950,
      0xBA70,0xBB70,0xBC70,0xBD70,0xBE70,0xBF70,0xC050,0xC150,
      0xC250,0xC350,0xC450,0xC550,0xC650,0xC750,0xC850,0xC950,
      0xCA70,0xCB70,0xCC70,0xCD70,0xCE70,0xCF70,0xD050,0xD150,
      0xD250,0xD350,0xD450,0xD550,0xD650,0xD750,0xD850,0xD950,
      0xDA70,0xDB70,0xDC70,0xDD70,0xDE70,0xDF70,0xE050,0xE150,
      0xE250,0xE350,0xE450,0xE550,0xE650,0xE750,0xE850,0xE950,
      0xEA70,0xEB70,0xEC70,0xED70,0xEE70,0xEF70,0xF050,0xF150,
      0xF250,0xF350,0xF450,0xF550,0xF650,0xF750,0xF850,0xF950,
      0xFA70,0xFB70,0xFC70,0xFD70,0xFE70,0xFF70,0x00D0,0x0150,
      0x0250,0x0350,0x0450,0x0550,0x0650,0x0750,0x0850,0x0950,
      0x0A70,0x0B70,0x0C70,0x0D70,0x0E70,0x0F70,0x1050,0x1150,
      0x1250,0x1350,0x1450,0x1550,0x1650,0x1750,0x1850,0x1950,
      0x1A70,0x1B70,0x1C70,0x1D70,0x1E70,0x1F70,0x2050,0x2150,
      0x2250,0x2350,0x2450,0x2550,0x2650,0x2750,0x2850,0x2950,
      0x2A70,0x2B70,0x2C70,0x2D70,0x2E70,0x2F70,0x3050,0x3150,
      0x3250,0x3350,0x3450,0x3550,0x3650,0x3750,0x3850,0x3950,
      0x3A70,0x3B70,0x3C70,0x3D70,0x3E70,0x3F70,0x4050,0x4150,
      0x4250,0x4350,0x4450,0x4550,0x4650,0x4750,0x4850,0x4950,
      0x4A70,0x4B70,0x4C70,0x4D70,0x4E70,0x4F70,0x5050,0x5150,
      0x5250,0x5350,0x5450,0x5550,0x5650,0x5750,0x5850,0x5950,
      0x5A70,0x5B70,0x5C70,0x5D70,0x5E70,0x5F70,0x6050,0x6150,
      0x6250,0x6350,0x6450,0x6550,0x6650,0x6750,0x6850,0x6950,
      0x6A70,0x6B70,0x6C70,0x6D70,0x6E70,0x6F70,0x7050,0x7150,
      0x7250,0x7350,0x7450,0x7550,0x7650,0x7750,0x7850,0x7950,
      0x7A70,0x7B70,0x7C70,0x7D70,0x7E70,0x7F70,0x8050,0x8150,
      0x8250,0x8350,0x8450,0x8550,0x8650,0x8750,0x8850,0x8950,
      0x8A70,0x8B70,0x8C70,0x8D70,0x8E70,0x8F70,0x9050,0x9150,
      0x9250,0x9350,0x9450,0x9550,0x9650,0x9750,0x9850,0x9950
    ]);
  }
  
  void buildOpCodes() {
    // NOP
    op[0x00] = NOP;
    // LD BC, u16
    op[0x01] = () {
        r['c'] = gb.memory.R(r['pc']++);
        r['b'] = gb.memory.R(r['pc']++);
        ticks = 12;
    };
    // LD (BC), A
    op[0x02] = () {
        gb.memory.W((r['b'] << 8) | r['c'], r['a']);
        ticks = 8;
    };
    // INC BC
    op[0x03] = () {
        r['t1'] = INC16((r['b'] << 8) | r['c']);
        r['b'] = r['t1'] >> 8;
        r['c'] = r['t1'] & 0xFF;
    };
    // INC B
    op[0x04] = () { INC('b', 4); };
    // DEC B
    op[0x05] = () { DEC('b', 4); };
    // LD B, u8
    op[0x06] = () { r['b'] = gb.memory.R(r['pc']++); ticks = 8; };
    // RLCA
    op[0x07] = () {
        r['fc'] = (r['a'] >> 7) & 1;
        r['a'] = (r['a'] << 1) & 0xFF | r['fc'];
        r['fn'] = r['fh'] = 0;
        r['fz'] = r['a'] == 0 ? 1 : 0;
        ticks = 4;
    };
    // LD (u16), SP
    op[0x08] = () { LD_MEM_R16('hl', 20); };
    // ADD HL, BC
    op[0x09] = () {
        r['hl'] = ADD16(r['hl'], (r['b'] << 8) | r['c']); ticks = 8;
    };
    // LD A,(BC)
    op[0x0A] = () {
        r['a'] = gb.memory.R(((r['b'] & 0x00FF) << 8) | r['c']);
        ticks = 8;
    };
    // DEC BC
    op[0x0B] = () {
        var bc = ((r['b'] << 8) + r['c'] - 1) & 0xFFFF;
        r['b'] = bc >> 8;
        r['c'] = bc & 0xFF;
        ticks = 8;
    };
    // INC C
    op[0x0C] = () { INC('c', 4); };
    // DEC C
    op[0x0D] = () { DEC('c', 4); };
    // LD C,u8
    op[0x0E] = () { r['c'] = gb.memory.R(r['pc']++); ticks = 8; };
    // RRCA
    op[0x0F] = () {
        r['fc'] = r['a'] & 1;
        r['a'] = (r['a'] >> 1) | (r['fc'] << 7);
        r['fn'] = r['fh'] = 0;
        r['fz'] = (r['a'] == 0 ? 1 : 0);
        ticks = 4;
    };
    // STOP
    op[0x10] = () {
        print('STOP');
        assert(false);
        ticks = 4;
    };
    // LD DE,u16
    op[0x11] = () {
        r['e'] = gb.memory.R(r['pc']++);
        r['d'] = gb.memory.R(r['pc']++);
        ticks = 12;
    };
    // LD (DE), A
    op[0x12] = () {
        gb.memory.W((r['d'] << 8) | r['e'], r['a']);
        ticks = 8;
    };
    // INC DE
    op[0x13] = () {
        r['t1'] = INC16((r['d'] << 8) | r['e']);
        r['d'] = r['t1'] >> 8;
        r['e'] = r['t1'] & 0xFF;
    };
    // INC D
    op[0x14] = () { INC('d', 4); };
    // DEC D
    op[0x15] = () { DEC('d', 4); };
    // LD D,u8
    op[0x16] = () { r['d'] = gb.memory.R(r['pc']++); ticks = 8; };
    // RLA
    op[0x17] = () { RLA(); };
    // JR s8
    op[0x18] = () { JR(true); };
    // ADD HL,DE
    op[0x19] = () { r['hl'] = ADD16(r['hl'], (r['d'] << 8) | r['e']); };
    // LD A,(DE)
    op[0x1A] = () {
        r['a'] = gb.memory.R(((r['d'] & 0x00FF) << 8) | r['e']);
        ticks = 8;
    };
    // DEC DE
    op[0x1B] = () {
        var de = ((r['d'] << 8) + r['e'] - 1) & 0xFFFF;
        r['d'] = de >> 8;
        r['e'] = de & 0xFF;
        ticks = 8;
    };
    // INC E
    op[0x1C] = () { INC('e', 4); };
    // DEC E
    op[0x1D] = () { DEC('e', 4); };
    // LD E,u8
    op[0x1E] = () {
        r['e'] = gb.memory.R(r['pc']++);
        ticks = 8;
    };
    // RRA
    op[0x1F] = () {
        r['t1'] = r['fc'];
        r['fc'] = r['a'] & 1;
        r['a'] = (r['a'] >> 1) | (r['t1'] << 7);
        r['fn'] = r['fh'] = 0;
        r['fz'] = r['a'] == 0 ? 1 : 0;
        ticks = 4;
    };
    // JR NZ,s8
    op[0x20] = () { JR(r['fz'] == 0); };
    // LD HL,u16
    op[0x21] = () {
        r['hl'] = (gb.memory.R(r['pc'] + 1) << 8) | gb.memory.R(r['pc']);
        r['pc'] += 2;
        ticks = 12;
    };
    // LDI (HL),A
    op[0x22] = () {
      gb.memory.W(r['hl'], r['a']);
      r['hl'] = (r['hl'] + 1) & 0xFFFF;
      ticks = 8;
    };
    // INC HL
    op[0x23] = () { r['hl'] = INC16(r['hl']); };
    // INC H
    op[0x24] = () {
        r['t1'] = r['hl'] >> 8;
        INC('t1', 4);
        r['hl'] = (r['hl'] & 0x00FF)|(r['t1'] << 8);
    };
    // DEC H
    op[0x25] = () {
        r['t1'] = r['hl'] >> 8;
        DEC('t1', 4);
        r['hl'] = (r['hl'] & 0x00FF)|(r['t1'] << 8);
    };
    // LD H,u8
    op[0x26] = () {
        r['hl'] &= 0x00FF;
        r['hl'] |= gb.memory.R(r['pc']++)<<8;
        ticks = 8;
    };
    // DAA
    op[0x27] = () { DDA(); };
    // JR Z,s8
    op[0x28] = () { JR(r['fz'] == 1); };
    // ADD HL,HL
    op[0x29] = () { r['hl'] = ADD16(r['hl'], r['hl']); };
    // LDI A,(HL)
    op[0x2A] = () {
        r['a'] = gb.memory.R(r['hl']);
        r['hl'] = (r['hl'] + 1) & 0xFFFF;
        ticks = 8;
    };
    // DEC HL
    op[0x2B] = () {
        r['hl'] = (r['hl'] - 1) & 0xFFFF;
        ticks = 8;
    };
    // INC L
    op[0x2C] = () {
        r['t1'] = r['hl'] & 0xFF;
        INC('t1', 4);
        r['hl'] = (r['hl'] & 0xFF00) | r['t1'];
    };
    // DEC L
    op[0x2D] = () {
        r['t1'] = r['hl'] & 0xFF;
        DEC('t1', 4);
        r['hl'] = (r['hl'] & 0xFF00) | r['t1'];
    };
    // LD L,u8
    op[0x2E] = () {
        r['hl'] &= 0xFF00; r['hl'] |= gb.memory.R(r['pc']++);
        ticks = 8;
    };
    // CPL
    op[0x2F] = () {
        r['a'] ^= 0xFF;
        r['fn'] = 1;
        r['fh'] = 1;
        ticks = 4;
    };
    // JR NC,s8
    op[0x30] = () { JR(r['fc'] == 0); };
    // LD SP,u16
    op[0x31] = () {
        r['sp'] = (gb.memory.R(r['pc'] + 1) << 8) | gb.memory.R(r['pc']);
        r['pc'] += 2;
        ticks = 12;
    };
    // LDD (HL),A
    op[0x32] = () {
        gb.memory.W(r['hl'], r['a']);
        r['hl'] = (r['hl'] - 1) & 0xFFFF;
        ticks = 8;
    };
    // INC SP
    op[0x33] = () { r['sp'] = INC16(r['sp']); };
    // INC (HL)
    op[0x34] = () {
        r['t1'] = gb.memory.R(r['hl']);
        INC('t1', 12);
        gb.memory.W(r['hl'], r['t1']);
    };
    // DEC (HL)
    op[0x35] = () {
      r['t1'] = gb.memory.R(r['hl']);
      DEC('t1', 12);
      gb.memory.W(r['hl'], r['t1']);

    };
    // LD (HL),u8
    op[0x36] = () {
      gb.memory.W(r['hl'], gb.memory.R(r['pc']++));
      ticks = 12;
    };
    // SCF
    op[0x37] = () {
        r['fc'] = 1;
        r['fn'] = 0;
        r['fh'] = 0;
        ticks = 4;
    };
    // JR C,s8
    op[0x38] = () { JR(r['fc'] == 1); };
    // ADD HL,SP
    op[0x39] = () { r['hl'] = ADD16(r['hl'], r['sp']); };
    // LDD A,(HL)
    op[0x3A] = () {
        r['a'] = gb.memory.R(r['hl']);
        r['hl'] = (r['hl'] - 1) & 0xFFFF;
        ticks = 8;
    };
    // DEC SP
    op[0x3B] = () {
      r['sp'] = (r['sp'] - 1) & 0xFFFF;
      ticks = 8;
    };
    // INC A
    op[0x3C] = () { INC('a', 4); };
    // DEC A
    op[0x3D] = () { DEC('a', 4); };
    // LD A,u8
    op[0x3E] = () {
        r['a'] = gb.memory.R(r['pc']++);
        ticks = 8;
    };
    // CCF
    op[0x3F] = () {
      r['fc'] = (~r['fc']) & 1;
      r['fn'] = r['fh'] = 0;
      ticks = 4;
    };
    // LD B,B
    op[0x40] = NOP;
    // LD B,C
    op[0x41] = () { r['b'] = r['c']; ticks = 4; };
    // LD B,D
    op[0x42] = () { r['b'] = r['d']; ticks = 4; };
    // LD B,E
    op[0x43] = () { r['b'] = r['e']; ticks = 4; };
    // LD B,H
    op[0x44] = () { r['b'] = r['hl'] >> 8; ticks = 4; };
    // LD B,L
    op[0x45] = () { r['b'] = r['hl'] & 0xFF; ticks = 4; };
    // LD B,(HL)
    op[0x46] = () { r['b'] = gb.memory.R(r['hl']); ticks = 8; };
    // LD B,A
    op[0x47] = () { r['b'] = r['a']; ticks = 4; };
    // LD C,B
    op[0x48] = () { r['c'] = r['b']; ticks = 4; };
    // LD C,C
    op[0x49] = NOP;
    // LD C,D
    op[0x4A] = () { r['c'] = r['d']; ticks = 4; };
    // LD C,E
    op[0x4B] = () { r['c'] = r['e']; ticks = 4; };
    // LD C,H
    op[0x4C] = () { r['c'] = r['hl'] >> 8; ticks = 4; };
    // LD C,L
    op[0x4D] = () { r['c'] = r['hl'] & 0xFF; ticks = 4; };
    // LD C,(HL)
    op[0x4E] = () { r['c'] = gb.memory.R(r['hl']); ticks = 8; };
    // LD C,A
    op[0x4F] = () { r['c'] = r['a']; ticks = 4; };
    // LD D,B
    op[0x50] = () { r['d'] = r['b']; ticks = 4; };
    // LD D,C
    op[0x51] = () { r['d'] = r['c']; ticks = 4; };
    // LD D,D
    op[0x52] = NOP;
    // LD D,E
    op[0x53] = () { r['d'] = r['e']; ticks = 4; };
    // LD D,H
    op[0x54] = () { r['d'] = r['hl'] >> 8; ticks = 4; };
    // LD D,L
    op[0x55] = () { r['d'] = r['hl'] & 0xFF; ticks = 4; };
    // LD D,(HL)
    op[0x56] = () { r['d'] = gb.memory.R(r['hl']); ticks = 8; };
    // LD D,A
    op[0x57] = () { r['d'] = r['a']; ticks = 4; };
    // LD E,B
    op[0x58] = () { r['e'] = r['b']; ticks = 4; };
    // LD E,C
    op[0x59] = () { r['e'] = r['c']; ticks = 4; };
    // LD E,D
    op[0x5A] = () { r['e'] = r['d']; ticks = 4; };
    // LD E,E
    op[0x5B] = NOP;
    // LD E,H
    op[0x5C] = () { r['e'] = r['hl'] >> 8; ticks = 4; };
    // LD E,L
    op[0x5D] = () { r['e'] = r['hl'] & 0xFF; ticks = 4; };
    // LD E,(HL)
    op[0x5E] = () { r['e'] = gb.memory.R(r['hl']); ticks = 8; };
    // LD E,A
    op[0x5F] = () { r['e'] = r['a']; ticks = 4; };
    // LD H,B
    op[0x60] = () { r['hl'] = (r['hl']&0x00FF)|(r['b']<<8); ticks = 4; };
    // LD H,C
    op[0x61] = () { r['hl'] = (r['hl']&0x00FF)|(r['c']<<8); ticks = 4; };
    // LD H,D
    op[0x62] = () { r['hl'] = (r['hl']&0x00FF)|(r['d']<<8); ticks = 4; };
    // LD H,E
    op[0x63] = () { r['hl'] = (r['hl']&0x00FF)|(r['e']<<8); ticks = 4; };
    // LD H,H
    op[0x64] = NOP;
    // LD H,L
    op[0x65] = () { r['hl'] = (r['hl']&0x00FF)|((r['hl']&0xFF)<<8); ticks = 4; };
    // LD H,(HL)
    op[0x66] = () { r['hl'] = (r['hl']&0x00FF)|(gb.memory.R(r['hl'])<<8); ticks = 8; };
    // LD H,A
    op[0x67] = () { r['hl'] = (r['hl']&0x00FF)|(r['a']<<8); ticks = 4; };
    // LD L,B
    op[0x68] = () { r['hl'] = (r['hl']&0xFF00)|r['b']; ticks = 4; };
    // LD L,C
    op[0x69] = () { r['hl'] = (r['hl']&0xFF00)|r['c']; ticks = 4; };
    // LD L,D
    op[0x6A] = () { r['hl'] = (r['hl']&0xFF00)|r['d']; ticks = 4; };
    // LD L,E
    op[0x6B] = () { r['hl'] = (r['hl']&0xFF00)|r['e']; ticks = 4; };
    // LD L,H
    op[0x6C] = () { r['hl'] = (r['hl']&0xFF00)|(r['hl']>>8); ticks = 4; };
    // LD L,L
    op[0x6D] = NOP;
    // LD L,(HL)
    op[0x6E] = () { r['hl'] = (r['hl']&0xFF00)|(gb.memory.R(r['hl'])); ticks = 8; };
    // LD L,A
    op[0x6F] = () { r['hl'] = (r['hl']&0xFF00)|r['a']; ticks = 4; };
    // LD (HL), B
    op[0x70] = () { gb.memory.W(r['hl'], r['b']); ticks = 8; };
    // LD (HL), C
    op[0x71] = () { gb.memory.W(r['hl'], r['c']); ticks = 8; };
    // LD (HL), D
    op[0x72] = () { gb.memory.W(r['hl'], r['d']); ticks = 8; };
    // LD (HL), E
    op[0x73] = () { gb.memory.W(r['hl'], r['e']); ticks = 8; };
    // LD (HL), H
    op[0x74] = () { gb.memory.W(r['hl'], r['hl'] >> 8); ticks = 8; };
    // LD (HL), L
    op[0x75] = () { gb.memory.W(r['hl'], r['hl'] & 0x00FF); ticks = 8; };
    // HALT
    op[0x76] = HALT;
    // LD (HL), A
    op[0x77] = () { gb.memory.W(r['hl'], r['a']); ticks = 8; };
    // LD A,B
    op[0x78] = () { r['a'] = r['b']; ticks = 4; };
    // LD A,C
    op[0x79] = () { r['a'] = r['c']; ticks = 4; };
    // LD A,D
    op[0x7A] = () { r['a'] = r['d']; ticks = 4; };
    // LD A,E
    op[0x7B] = () { r['a'] = r['e']; ticks = 4; };
    // LD A,H
    op[0x7C] = () { r['a'] = r['hl'] >> 8; ticks = 4; };
    // LD A,L
    op[0x7D] = () { r['a'] = r['hl'] & 0x00FF; ticks = 4; };
    // LD A,(HL)
    op[0x7E] = () { r['a'] = gb.memory.R(r['hl']); ticks = 8; };
    // LD A, A
    op[0x7F] = NOP;
    // ADD A,B
    op[0x80] = () { ADD_A('b', 4); };
    // ADD A,C
    op[0x81] = () { ADD_A('c', 4); };
    // ADD A,D
    op[0x82] = () { ADD_A('d', 4); };
    // ADD A,E
    op[0x83] = () { ADD_A('e', 4); };
    // ADD A,H
    op[0x84] = () { r['t1'] = r['hl'] >> 8; ADD_A('t1', 4); };
    // ADD A,L
    op[0x85] = () { r['t1'] = r['hl'] & 0x00FF; ADD_A('t1', 4); };
    // ADD A,(HL)
    op[0x86] = () { r['t1'] = gb.memory.R(r['hl']); ADD_A('t1', 4); };
    // ADD A,A
    op[0x87] = () { ADD_A('a', 4); };
    // ADC A,B
    op[0x88] = () { ADC_A('b', 4); };
    // ADC A,C
    op[0x89] = () { ADC_A('c', 4); };
    // ADC A,D
    op[0x8A] = () { ADC_A('d', 4); };
    // ADC A,E
    op[0x8B] = () { ADC_A('e', 4); };
    // ADC A,H
    op[0x8C] = () { r['t1'] = r['hl'] >> 8; ADC_A('t1', 4); };
    // ADC A,L
    op[0x8D] = () { r['t1'] = r['hl'] & 0xFF; ADC_A('t1', 4); };
    // ADC A,(HL)
    op[0x8E] = () { r['t1'] = gb.memory.R(r['hl']); ADC_A('t1', 8); };
    // ADC A,A
    op[0x8F] = () { ADC_A('a', 4); };
    // SUB B
    op[0x90] = () { SUB_A('b', 4); };
    // SUB C
    op[0x91] = () { SUB_A('c', 4); };
    // SUB D
    op[0x92] = () { SUB_A('d', 4); };
    // SUB E
    op[0x93] = () { SUB_A('e', 4); };
    // SUB H
    op[0x94] = () { r['t1'] = r['hl'] >> 8; SUB_A('t1', 4); };
    // SUB L
    op[0x95] = () { r['t1'] = r['hl'] & 0xFF; SUB_A('t1', 4); };
    // SUB (HL)
    op[0x96] = () { r['t1'] = gb.memory.R(r['h1']); SUB_A('t1', 8); };
    // SUB A
    op[0x97] = () { SUB_A('a', 4); };
    // SBC A,B
    op[0x98] = () { SBC_A('b', 4); };
    // SBC A,C
    op[0x99] = () { SBC_A('c', 4); };
    // SBC A,D
    op[0x9A] = () { SBC_A('d', 4); };
    // SBC A,E
    op[0x9B] = () { SBC_A('e', 4); };
    // SBC A,H
    op[0x9C] = () { r['t1'] = r['hl'] >> 8; SBC_A('t1', 4); };
    // SBC A,L
    op[0x9D] = () { r['t1'] = r['hl'] & 0xFF; SBC_A('t1', 4); };
    // SBC A,(HL)
    op[0x9E] = () { r['t1'] = gb.memory.R(r['hl']); SBC_A('t1', 4); };
    // SBC A,A
    op[0x9F] = () { SBC_A('a', 4); };
    // AND B
    op[0xA0] = () { AND_A('b', 4); };
    // AND A,C
    op[0xA1] = () { AND_A('c', 4); };
    // AND A,D
    op[0xA2] = () { AND_A('d', 4); };
    // AND A,E
    op[0xA3] = () { AND_A('e', 4); };
    // AND A,H
    op[0xA4] = () { r['t1'] = r['hl'] >> 8; AND_A('t1', 4); };
    // AND A,L
    op[0xA5] = () { r['t1'] = r['hl'] & 0xFF; AND_A('t1', 4); };
    // AND A,(HL)
    op[0xA6] = () { r['t1'] = gb.memory.R(r['hl']); AND_A('t1', 4); };
    // AND A,A
    op[0xA7] = () { AND_A('a', 4); };
    // XOR B
    op[0xA8] = () { XOR_A('b', 4); };
    // XOR A,C
    op[0xA9] = () { XOR_A('c', 4); };
    // XOR A,D
    op[0xAA] = () { XOR_A('d', 4); };
    // XOR A,E
    op[0xAB] = () { XOR_A('e', 4); };
    // XOR A,H
    op[0xAC] = () { r['t1'] = r['hl'] >> 8; XOR_A('t1', 4); };
    // XOR A,L
    op[0xAD] = () { r['t1'] = r['hl'] & 0xFF; XOR_A('t1', 4); };
    // XOR A,(HL)
    op[0xAE] = () { r['t1'] = gb.memory.R(r['hl']); XOR_A('t1', 4); };
    // XOR A,A
    op[0xAF] = () { XOR_A('a', 4); };
    // OR B
    op[0xB0] = () { OR_A('b', 4); };
    // OR A,C
    op[0xB1] = () { OR_A('c', 4); };
    // OR A,D
    op[0xB2] = () { OR_A('d', 4); };
    // OR A,E
    op[0xB3] = () { OR_A('e', 4); };
    // OR A,H
    op[0xB4] = () { r['t1'] = r['hl'] >> 8; OR_A('t1', 4); };
    // OR A,L
    op[0xB5] = () { r['t1'] = r['hl'] & 0xFF; OR_A('t1', 4); };
    // OR A,(HL)
    op[0xB6] = () { r['t1'] = gb.memory.R(r['hl']); OR_A('t1', 4); };
    // OR A,A
    op[0xB7] = () { OR_A('a', 4); };
    // CP B
    op[0xB8] = () { CP_A('b', 4); };
    // CP C
    op[0xB9] = () { CP_A('c', 4); };
    // CP D
    op[0xBA] = () { CP_A('d', 4); };
    // CP E
    op[0xBB] = () { CP_A('e', 4); };
    // CP H
    op[0xBC] = () { r['t1'] = r['hl'] >> 8; CP_A('t1', 4); };
    // CP L
    op[0xBD] = () { r['t1'] = r['hl'] & 0xFF; CP_A('t1', 4); };
    // CP (HL)
    op[0xBE] = () { r['t1'] = gb.memory.R(r['hl']); CP_A('t1', 8); };
    // CP A
    op[0xBF] = () { CP_A('a', 4); };
    // RET NZ
    op[0xC0] = () { RET(r['fz'] == 0); };
    // POP BC
    op[0xC1] = () {
        r['c'] = gb.memory.R(r['sp']++);
        r['b'] = gb.memory.R(r['sp']++);
        ticks = 12;
    };
    // JP NZ,u16
    op[0xC2] = () { JP(r['fz'] == 0); };
    // JP u16
    op[0xC3] = () { JP(true); };
    // CALL NZ,u16
    op[0xC4] = () { CALL(r['fz'] == 0); };
    // PUSH BC
    op[0xC5] = () {
        gb.memory.W(--r['sp'], r['b']);
        gb.memory.W(--r['sp'], r['c']);
        ticks = 16;
    };
    // ADD A,u8
    op[0xC6] = () { r['t1'] = gb.memory.R(r['pc']++); ADD_A('t1', 8); };
    // RST 0x00
    op[0xC7] = () { RST(0x00); };
    // RET Z
    op[0xC8] = () { RET(r['fz'] == 1); };
    // RET
    op[0xC9] = () { RET(true); };
    // JP Z,u16
    op[0xCA] = () { JP(r['fz'] == 1); };
    // CB
    op[0xCB] = () { opcb[gb.memory.R(r['pc']++)](); };
    // CALL Z,u16
    op[0xCC] = () { CALL(r['fz'] == 1); };
    // CALL u16
    op[0xCD] = () { CALL(true); };
    // ADC A,u8
    op[0xCE] = () { r['t1'] = gb.memory.R(r['pc']++); ADC_A('t1', 8); };
    // RST 0x08
    op[0xCF] = () { RST(0x08); };
    // RET NC
    op[0xD0] = () { RET(r['fc'] == 0); };
    // POP DE
    op[0xD1] = () {
      r['e'] = gb.memory.R(r['sp']++);
      r['d'] = gb.memory.R(r['sp']++);
      ticks = 12;
    };
    // JP NC,u16
    op[0xD2] = () { JP(r['fc'] == 0); };
    // UNKNOWN
    op[0xD3] = UNKNOWN;
    // CALL NC,u16
    op[0xD4] = () { CALL(r['fc'] == 0); };
    // PUSH DE
    op[0xD5] = () {
        gb.memory.W(--r['sp'], r['d']);
        gb.memory.W(--r['sp'], r['e']);
        ticks = 16;
    };
    // SUB u8
    op[0xD6] = () {
        r['t1'] = gb.memory.R(r['pc']++);
        SUB_A('t1', 8);
    };
    // RST 0x10
    op[0xD7] = () { RST(0x10); };
    // RET C
    op[0xD8] = () { RET(r['fc'] == 1); };
    // RETI
    op[0xD9] = () { RET(true); gb.interrupts.enabled = true; };
    // JP C,u16
    op[0xDA] = () { JP(r['fc'] == 1); };
    // UNKNOWN
    op[0xDB] = UNKNOWN;
    // CALL C,u16
    op[0xDC] = () { CALL(r['fc'] == 1); };
    // UNKNOWN
    op[0xDD] = UNKNOWN;
    // SBC A,u8
    op[0xDE] = () {
        r['t1'] = gb.memory.R(r['pc']++);
        SBC_A('t1', 8);
    };
    // RST 0x18
    op[0xDF] = () { RST(0x18); };
    // LD (0xFF00+u8),A
    op[0xE0] = () {
        gb.memory.W(0xFF00 + gb.memory.R(r['pc']++), r['a']);
        ticks = 12;
    };
    // POP HL
    op[0xE1] = () {
        r['t1'] = gb.memory.R(r['sp']++);
        r['hl'] = (gb.memory.R(r['sp']++)<<8)|r['t1'];
        ticks = 12;
    };
    // LD (0xFF00+C),A
    op[0xE2] = () {
        gb.memory.W(0xFF00 + r['c'], r['a']);
        ticks = 8;
    };
    // UNKNOWN
    op[0xE3] = UNKNOWN;
    // UNKNOWN
    op[0xE4] = UNKNOWN;
    // PUSH HL
    op[0xE5] = () {
        gb.memory.W(--r['sp'], r['hl'] >> 8);
        gb.memory.W(--r['sp'], r['hl'] & 0xFF);
        ticks = 16;
    };
    // AND u8
    op[0xE6] = () { 
        r['t2'] = gb.memory.R(r['pc']);
        AND_A('t2', 8);
    };
    // RST 0x20
    op[0xE7] = () { RST(0x20); };
    // ADD SP,u8
    op[0xE8] = () {
        r['sp'] = ADD16(r['sp'], Util.signed(gb.memory.R(r['pc']++)));
        ticks += 8;
    };
    // JP (HL)
    op[0xE9] = () {
        r['pc'] = r['hl'];
        ticks = 4;
    };
    // LD (u16),A
    op[0xEA] = () {
        gb.memory.W((gb.memory.R(r['pc']+1)<<8)|gb.memory.R(r['pc']), r['a']);
        r['pc'] += 2;
        ticks = 16;
    };
    // UNKNOWN
    op[0xEB] = UNKNOWN;
    // UNKNOWN
    op[0xEC] = UNKNOWN;
    // UNKNOWN
    op[0xED] = UNKNOWN;
    // XOR u8
    op[0xEE] = () { XOR_A(gb.memory.R(r['pc']++), 8); };
    // RST 0x28
    op[0xEF] = () { RST(0x28); };
    // LD A,(0xFF00+u8)
    op[0xF0] = () {
        r['a'] = gb.memory.R(0xFF00 + gb.memory.R(r['pc']++));
        ticks = 12;
    };
    // POP AF
    op[0xF1] = () {
        r['t1'] = gb.memory.R(r['sp']++);
        r['a'] = gb.memory.R(r['sp']++);
        r['fz'] = (r['t1']>>7)&1;
        r['fn'] = (r['t1']>>6)&1;
        r['fh'] = (r['t1']>>5)&1;
        r['fc'] = (r['t1']>>4)&1;
        ticks = 12;
    };
    
    // LD A,(0xFF00+C)
    op[0xF2] = () {
        r['a'] = gb.memory.R(0xFF00 + r['c']);
        ticks = 8;
    };
    // DI
    op[0xF3] = () { gb.interrupts.enabled = false; ticks = 4; };
    // UNKNOWN
    op[0xF4] = UNKNOWN;
    // PUSH AF
    op[0xF5] = () {
        gb.memory.W(--r['sp'], r['a']);
        gb.memory.W(--r['sp'], (r['fz']<<7)|(r['fn']<<6)|(r['fh']<<5)|(r['fc']<<4));
        ticks = 16;
    };
    // OR u8
    op[0xF6] = () { OR_A(gb.memory.R(r['pc']++), 8); };
    // RST 0x30
    op[0xF7] = () { RST(0x30); };
    // LD HL,SP+u8
    op[0xF8] = () {
        var n = gb.memory.R(r['pc']++);
        r['hl'] = r['sp'] + Util.signed(n);
        r['fz'] = 0;
        r['fn'] = 0;
        r['fh'] = ((r['sp']&0x0F) + (n&0x0F)) > 0x0F ? 1 : 0;
        r['fc'] = ((r['sp']&0xFF) + (n&0xFF)) > 0xFF ? 1 : 0;
        ticks = 12;
    };
    // LD SP,HL
    op[0xF9] = () {
        r['sp'] = r['hl'];
        ticks = 8;
    };
    // LD A,(u16)
    op[0xFA] = () {
        r['a'] = gb.memory.R((gb.memory.R(r['pc']+1)<<8)|gb.memory.R(r['pc']));
        r['pc'] += 2;
        ticks = 16;
    };
    // EI
    op[0xFB] = () { gb.interrupts.enabled = true; ticks = 4; };
    // UNKNOWN
    op[0xFC] = UNKNOWN;
    // UNKNOWN
    op[0xFD] = UNKNOWN;
    // CP u8
    op[0xFE] = () {
        r['t1'] = gb.memory.R(r['pc']++);
        CP_A('t1', 8);
    };
    // RST 0x38
    op[0xFF] = () { RST(0x38); };
  }
    
  void buildOpCodeCBs() {
    opcb[0x00] = () { r['b'] = RLC(r['b']); };
    opcb[0x01] = () { r['c'] = RLC(r['c']); };
    opcb[0x02] = () { r['d'] = RLC(r['d']); };
    opcb[0x03] = () { r['e'] = RLC(r['e']); };
    opcb[0x04] = () { r['hl'] = (r['hl'] & 0x00FF) | (RLC(r['hl'] >> 8) << 8); };
    opcb[0x05] = () { r['hl'] = (r['hl'] & 0xFF00) | RLC(r['hl'] & 0xFF); };
    opcb[0x06] = () { gb.memory.W(r['hl'], RLC(gb.memory.R(r['hl']))); ticks += 8; };
    opcb[0x07] = () { r['a'] = RLC(r['a']); };
    opcb[0x08] = () { r['b'] = RRC(r['b']); };
    opcb[0x09] = () { r['c'] = RRC(r['c']); };
    opcb[0x0A] = () { r['d'] = RRC(r['d']); };
    opcb[0x0B] = () { r['e'] = RRC(r['e']); };
    opcb[0x0C] = () { r['hl'] = (r['hl'] & 0x00FF) | (RRC(r['hl'] >> 8) << 8); };
    opcb[0x0D] = () { r['hl'] = (r['hl'] & 0xFF00) | RRC(r['hl'] & 0xFF); };
    opcb[0x0E] = () { gb.memory.W(r['hl'], RRC(gb.memory.R(r['hl']))); ticks += 8; };
    opcb[0x0F] = () { r['a'] = RRC(r['a']); };
    opcb[0x10] = () { r['b'] = RL(r['b']); };
    opcb[0x11] = () { r['c'] = RL(r['c']); };
    opcb[0x12] = () { r['d'] = RL(r['d']); };
    opcb[0x13] = () { r['e'] = RL(r['e']); };
    opcb[0x14] = () { r['hl'] = (r['hl'] & 0x00FF) | (RL(r['hl'] >> 8) << 8); };
    opcb[0x15] = () { r['hl'] = (r['hl'] & 0xFF00) | RL(r['hl'] & 0xFF); };
    opcb[0x16] = () { gb.memory.W(r['hl'], RL(gb.memory.R(r['hl']))); ticks += 8; };
    opcb[0x17] = () { r['a'] = RL(r['a']); };
    opcb[0x18] = () { r['b'] = RR(r['b']); };
    opcb[0x19] = () { r['c'] = RR(r['c']); };
    opcb[0x1A] = () { r['d'] = RR(r['d']); };
    opcb[0x1B] = () { r['e'] = RR(r['e']); };
    opcb[0x1C] = () { r['hl'] = (r['hl'] & 0x00FF) | (RR(r['hl'] >> 8) << 8); };
    opcb[0x1D] = () { r['hl'] = (r['hl'] & 0xFF00) | RR(r['hl'] & 0xFF); };
    opcb[0x1E] = () { gb.memory.W(r['hl'], RR(gb.memory.R(r['hl']))); ticks += 8; };
    opcb[0x1F] = () { r['a'] = RR(r['a']); };
    opcb[0x20] = () { SLA_R('b', 8); };
    opcb[0x21] = () { SLA_R('c', 8); };
    opcb[0x22] = () { SLA_R('d', 8); };
    opcb[0x23] = () { SLA_R('e', 8); };
    opcb[0x24] = () { r['t1'] = r['hl'] >> 8; SLA_R('t1', 8); r['hl'] = (r['t1'] << 8) | (r['hl'] & 0x00FF); };
    opcb[0x25] = () { r['t1'] = r['hl'] & 0xFF; SLA_R('t1', 8); r['hl'] = (r['hl'] & 0xFF00) | r['t1']; };
    opcb[0x26] = () { r['t1'] = gb.memory.R(r['hl']); SLA_R('t1', 16); gb.memory.W(r['hl'], r['t1']); };
    opcb[0x27] = () { SLA_R('a', 8); };
    opcb[0x28] = () {
      r['fc'] = r['b'] & 1; r['b'] = (r['b'] >> 1) | (r['b'] & 0x80);
      r['fn'] = 0; r['fh'] = 0; r['fz'] = (r['b'] == 0 ? 1 : 0);
      ticks = 8;
    };
    opcb[0x29] = () {
      r['fc'] = r['c'] & 1; r['c'] = (r['c'] >> 1) | (r['c'] & 0x80);
      r['fn'] = 0; r['fh'] = 0; r['fz'] = (r['c'] == 0 ? 1 : 0);
      ticks = 8;
    };
    opcb[0x2A] = () {
      r['fc'] = r['d'] & 1; r['d'] = (r['d'] >> 1) | (r['d'] & 0x80);
      r['fn'] = 0; r['fh'] = 0; r['fz'] = (r['d'] == 0 ? 1 : 0);
      ticks = 8;
    };
    opcb[0x2B] = () {
      r['fc'] = r['e'] & 1; r['e'] = (r['e'] >> 1) | (r['e'] & 0x80);
      r['fn'] = 0; r['fh'] = 0;
      r['fz'] = (r['e'] == 0 ? 1 : 0);
      ticks = 8;
    };
    opcb[0x2C] = () {
      var h = r['hl'] >> 8; r['fc'] = h & 1; h = (h >> 1) | (h & 0x80);
      r['fn'] = 0; r['fh'] = 0; r['fz'] = (h == 0 ? 1 : 0);
      r['hl'] = (h << 8) | (r['hl'] & 0x00ff);
      ticks = 8; };
    opcb[0x2D] = () {
      var l = r['hl'] & 0xFF; r['fc'] = l & 1; l = (l >> 1) | (l & 0x80);
      r['fn'] = 0; r['fh'] = 0; r['fz'] = (l == 0 ? 1 : 0);
      r['hl'] = (r['hl'] & 0xFF00) | l;
      ticks = 8; };
    opcb[0x2E] = () {
      var m = gb.memory.R(r['hl']); r['fc'] = m & 1; m = (m >> 1) | (m & 0x80);
      r['fn'] = 0; r['fh'] = 0;
      r['fz'] = (m == 0 ? 1 : 0);
      gb.memory.W(r['hl'], m);
      ticks = 16; };
    opcb[0x2F] = () {
      r['fc'] = r['a'] & 1; r['a'] = (r['a'] >> 1) | (r['a'] & 0x80);
      r['fn'] = 0; r['fh'] = 0; r['fz'] = (r['a'] == 0 ? 1 : 0);
      ticks = 8; };
    opcb[0x30] = () { SWAP('b'); };
    opcb[0x31] = () { SWAP('c'); };
    opcb[0x32] = () { SWAP('d'); };
    opcb[0x33] = () { SWAP('e'); };
    opcb[0x34] = () { SWAP('h'); };
    opcb[0x35] = () { SWAP('l'); };
    opcb[0x36] = () { SWAP('hl'); };
    opcb[0x37] = () { SWAP('a'); };
    opcb[0x38] = () {
        r['fc'] = r['b'] & 1;
        r['b'] = r['b'] >> 1;
        r['fn'] = r['fh'] = 0;
        r['fz'] = (r['b'] == 0 ? 1 : 0);
        ticks = 8;
    };
    opcb[0x39] = () {
        r['fc'] = r['c'] & 1;
        r['c'] = r['c'] >> 1;
        r['fn'] = r['fh'] = 0;
        r['fz'] = (r['c'] == 0 ? 1 : 0);
        ticks = 8;
    };
    opcb[0x3A] = () {
        r['fc'] = r['d'] & 1;
        r['d'] = r['d'] >> 1;
        r['fn'] = r['fh'] = 0;
        r['fz'] = (r['d'] == 0 ? 1 : 0);
        ticks = 8;
    };
    opcb[0x3B] = () {
        r['fc'] = r['e'] & 1;
        r['e'] = r['e'] >> 1;
        r['fn'] = r['fh'] = 0;
        r['fz'] = (r['e'] == 0 ? 1 : 0);
        ticks = 8;
    };
    opcb[0x3C] = () {
        var h = r['hl'] >> 8;
        r['fc'] = h & 1;
        h = h >> 1;
        r['fn'] = r['fh'] = 0;
        r['fz'] = (h == 0 ? 1 : 0);
        r['hl'] = (h << 8) | (r['hl'] & 0x00FF);
        ticks = 8;
    };
    opcb[0x3D] = () {
        var l = r['hl'] & 0xFF;
        r['fc'] = l & 1;
        l = l >> 1;
        r['fn'] = r['fh'] = 0;
        r['fz'] = (l == 0 ? 1 : 0);
        r['hl'] = (r['hl'] & 0xFF00) | l;
        ticks = 8;
    };
    opcb[0x3E] = () {
        var m = gb.memory.R(r['hl']);
        r['fc'] = m & 1;
        m = m >> 1;
        r['fn'] = r['fh'] = 0;
        r['fz'] = (m == 0 ? 1 : 0);
        gb.memory.W(r['hl'], m);
        ticks = 16;
    };
    opcb[0x3F] = () {
        r['fc'] = r['a'] & 1;
        r['a'] = r['a'] >> 1;
        r['fn'] = r['fh'] = 0;
        r['fz'] = (r['a'] == 0 ? 1 : 0);
        ticks = 8;
    };

    for (var i = 0; i < 8; ++i) {
      var o = (1 << 6) | (i << 3);
      // BIT n, r - CB 01 xxx xxx - CB 01 bit reg
      opcb[o|0] = () { BIT('b', 1 << i, 8); };
      opcb[o|1] = () { BIT('c', 1 << i, 8); };
      opcb[o|2] = () { BIT('d', 1 << i, 8); };
      opcb[o|3] = () { BIT('e', 1 << i, 8); };
      opcb[o|4] = () { BIT('hl', 256 << i, 8); };
      opcb[o|5] = () { BIT('hl', 1 << i, 8); };
      opcb[o|6] = () { r['t2'] = gb.memory.R(r['hl']); BIT('t2', 1 << i, 16); };
      opcb[o|7] = () { BIT('a', 1 << i, 8); };
      
      // RES n, r - CB 10 xxx xxx - CB 10 bit reg
      o = (2 << 6) | (i << 3);
      opcb[o|0] = () { RES('b', 1 << i, 0xFF, 8); };
      opcb[o|1] = () { RES('c', 1 << i, 0xFF, 8); };
      opcb[o|2] = () { RES('d', 1 << i, 0xFF, 8); };
      opcb[o|3] = () { RES('e', 1 << i, 0xFF, 8); };
      opcb[o|4] = () { RES('hl', 256 << i, 0xFFFF, 8); };
      opcb[o|5] = () { RES('hl', 1 << i, 0xFFFF, 8); };
      opcb[o|6] = () {
          r['t2'] = gb.memory.R(r['hl']);
          RES('t2', 1 << i, 0xFF, 16);
          gb.memory.W(r['hl'], r['t2']);
      };
      opcb[o|7] = () { RES('a', 1 << i, 0xFF, 8); };
      
      // SET n, r - CB 11 xxx xxx - CB 11 bit reg
      o = (3 << 6) | (i << 3);
      opcb[o|0] = () { SET('b', 1<<i, 8); };
      opcb[o|1] = () { SET('c', 1<<i, 8); };
      opcb[o|2] = () { SET('d', 1<<i, 8); };
      opcb[o|3] = () { SET('e', 1<<i, 8); };
      opcb[o|4] = () { SET('hl', 256<<i, 8); };
      opcb[o|5] = () { SET('hl', 1<<i, 8); };
      opcb[o|6] = () {
          r['t2'] = gb.memory.R(r['hl']);
          SET('t2', 1<<i, 16);
          gb.memory.W(r['hl'], r['t2']);
      };
      opcb[o|7] = () { SET('a', 1<<i, 8); };
    }
  }
  
  void BIT(String reg, int mask, int t) {
    r['fz'] = (r[reg] & mask) == 0 ? 1 : 0;
    r['fn'] = 0;
    r['fh'] = 1;
    ticks = t;
  }
  
  void RES(String reg, int shift_mask, int mask, int t) {
    r[reg] &= ((~shift_mask) & mask);
    ticks = t;
  }
  
  void SET(String reg, int mask, int t) {
    r[reg] |= mask;
    ticks = t;
  }

  //List<Mnemonic> mn = new List<Mnemonic>();
  //List<Mnemonic> mncb = new List<Mnemonic>();
}
