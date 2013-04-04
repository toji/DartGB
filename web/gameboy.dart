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
    ROM.load('../roms/$filename').then((ROM r) {
        // NOTE: DO NOT CHANGE THE ORDER OF INITIALIZATION
        rom = r;
        print('Loaded ${rom.name}');
        input = new Input(this);
        memory = new Memory(this);
        memory.reset();
        lcd = new LCD(canvas, memory);
        cpu = new CPU(this);
        timers = new Timers(this);
        interrupts = new Interrupts(this);
        run();
    });
  }

  void run() {
    if (!paused)
      return;
    paused = false;
    // TODO: disable/enable buttons here
    fpsTimer = new Timer.periodic(new Duration(seconds: 1), showFPS);
    runTimer = new Timer.periodic(new Duration(milliseconds: 16), frame);
    var status = document.getElementById('status') as DivElement;
    status.innerHtml = 'Running';
  }

  void pause() {
    if (paused)
      return;
    paused = true;
    // TODO: disable/enable buttons here
    runTimer.cancel();
    fpsTimer.cancel();
    var status = document.getElementById('status') as DivElement;
    status.innerHtml = 'Paused';
  }

  void frame(Timer t) {
    timers.endFrame = false;
    while (!(timers.endFrame || paused)) {
      cpu.next();
      interrupts.run();
      timers.control();
      input.pollGamepad();
      // debugger.checkBreakpoint();
    }
  }

  void showFPS(Timer t) {
    frames += timers.FPS;
    ++seconds;
    //var status = document.getElementById('status') as DivElement;
    //status.innerHtml = 'Running ${timers.FPS} fps';
    timers.FPS = 0;
    bankSwitchCount = 0;
  }
}
