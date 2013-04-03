part of dartgb;

class Gameboy {
  bool paused = false;
  bool endFrame;

  int seconds;
  int frames;

  int bankSwitchCount = 0;
  
  //Debugger debugger;
  LCD lcd = null;  
  ROM rom = null;
  Memory memory = null;
  Interrupts interrupts = new Interrupts();
  CPU cpu = new CPU();
  Input input = new Input();
  Timers timers = new Timers();

  Timer runTimer = null;
  Timer fpsTimer = null;
  
  Gameboy(String filename, CanvasElement canvas)
      : seconds = 0,
        frames = 0,
        paused = true,
        endFrame = true {
    rom = new ROM('roms/$filename');
    memory = new Memory(rom);
    lcd = new LCD(canvas, memory);
    run();
  }

  void run() {
    if (!paused)
      return;
    paused = false;
    // TODO: disable/enable buttons here
    fpsTimer = new Timer.periodic(new Duration(seconds: 1), showFPS);
    runTimer = new Timer.periodic(new Duration(milliseconds: 16), frame);
  }

  void pause() {
    if (paused)
      return;
    paused = true;
    // TODO: disable/enable buttons here
    runTimer.cancel();
    fpsTimer.cancel();
    // TODO: set 'status' in web page to paused
  }

  void frame(Timer t) {
    endFrame = false;
    while (!(endFrame || paused)) {
      cpu.nextOp();
      interrupts.run();
      timers.control();
      // debugger.checkBreakpoint();
    }
  }

  void showFPS(Timer t) {
    // TODO
    // frames += FPS;
    ++seconds;
    // TODO: set status to fps
    // FPS = 0;
    bankSwitchCount = 0;
  }
}
