part of dartgb;

class Gameboy {
  bool paused = false;

  int seconds;
  int frames;

  int bankSwitchCount = 0;
  
  //Debugger debugger;
  LCD lcd = null;  
  ROM rom = null;
  Memory memory = null;
  Interrupts interrupts = null;
  CPU cpu = null;
  Input input = null;
  Timers timers;

  Timer runTimer = null;
  Timer fpsTimer = null;
  
  Gameboy(String filename, CanvasElement canvas)
      : seconds = 0,
        frames = 0,
        paused = true {
    rom = new ROM('roms/$filename');
    memory = new Memory(rom);
    timers = new Timers(memory);
    cpu = new CPU(this);
    interrupts = new Interrupts(this);
    lcd = new LCD(canvas, memory);
    input = new Input(memory);
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
    timers.endFrame = false;
    while (!(timers.endFrame || paused)) {
      cpu.next();
      interrupts.run();
      timers.control();
      // debugger.checkBreakpoint();
    }
  }

  void showFPS(Timer t) {
    frames += timers.FPS;
    ++seconds;
    // TODO: set status to fps
    timers.FPS = 0;
    bankSwitchCount = 0;
  }
}
