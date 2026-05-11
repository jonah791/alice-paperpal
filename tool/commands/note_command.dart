import '../cli_helpers.dart' show println, bold, cyan, printError, printSuccess, printJson;
import '../cli_state.dart' show loadNotes, saveNotes;

const _help = 'note list <paper-id> [--json] | note add <paper-id> <text> [--type note|highlight|question] | note delete <note-id>';

void noteCommand(List<String> args) {
  if (args.isEmpty) {
    printError(_help);
    return;
  }

  final sub = args[0];

  if (sub == 'list') {
    if (args.length < 2) {
      printError('Usage: note list <paper-id>');
      return;
    }
    final paperId = args[1];
    final asJson = args.contains('--json');
    final notes = loadNotes().where((n) => n['paperId'] == paperId).toList();

    if (notes.isEmpty) {
      println('No notes for paper: $paperId');
      return;
    }

    if (asJson) {
      printJson(notes);
      return;
    }

    println('${bold("Notes for")} $paperId:\n');
    for (var i = 0; i < notes.length; i++) {
      final n = notes[i];
      println('  [${i + 1}] ${cyan(n['type'] as String? ?? 'note')} — ${bold(n['text'] as String? ?? '')}');
      println('       ${cyan("ID")}: ${n['id']}');
      if (n['selectedText'] != null) {
        println('       ${cyan("Selection")}: ${n['selectedText']}');
      }
      println('');
    }
  } else if (sub == 'add') {
    if (args.length < 3) {
      printError('Usage: note add <paper-id> <text>');
      return;
    }
    final paperId = args[1];
    final text = args.sublist(2).join(' ');
    final typeIdx = args.indexOf('--type');
    final type = (typeIdx >= 0 && typeIdx + 1 < args.length) ? args[typeIdx + 1] : 'note';

    final notes = loadNotes();
    final note = {
      'id': DateTime.now().millisecondsSinceEpoch.toString(),
      'paperId': paperId,
      'text': text,
      'createdAt': DateTime.now().toIso8601String(),
      'updatedAt': DateTime.now().toIso8601String(),
      'type': type,
    };
    notes.add(note);
    saveNotes(notes);
    printSuccess('Note added: ${note['id']}');
  } else if (sub == 'delete') {
    if (args.length < 2) {
      printError('Usage: note delete <note-id>');
      return;
    }
    final noteId = args[1];
    final notes = loadNotes();
    final before = notes.length;
    notes.removeWhere((n) => n['id'] == noteId);
    if (notes.length == before) {
      printError('Note not found: $noteId');
      return;
    }
    saveNotes(notes);
    printSuccess('Deleted note: $noteId');
  } else {
    printError('Unknown: $sub\n$_help');
  }
}
