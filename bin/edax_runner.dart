import 'dart:io';
import 'dart:math';

import 'package:libedax4dart/libedax4dart.dart';

const String _bookFile = 'data/book.dat';
const int _waitEdaxLoadingData = 20;
const String _learningListFile = 'learning_list.txt';
const String _learnedLogFile = 'learned_log.txt';
const String _commentHead = '//';
final _edaxVsEdaxRegexp = RegExp(r'^([a-hA-H]{1}[1-8]{1})+$'); // e.g. "f5f6f7"
final _edaxVsEdaxWithRandomnessRegexp = RegExp(r'^(\d+)(,)(([a-hA-H]{1}[1-8]{1})+)$'); // e.g. "3,f5f6f7"
final _bookDeviateRegexp = RegExp(r'^(\[)(\d+)(\s+)(\d+)(\])(\s+)(([a-hA-H]{1}[1-8]{1})+)$'); // e.g. "[1 3] f5f6f7"

Future<void> main(final List<String> arguments) async {
  _log('edax shared library: $_edaxSharedLibraryPath.');
  final edax = LibEdax(_edaxSharedLibraryPath)
    ..libedaxInitialize(['', '-book-file', _bookFile]) // NOTE: prioritize `edax.ini`.
    ..edaxInit()
    ..edaxEnableBookVerbose()
    ..edaxPlayPrint();

  _log('wait edax loading data: $_waitEdaxLoadingData sec.');
  await Future<void>.delayed(const Duration(seconds: _waitEdaxLoadingData));

  while (true) {
    final text = await _getNextLearningText();
    if (text == 'exit' || text.isEmpty) {
      edax.libedaxTerminate();
      _log('edax has terminated.');
      break;
    }
    _log('start to learn "$text".');

    if (text == 'fix') _doEdaxBookFix(edax);
    if (_edaxVsEdaxRegexp.hasMatch(text)) _doEdaxVsEdaxWithRandomness(edax, text, 0);
    if (_edaxVsEdaxWithRandomnessRegexp.hasMatch(text)) {
      final match = _edaxVsEdaxWithRandomnessRegexp.firstMatch(text);
      final moves = match!.group(3) ?? '';
      final randomness = int.parse(match.group(1) ?? '0');
      _doEdaxVsEdaxWithRandomness(edax, moves, randomness);
    }
    if (_bookDeviateRegexp.hasMatch(text)) {
      final match = _bookDeviateRegexp.firstMatch(text);
      final moves = match!.group(7) ?? '';
      final relativeError = int.parse(match.group(2) ?? '0');
      final absoluteError = int.parse(match.group(4) ?? '0');
      _doEdaxBookDeviate(edax, moves, relativeError, absoluteError);
    }

    _log('has finished learning, and will remove "$text".');
    await _removeLearnedText();
    _log('has removed "$text".');
  }
}

String get _edaxSharedLibraryPath {
  if (Platform.isLinux) return 'libedax.so';
  if (Platform.isMacOS) return 'libedax.universal.dylib';
  if (Platform.isWindows) return 'libedax-x64.dll';
  throw Exception('${Platform.operatingSystem} is not supported');
}

Future<String> _getNextLearningText() async {
  final file = File(_learningListFile);
  final lines = await file.readAsLines();
  return lines.firstWhere((final line) => !line.contains(_commentHead), orElse: () => '').trim();
}

Future<void> _removeLearnedText() async {
  final srcFile = File(_learningListFile);
  final logFile = File(_learnedLogFile);
  final lines = await srcFile.readAsLines();
  var cnt = 0;
  for (final line in lines) {
    await logFile.writeAsString('$line\n', mode: FileMode.append);
    cnt++;
    if (!line.contains(_commentHead)) break;
  }
  lines.removeRange(0, min(cnt, lines.length));
  await srcFile.writeAsString(lines.join('\n'));
}

void _log(final String msg) => stdout.writeln('\n[edax_runner] $msg\n');

void _doEdaxBookFix(final LibEdax edax) {
  edax
    ..edaxBookFix()
    ..edaxPlayPrint();
}

void _doEdaxVsEdaxWithRandomness(final LibEdax edax, final String moves, final int randomness) {
  edax
    ..edaxInit()
    ..edaxSetOption('book-randomness', randomness.toString())
    ..edaxPlay(moves)
    ..edaxPlayPrint();
  while (!edax.edaxIsGameOver()) {
    edax.edaxGo();
    stdout.writeln();
    edax.edaxPlayPrint();
  }
  _log('game over. will book store and save.');
  edax
    ..edaxMode(3)
    ..edaxBookStore()
    ..edaxBookSave(_bookFile);
  _log('has finished book store and save.');
}

void _doEdaxBookDeviate(final LibEdax edax, final String moves, final int relativeError, final int absoluteError) {
  edax
    ..edaxInit()
    ..edaxPlay(moves)
    ..edaxPlayPrint();
  stdout.writeln();
  _log('will book deviate and save.');
  edax
    ..edaxBookDeviate(relativeError, absoluteError)
    ..edaxBookFix()
    ..edaxBookSave(_bookFile);
  _log('has finished book deviate and save.');
}
