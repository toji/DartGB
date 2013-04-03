library dartgb;

import 'dart:typeddata';
import 'dart:async';
import 'dart:html';
import 'dart:math';
import 'dart:web_gl' as GL;
import 'package:web_ui/web_ui.dart';
import 'glutils/glutils.dart';

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
  CanvasElement canvas = query('#lcd');
  var gameboy = new Gameboy('tetris.rom', canvas);
}
