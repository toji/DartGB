part of dartgb;

class GamepadButton {
  int ID;
  bool pressed;
  
  GamepadButton(this.ID) : pressed = false;
}

class Input {
  Gameboy gb = null;
  Gamepad gamepad = null;
  
  int pin14 = 0xEF;
  int pin15 = 0xDF;
  
  const int BUTTON_A = 1;
  const int BUTTON_B = 0;
  const int BUTTON_START = 9;
  const int BUTTON_SELECT = 8;
  const int BUTTON_UP = 12;
  const int BUTTON_DOWN = 13;
  const int BUTTON_LEFT = 14;
  const int BUTTON_RIGHT = 15;
  
  List<GamepadButton> buttons = new List<GamepadButton>(8);
  
  const num ANALOGUE_THRESHOLD = 0.5;
  
  Input(this.gb) {
    window.document.onKeyDown.listen(onKeyDownEvent);
    window.document.onKeyUp.listen(onKeyUpEvent);

    buttons[0] = new GamepadButton(BUTTON_A);
    buttons[1] = new GamepadButton(BUTTON_B);
    buttons[2] = new GamepadButton(BUTTON_START);
    buttons[3] = new GamepadButton(BUTTON_SELECT);
    buttons[4] = new GamepadButton(BUTTON_UP);
    buttons[5] = new GamepadButton(BUTTON_DOWN);
    buttons[6] = new GamepadButton(BUTTON_LEFT);
    buttons[7] = new GamepadButton(BUTTON_RIGHT);    
  }
  
  bool buttonPressed(int buttonID) => gamepad.buttons[buttonID] > ANALOGUE_THRESHOLD;
  
  void pollGamepad() {
    var new_gamepad = window.navigator.getGamepads()[0];
    if (new_gamepad != null && new_gamepad != gamepad) {
      gamepad = new_gamepad;
      print('found gamepad ${gamepad.id}');
    }
    if (gamepad != null && gamepad.buttons != null) {
      buttons.forEach((b) {
          bool pressed = gamepad.buttons[b.ID];
          if (pressed != b.pressed) {
            if (pressed)
              onButtonDown(b.ID);
            else
              onButtonUp(b.ID);
            b.pressed = pressed;
          }
      });
    }
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
  
  void onButtonDown(int button) {
    switch (button) {
      case BUTTON_DOWN:
        pin14 &= 0xF7;
        gb.memory.W(gb.memory.IF, gb.memory.IF|16);
        break;
      case BUTTON_UP:
        pin14 &= 0xFB;
        gb.memory.W(gb.memory.IF, gb.memory.IF|16);
        break;
      case BUTTON_LEFT:
        pin14 &= 0xFD;
        gb.memory.W(gb.memory.IF, gb.memory.IF|16);
        break;
      case BUTTON_RIGHT:
        pin14 &= 0xFE;
        gb.memory.W(gb.memory.IF, gb.memory.IF|16);
        break;
      case BUTTON_START:
        pin15 &= 0xF7;
        gb.memory.W(gb.memory.IF, gb.memory.IF|16);
        break;
      case BUTTON_SELECT:
        pin15 &= 0xFB;
        gb.memory.W(gb.memory.IF, gb.memory.IF|16);
        break;
      case BUTTON_B:
        pin15 &= 0xFD;
        gb.memory.W(gb.memory.IF, gb.memory.IF|16);
        break;
      case BUTTON_A:
        pin15 &= 0xFE;
        gb.memory.W(gb.memory.IF, gb.memory.IF|16);
        break;
    }
  }
  
  void onButtonUp(int button) {
    switch (button) {
      case BUTTON_DOWN:
        pin14 |= 0x8;
        gb.memory.W(gb.memory.IF, gb.memory.IF|16);
        break;
      case BUTTON_UP:
        pin14 |= 0x4;
        gb.memory.W(gb.memory.IF, gb.memory.IF|16);
        break;
      case BUTTON_LEFT:
        pin14 |= 0x2;
        gb.memory.W(gb.memory.IF, gb.memory.IF|16);
        break;
      case BUTTON_RIGHT:
        pin14 |= 0x1;
        gb.memory.W(gb.memory.IF, gb.memory.IF|16);
        break;
      case BUTTON_START:
        pin15 |= 0x8;
        gb.memory.W(gb.memory.IF, gb.memory.IF|16);
        break;
      case BUTTON_SELECT:
        pin15 |= 0x4;
        gb.memory.W(gb.memory.IF, gb.memory.IF|16);
        break;
      case BUTTON_B:
        pin15 |= 0x2;
        gb.memory.W(gb.memory.IF, gb.memory.IF|16);
        break;
      case BUTTON_A:
        pin15 |= 0x1;
        gb.memory.W(gb.memory.IF, gb.memory.IF|16);
        break;
    }
  }
      
  void onKeyDownEvent(KeyboardEvent e) {
    switch (e.keyCode) {
      case 40:  // down
        onButtonDown(BUTTON_DOWN);
        e.preventDefault();
        break;
      case 38:  // up
        onButtonDown(BUTTON_UP);
        e.preventDefault();
        break;
      case 37:  // left
        onButtonDown(BUTTON_LEFT);
        e.preventDefault();
        break;
      case 39:  // right
        onButtonDown(BUTTON_RIGHT);
        e.preventDefault();
        break;
      case 65:  // start
        onButtonDown(BUTTON_START);
        e.preventDefault();
        break;
      case 83:  // select
        onButtonDown(BUTTON_SELECT);
        e.preventDefault();
        break;
      case 90:  // B
        onButtonDown(BUTTON_B);
        e.preventDefault();
        break;
      case 88:  // 
        onButtonDown(BUTTON_A);
        e.preventDefault();
        break;
    }
  }
  
  void onKeyUpEvent(KeyboardEvent e) {
    switch (e.keyCode) {
      case 40:  // down
        onButtonUp(BUTTON_DOWN);
        e.preventDefault();
        break;
      case 38:  // up
        onButtonUp(BUTTON_UP);
        e.preventDefault();
        break;
      case 37:  // left
        onButtonUp(BUTTON_LEFT);
        e.preventDefault();
        break;
      case 39:  // right
        onButtonUp(BUTTON_RIGHT);
        e.preventDefault();
        break;
      case 65:  // start
        onButtonUp(BUTTON_START);
        e.preventDefault();
        break;
      case 83:  // select
        onButtonUp(BUTTON_SELECT);
        e.preventDefault();
        break;
      case 90:  // B
        onButtonUp(BUTTON_B);
        e.preventDefault();
        break;
      case 88:  // A
        onButtonUp(BUTTON_A);
        e.preventDefault();
        break;
    }
  }
}
