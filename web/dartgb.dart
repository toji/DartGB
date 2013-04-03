library dartgb;

import 'dart:async';
import 'dart:html';
import 'package:web_ui/web_ui.dart';

part 'cpu.dart';
part 'gameboy.dart';
part 'input.dart';
part 'interrupts.dart';
part 'lcd.dart';
part 'memory.dart';
part 'rom.dart';
part 'timers.dart';

// initial value for click-counter
int startingCount = 5;

/**
 * Learn about the Web UI package by visiting
 * http://www.dartlang.org/articles/dart-web-components/.
 */
void main() {
  var gameboy = new Gameboy('tetris.rom');
  // Enable this to use Shadow DOM in the browser.
  //useShadowDom = true;
}
