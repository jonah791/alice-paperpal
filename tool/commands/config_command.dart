import '../cli_state.dart' show loadConfig, saveConfig;
import '../cli_helpers.dart' show println, printSuccess, printError, printJson;

const _help = 'config get <key> | config set <key> <value>';

void configCommand(List<String> args) {
  if (args.isEmpty) {
    println(_help);
    return;
  }

  final sub = args[0];
  final cfg = loadConfig();

  if (sub == 'get') {
    if (args.length < 2) {
      printError('Usage: config get <key>');
      return;
    }
    final val = cfg[args[1]];
    printJson({args[1]: val});
  } else if (sub == 'set') {
    if (args.length < 3) {
      printError('Usage: config set <key> <value>');
      return;
    }
    cfg[args[1]] = args[2];
    saveConfig(cfg);
    printSuccess('${args[1]} = ${args[2]}');
  } else if (sub == 'list') {
    printJson(cfg);
  } else {
    printError('Unknown subcommand: $sub\n$_help');
  }
}
