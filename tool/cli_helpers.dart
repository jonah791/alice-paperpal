import 'dart:convert';
import 'dart:io';

const _red = '\x1B[31m';
const _green = '\x1B[32m';
const _yellow = '\x1B[33m';
const _blue = '\x1B[34m';
const _cyan = '\x1B[36m';
const _bold = '\x1B[1m';
const _reset = '\x1B[0m';

bool get _noColor => Platform.environment['NO_COLOR'] != null;

String _c(String code, String text) => _noColor ? text : '$code$text$_reset';

String red(String s) => _c(_red, s);
String green(String s) => _c(_green, s);
String yellow(String s) => _c(_yellow, s);
String blue(String s) => _c(_blue, s);
String cyan(String s) => _c(_cyan, s);
String bold(String s) => _c(_bold, s);

void printError(String msg) {
  stderr.writeln(red('Error: $msg'));
  exitCode = 1;
}

void printSuccess(String msg) {
  println(green('✓ $msg'));
}

void printWarning(String msg) {
  println(yellow('⚠ $msg'));
}

void println(String msg) {
  stdout.writeln(msg);
}

void printJson(Object data) {
  stdout.writeln(const JsonEncoder.withIndent('  ').convert(data));
}
