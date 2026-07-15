import 'package:paperpal/core/models/soul.dart';
import '../cli_state.dart' show soulPresetDefinitions, loadActiveSoulId, saveActiveSoulId, deleteSoulFile, ensureDirs;
import '../cli_helpers.dart' show printSuccess, printError, println, cyan, bold;

const _help = 'soul list | soul set <id> | soul create <name> <description> | soul delete <id>';

void soulCommand(List<String> args) {
  if (args.isEmpty) {
    println(_help);
    return;
  }

  final sub = args[0];

  if (sub == 'list') {
    final activeId = loadActiveSoulId();
    final presets = soulPresetDefinitions.entries.map((e) => Soul.fromJson(e.value)).toList();
    println('${bold("Presets")}:');
    for (final s in presets) {
      final active = s.id == activeId ? bold(cyan(' [active]')) : '';
      println('  ${cyan(s.id)}: ${s.name}$active');
      println('       ${s.description}');
    }
  } else if (sub == 'set') {
    if (args.length < 2) {
      printError('Usage: soul set <id>');
      return;
    }
    final id = args[1];
    final exists = soulPresetDefinitions.containsKey(id);
    if (!exists) {
      printError('Soul not found: $id');
      return;
    }
    ensureDirs();
    saveActiveSoulId(id);
    printSuccess('Active soul set to: $id');
  } else if (sub == 'create') {
    if (args.length < 3) {
      printError('Usage: soul create <name> <description>');
      return;
    }
    printError('Custom soul creation requires LLM — use the Flutter app or implement via ask command');
  } else if (sub == 'delete') {
    if (args.length < 2) {
      printError('Usage: soul delete <id>');
      return;
    }
    deleteSoulFile(args[1]);
    if (loadActiveSoulId() == args[1]) {
      saveActiveSoulId(soulPresetDefinitions.keys.first);
    }
    printSuccess('Deleted soul: ${args[1]}');
  } else {
    printError('Unknown subcommand: $sub\n$_help');
  }
}
