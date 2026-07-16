// PaperPal CLI — Convert Command
//
// Converts any supported document to Markdown using the unified
// DocConversionService (MarkItDown bridge).
//
// Usage: dart run tool/paperpal.dart convert <path> [--output <path>] [--json]

import 'dart:convert';
import 'dart:io';

import '../cli_state.dart';
import '../cli_helpers.dart';
import '../../../lib/core/init.dart' show createLocator;
import '../../../lib/core/interfaces/services.dart' show IDocConversionService;

Future<void> convertCommand(List<String> args) async {
  if (args.isEmpty || args[0] == 'help') {
    _printHelp();
    return;
  }

  var inputPath = '';
  var outputPath = '';
  var asJson = false;

  for (var i = 0; i < args.length; i++) {
    if (args[i] == '--output' && i + 1 < args.length) {
      outputPath = args[i + 1];
      i++;
    } else if (args[i] == '--json') {
      asJson = true;
    } else if (!args[i].startsWith('--')) {
      inputPath = args[i];
    }
  }

  if (inputPath.isEmpty) {
    printError('Missing input file path');
    _printHelp();
    return;
  }

  final file = File(inputPath);
  if (!await file.exists()) {
    printError('File not found: $inputPath');
    return;
  }

  println('Converting: ${file.path}...');
  final locator = await createLocator();
  final converter = locator.get<IDocConversionService>();

  final result = await converter.convertToMarkdown(file);

  if (!result.success) {
    printError('Conversion failed: ${result.error}');
    return;
  }

  if (outputPath.isNotEmpty) {
    await File(outputPath).writeAsString(result.markdown, flush: true);
    println('Written: $outputPath (${result.markdown.length} chars)');
  } else if (asJson) {
    println(jsonEncode({
      'success': true,
      'title': result.title,
      'markdown': result.markdown,
      'length': result.markdown.length,
      'sourceFormat': result.sourceFormat,
      'sourceType': result.sourceType,
    }));
  } else {
    println(result.markdown);
  }
}

void _printHelp() {
  println('${bold("Convert")} — Convert any document to Markdown');
  println('');
  println('Usage: dart run tool/paperpal.dart convert ${bold("<path>")} [options]');
  println('');
  println('Options:');
  println('  --output <path>   Write output to file');
  println('  --json            Output as JSON');
  println('');
  println('Supported formats:');
  println('  PDF, DOCX, PPTX, XLSX, EPUB, HTML, MD, TXT, CSV, JSON, XML,');
  println('  PNG, JPG, GIF, WEBP, MP3, WAV, M4A');
  println('');
  println('Requires: Python 3.10+ with markitdown package installed.');
  println('  pip install markitdown');
}
