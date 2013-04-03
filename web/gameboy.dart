part of dartgb;

class Gameboy {
  Gameboy(String filename, CanvasElement canvas, bool startRunning)
      : seconds = 0,
        frames = 0 {
    lcd = new LCD(canvas);
    loadROM('roms/$filename');
    if (startRunning)
      run();
    else
      pause();
  }

  void loadROM(String filename) {

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

  void frame() {
    endFrame = false;
    while (!(endFrame || paused)) {
      cpu.nextOp();
      interrupts.run();
      timers.control();
      // debugger.checkBreakpoint();
    }
  }

  void showFPS() {
    // TODO
    // frames += FPS;
    ++seconds;
    // TODO: set status to fps
    // FPS = 0;
    bankSwitchCount = 0;
  }

  bool paused = false;
  bool endFrame;

  int seconds;
  int frames;

  int bankSwitchCount = 0;
  
  //Debugger debugger;
  Memory memory = new Memory();
  LCD lcd;
  Interrupts interrupts = new Interrupts();
  CPU cpu = new CPU();
  Input input = new Input();
  Timers timers = new Timers();

  Timer runTimer;
  Timer fpsTimer;
}
