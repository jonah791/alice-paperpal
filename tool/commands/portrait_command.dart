import '../cli_helpers.dart' show println, bold, cyan, printJson;
import '../cli_state.dart' show loadPortrait;

void portraitCommand(List<String> args) {
  final asJson = args.contains('--json');
  final portrait = loadPortrait();

  if (portrait.isEmpty) {
    println('No portrait data yet. Start chatting to build a portrait.');
    return;
  }

  if (asJson) {
    printJson(portrait);
    return;
  }

  println('${bold("User Portrait")}:\n');
  for (final entry in portrait.entries) {
    final key = entry.key;
    final val = entry.value;

    if (key == 'last_updated') {
      println('  ${cyan("Last Updated")}: $val');
      continue;
    }

    if (val is Map) {
      println('  ${cyan(key)}:');
      for (final sub in val.entries) {
        println('    ${bold(sub.key)}: ${sub.value}');
      }
    } else if (val is List) {
      println('  ${cyan(key)}: ${val.join(', ')}');
    } else {
      println('  ${cyan(key)}: $val');
    }
  }
}
