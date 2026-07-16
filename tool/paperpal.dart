// ALICE PaperPal — CLI
//
// Run:  dart run tool/paperpal.dart <command> [args]
//
// Tests the real product code (API clients, data models, services)
// without requiring the Flutter UI.

import 'cli_state.dart' show ensureDirs;
import 'cli_helpers.dart' show println, bold, printError;

import 'commands/config_command.dart' show configCommand;
import 'commands/search_command.dart' show searchCommand;
import 'commands/import_command.dart' show importCommand;
import 'commands/paper_command.dart' show paperCommand;
import 'commands/ask_command.dart' show askCommand;
import 'commands/summarize_command.dart' show summarizeCommand;
import 'commands/translate_command.dart' show translateCommand;
import 'commands/export_command.dart' show exportCommand;
import 'commands/soul_command.dart' show soulCommand;
import 'commands/note_command.dart' show noteCommand;
import 'commands/memory_command.dart' show memoryCommand;
import 'commands/portrait_command.dart' show portraitCommand;
import 'commands/convert_command.dart' show convertCommand;

Future<void> main(List<String> args) async {
  if (args.isEmpty) {
    _printHelp();
    return;
  }

  ensureDirs();

  final cmd = args[0];
  final rest = args.sublist(1);

  try {
    switch (cmd) {
      case 'config':
        configCommand(rest);
      case 'search':
        await searchCommand(rest);
      case 'import':
        await importCommand(rest);
      case 'papers':
        paperCommand(rest);
      case 'ask':
        await askCommand(rest);
      case 'summarize':
        await summarizeCommand(rest);
      case 'translate':
        await translateCommand(rest);
      case 'export':
        exportCommand(rest);
      case 'soul':
        soulCommand(rest);
      case 'note':
        noteCommand(rest);
      case 'memory':
        memoryCommand(rest);
      case 'portrait':
        portraitCommand(rest);
      case 'convert':
        await convertCommand(rest);
      case 'help':
        _printHelp();
      default:
        printError('Unknown command: $cmd');
        _printHelp();
    }
  } catch (e) {
    printError('$cmd failed: $e');
  }
}

void _printHelp() {
  println('${bold("PaperPal CLI")} — AI-powered paper reading assistant\n');
  println('Usage: dart run tool/paperpal.dart ${bold("<command>")} [args]\n');
  println('${bold("Configuration")}:');
  println('  config get <key>                 Get config value');
  println('  config set <key> <value>          Set config value');
  println('  config list                       List all config\n');
  println('${bold("Search & Import")}:');
  println('  search <query> [--limit N]        Search papers via arXiv + Semantic Scholar');
  println('  import search <index>             Import paper from search result index');
  println('  import pdf <path> [--title T]     Import and parse a local PDF');
  println('  import url <url> [--title T]      Import and parse PDF from URL\n');
  println('${bold("Document Conversion")}:');
  println('  convert <path> [--output F]       Convert any document to Markdown');
  println('  convert <path> --json             Convert and output as JSON\n');
  println('${bold("Papers")}:');
  println('  papers list [--status S] [--json]  List imported papers');
  println('  papers show <id> [--translated]    Show paper content');
  println('  papers delete <id>                Delete a paper\n');
  println('${bold("AI")}:');
  println('  ask <paper-id> <question>          Ask AI about a paper');
  println('  ask <paper-id> <q> --stream        Stream the answer');
  println('  summarize <paper-id>               Generate paper summary');
  println('  translate <paper-id> [--target <lang>]  Translate paper (e.g. --target zh)\n');
  println('${bold("Export")}:');
  println('  export bibtex <id> [--output F]    Export as BibTeX');
  println('  export markdown <id> [--output F]  Export as Markdown\n');
  println('${bold("Souls")}:');
  println('  soul list                          List available souls');
  println('  soul set <id>                      Set active soul');
  println('  soul create <name> <desc>          Create a new soul');
  println('  soul delete <id>                   Delete a soul\n');
  println('${bold("Notes & Memory")}:');
  println('  note list <paper-id> [--json]       List notes for a paper');
  println('  note add <paper-id> <text> [--type]  Add a note (types: note, highlight, question)');
  println('  note delete <note-id>               Delete a note');
  println('  memory list [--json]               Show conversation memory');
  println('  memory prune                       Clean old memories\n');
  println('${bold("Profile")}:');
  println('  portrait show [--json]             View user portrait\n');
}
