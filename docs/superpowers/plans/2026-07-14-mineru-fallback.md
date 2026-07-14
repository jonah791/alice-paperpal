# MinerU Fallback Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Add a lightweight PDF text extraction pipeline that activates when MinerU is unavailable.

**Architecture:** New `PdfFallbackService` with 3-tier fallback (poppler → flutter_pdf → metadata-only). `PaperService.importPdf()` removes the early-return guard; on MinerU failure, delegates to `PdfFallbackService`. `ParseResult.sourceType` tracks the origin; `Paper.sourceType` persists it. ReadPage shows a banner for non-MinerU content.

**Tech Stack:** Flutter/Dart, `syncfusion_flutter_pdf` (existing), `poppler-utils` (optional runtime dep), `dart:io` Process

## Global Constraints

- All 340+ existing tests pass unmodified
- `ParseResult.sourceType` defaults to `'mineru'` — zero impact on existing consumers
- `Paper.sourceType` defaults to `'mineru'` — JSON deserialization handles missing field gracefully
- No new pub dependencies

---

### Task 1: Add `sourceType` to ParseResult + Paper

**Files:**
- Modify: `lib/core/models/parse_result.dart`
- Modify: `lib/core/models/paper.dart`

**Interfaces:**
- Produces: `ParseResult.sourceType` defaults `'mineru'`, `Paper.sourceType` defaults `'mineru'`

- [ ] **Step 1: Add `sourceType` to ParseResult**

```dart
class ParseResult {
  final String markdown;
  final String title;
  final List<String> imagePaths;
  final String contentListJson;
  final int startPage;
  final int endPage;
  final String sourceType; // 'mineru' | 'fallback_text' | 'fallback_raw'

  const ParseResult({
    required this.markdown,
    this.title = '',
    this.imagePaths = const [],
    this.contentListJson = '',
    this.startPage = 0,
    this.endPage = 0,
    this.sourceType = 'mineru',
  });
}
```

- [ ] **Step 2: Add `sourceType` to Paper model**

```dart
// Add field
final String sourceType;

// Default in constructor
this.sourceType = 'mineru',

// copyWith
String? sourceType,
sourceType: sourceType ?? this.sourceType,

// toJson
'sourceType': sourceType,

// fromJson
sourceType: json['sourceType'] as String? ?? 'mineru',
```

- [ ] **Step 3: Compile check**

Run: `dart analyze lib/core/models/`
Expected: No issues

- [ ] **Step 4: Commit**

```bash
git add lib/core/models/parse_result.dart lib/core/models/paper.dart
git commit -m "feat(parse): add sourceType field to ParseResult and Paper"
```

---

### Task 2: Create PdfFallbackService

**Files:**
- Create: `lib/core/services/pdf_fallback_service.dart`

- [ ] **Step 1: Write PdfFallbackService**

```dart
import 'dart:io';
import 'package:logging/logging.dart';
import 'package:syncfusion_flutter_pdf/pdf.dart';
import '../models/parse_result.dart';

final _log = Logger('PdfFallbackService');

class PdfFallbackService {
  Future<ParseResult> parseAsText(File pdfFile, int pageCount) async {
    // Level 1: poppler pdftotext
    if (await _hasPoppler()) {
      try {
        final result = await _parseWithPoppler(pdfFile);
        _log.info('poppler fallback OK: ${result.markdown.length} chars');
        return result;
      } catch (e) {
        _log.warning('poppler failed: $e');
      }
    }

    // Level 2: flutter_pdf
    try {
      final result = _parseWithFlutterPdf(pdfFile);
      _log.info('flutter_pdf fallback OK: ${result.markdown.length} chars');
      return result;
    } catch (e) {
      _log.warning('flutter_pdf failed: $e');
    }

    // Level 3: metadata only
    final name = pdfFile.path.split(Platform.pathSeparator).last.replaceAll('.pdf', '');
    _log.info('metadata-only fallback: $name');
    return ParseResult(
      markdown: '# $name\n\n*无法解析此 PDF 的内容。*',
      title: name,
      sourceType: 'fallback_raw',
    );
  }

  Future<bool> _hasPoppler() async {
    try {
      if (Platform.isWindows) {
        final result = await Process.run('where', ['pdftotext']);
        return result.exitCode == 0;
      }
      final result = await Process.run('which', ['pdftotext']);
      return result.exitCode == 0;
    } catch (_) {
      return false;
    }
  }

  Future<ParseResult> _parseWithPoppler(File pdfFile) async {
    final result = await Process.run('pdftotext', ['-layout', pdfFile.path, '-']);
    if (result.exitCode != 0) {
      throw Exception('pdftotext exit code ${result.exitCode}');
    }
    final text = result.stdout as String;
    if (text.trim().isEmpty) throw Exception('pdftotext produced empty output');

    final sections = _splitSections(text);
    return ParseResult(
      markdown: sections.join('\n\n'),
      title: _extractTitle(text),
      sourceType: 'fallback_text',
    );
  }

  ParseResult _parseWithFlutterPdf(File pdfFile) {
    final doc = PdfDocument(inputBytes: pdfFile.readAsBytesSync());
    try {
      final buffer = StringBuffer();
      for (var i = 0; i < doc.pages.count; i++) {
        final page = doc.pages[i];
        final text = PdfTextExtractor(page).extractText();
        if (i > 0) buffer.writeln('\n\n<!-- page-break -->\n');
        buffer.writeln('### 第 ${i + 1} 页');
        buffer.writeln(text.trim());
      }
      return ParseResult(
        markdown: buffer.toString(),
        title: _extractTitle(buffer.toString()),
        sourceType: 'fallback_raw',
      );
    } finally {
      doc.dispose();
    }
  }

  String _extractTitle(String text) {
    final lines = text.split('\n');
    for (final line in lines) {
      final trimmed = line.trim();
      if (trimmed.isNotEmpty && !trimmed.startsWith('#')) {
        return trimmed.length > 120 ? trimmed.substring(0, 120) : trimmed;
      }
    }
    return 'Untitled';
  }

  List<String> _splitSections(String text) {
    final lines = text.split('\n');
    final sections = <String>[];
    var current = StringBuffer();

    for (final line in lines) {
      final trimmed = line.trim();
      if (trimmed.isEmpty && current.isNotEmpty) {
        final content = current.toString().trim();
        if (content.isNotEmpty) sections.add(content);
        current = StringBuffer();
      } else if (_isSectionHeader(trimmed)) {
        if (current.isNotEmpty) {
          final content = current.toString().trim();
          if (content.isNotEmpty) sections.add(content);
          current = StringBuffer();
        }
        current.writeln('## $trimmed');
      } else {
        current.writeln(trimmed);
      }
    }

    final last = current.toString().trim();
    if (last.isNotEmpty) sections.add(last);
    return sections;
  }

  bool _isSectionHeader(String line) {
    if (line.length > 60 || line.isEmpty) return false;
    final keywords = ['introduction', 'abstract', 'method', 'approach',
      'experiment', 'result', 'conclusion', 'discussion', 'related work',
      'background', 'preliminary', 'analysis', 'evaluation', 'limitation',
      'acknowledgment', 'reference', 'introduction', '方法', '实验', '结论',
      '相关工作', '引言'];
    final lower = line.toLowerCase().replaceAll(RegExp(r'[^a-z\u4e00-\u9fff]'), '');
    for (final kw in keywords) {
      if (lower.contains(kw)) return true;
    }
    return false;
  }
}
```

- [ ] **Step 2: Compile check**

Run: `dart analyze lib/core/services/pdf_fallback_service.dart`
Expected: No issues

- [ ] **Step 3: Commit**

```bash
git add lib/core/services/pdf_fallback_service.dart
git commit -m "feat(parse): add PdfFallbackService with 3-tier text extraction"
```

---

### Task 3: Integrate Fallback into PaperService

**Files:**
- Modify: `lib/core/services/paper_service.dart`

- [ ] **Step 1: Add PdfFallbackService field**

```dart
// After _parse field
final _fallback = PdfFallbackService();
```

- [ ] **Step 2: Remove early MinerU key guards**

In `importPdf()` (line ~125-130) and `importFromSearch()` (line ~109-114), remove the `readMineruApiKey()` check that returns null:

```dart
// importFromSearch — remove lines 110-114
  Future<Paper?> importFromSearch(SearchResult result, {void Function(int, int)? onProgress}) async {
    if (result.pdfUrl.isEmpty) {
      _log.warning('importFromSearch: no PDF URL for ${result.title}');
      return null;
    }

// importPdf — remove lines 126-130
  Future<Paper?> importPdf(File pdfFile, {String? title}) async {
    final paperId = _uuid.v4();
    final paper = Paper(
      id: paperId,
```

- [ ] **Step 3: Modify importPdf catch block to try fallback**

Replace the single catch block (lines ~167-174) with a try-fallback-catch chain:

```dart
    try {
      final pageCount = await PageCounter.getPageCount(pdfFile.path);
      final result = await _parse.parsePdf(pdfFile, pageCount);
      await _cache.saveMarkdown(paperId, result.markdown);

      final updated = paper.copyWith(
        title: result.title.isNotEmpty ? result.title : paper.title,
        status: PaperStatus.parsed,
        pageCount: pageCount,
        sourceType: result.sourceType,
      );
      _papers.remove(paper);
      _papers.add(updated);
      _emitPapers();
      await _persistPaper(updated);
      _activeComment(paperId);
      if (_config.config.autoTranslate) await _autoTranslate(updated);
      return updated;
    } catch (e) {
      _log.warning('MinerU parse failed: $e, trying fallback...');
      try {
        final pageCount = await PageCounter.getPageCount(pdfFile.path);
        final result = await _fallback.parseAsText(pdfFile, pageCount);
        await _cache.saveMarkdown(paperId, result.markdown);

        final updated = paper.copyWith(
          title: result.title.isNotEmpty ? result.title : paper.title,
          status: PaperStatus.parsed,
          pageCount: pageCount,
          sourceType: result.sourceType,
        );
        _papers.remove(paper);
        _papers.add(updated);
        _emitPapers();
        await _persistPaper(updated);
        _log.info('fallback parse OK: $paperId');
        return updated;
      } catch (e2) {
        _log.warning('importPdf all paths failed: $paperId → $e2');
        final failed = paper.copyWith(status: PaperStatus.error, errorMessage: e2.toString());
        _papers.remove(paper);
        _papers.add(failed);
        _emitPapers();
        return failed;
      }
    }
```

- [ ] **Step 4: Add import for PdfFallbackService**

```dart
// At top of file
import 'pdf_fallback_service.dart';
```

- [ ] **Step 5: Run all tests**

Run: `flutter test`
Expected: 340+ tests all pass

- [ ] **Step 6: Commit**

```bash
git add lib/core/services/paper_service.dart
git commit -m "feat(parse): integrate PdfFallbackService into PaperService"
```

---

### Task 4: Fallback Banner in ReadPage

**Files:**
- Modify: `lib/ui/pages/read_page.dart`

- [ ] **Step 1: Add banner for non-MinerU content**

Find the build method's body, add a banner at the top when `widget.paper.sourceType != 'mineru'`:

In the build method, after getting theme, add:

```dart
    // Banner for fallback-parsed papers
    if (widget.paper.sourceType != 'mineru') {
      return Column(
        children: [
          Container(
            width: double.infinity,
            padding: padSym(h: Spacing.md, v: Spacing.sm),
            color: theme.colorScheme.secondaryContainer,
            child: Row(
              children: [
                Icon(Icons.info_outline, size: DesignTokens.iconSm),
                SizedBox(width: Spacing.sm),
                Expanded(
                  child: Text(
                    '轻量解析模式 — PDF 以纯文本显示，公式/图表可能不完整。',
                    style: theme.textTheme.bodySmall,
                  ),
                ),
              ],
            ),
          ),
          Expanded(child: existingBody),
        ],
      );
    }
```

- [ ] **Step 2: Compile check**

Run: `dart analyze lib/ui/pages/read_page.dart`
Expected: No issues

- [ ] **Step 3: Run all tests**

Run: `flutter test`
Expected: 340+ tests all pass

- [ ] **Step 4: Commit**

```bash
git add lib/ui/pages/read_page.dart
git commit -m "feat(ui): show banner for fallback-parsed papers in ReadPage"
```

---

### Task 5: Add Tests for Fallback Path

**Files:**
- Create: `test/core/services/pdf_fallback_service_test.dart`

- [ ] **Step 1: Write unit tests**

```dart
import 'dart:io';
import 'package:flutter_test/flutter_test.dart';
import 'package:syncfusion_flutter_pdf/pdf.dart';
import 'package:paperpal/core/services/pdf_fallback_service.dart';
import 'package:paperpal/core/models/parse_result.dart';

void main() {
  late PdfFallbackService service;

  setUp(() {
    service = PdfFallbackService();
  });

  group('_extractTitle', () {
    test('extracts first non-header line', () {
      final result = service._extractTitle('## Header\n\nTitle Text\n\nBody');
      expect(result, 'Title Text');
    });

    test('skips hash-prefixed lines', () {
      final result = service._extractTitle('# Title\n## Sub\n\nReal Title Here');
      expect(result, 'Real Title Here');
    });

    test('returns Untitled for empty', () {
      final result = service._extractTitle('');
      expect(result, 'Untitled');
    });

    test('truncates long titles at 120 chars', () {
      final long = 'A' * 200;
      final result = service._extractTitle(long);
      expect(result.length, 120);
    });
  });

  group('_splitSections', () {
    test('splits on blank lines', () {
      // Access private via reflection — simpler: just test the sections
      final text = 'Line 1\nLine 2\n\nLine 3\n\nLine 4';
      final sections = service._splitSections(text);
      expect(sections.length, 3);
      expect(sections[0], 'Line 1\nLine 2');
    });

    test('marks common section headers with ##', () {
      final text = 'Abstract\nThis is the abstract.\n\nIntroduction\nContent.';
      final sections = service._splitSections(text);
      expect(sections.any((s) => s.startsWith('## Abstract')), true);
      expect(sections.any((s) => s.startsWith('## Introduction')), true);
    });
  });

  group('_isSectionHeader', () {
    test('recognizes Introduction', () {
      expect(service._isSectionHeader('Introduction'), true);
    });
    test('recognizes Related Work', () {
      expect(service._isSectionHeader('Related Work'), true);
    });
    test('rejects long lines', () {
      expect(service._isSectionHeader('A' * 61), false);
    });
    test('rejects empty', () {
      expect(service._isSectionHeader(''), false);
    });
  });

  // Integration-level tests require a real PDF fixture
  group('flutter_pdf extraction', () {
    test('generates page headers and non-empty output for valid PDF', () async {
      final fixture = File('test/fixtures/sample.pdf');
      if (!await fixture.exists()) return; // skip gracefully
      final result = service._parseWithFlutterPdf(fixture);
      expect(result.sourceType, 'fallback_raw');
      expect(result.markdown, contains('第 1 页'));
      expect(result.title, isNot(equals('Untitled')));
    });
  });
}
```

Note: The private method access above might require making methods package-visible (prefix `_` → remove). Either export internal methods with doc comments or just leave the integration test.

Actually, for the tests to access `_extractTitle`, `_splitSections`, `_isSectionHeader`, and `_parseWithFlutterPdf`, make them package-visible (remove underscore prefix) and add `@visibleForTesting` annotation:

```dart
@visibleForTesting
String extractTitle(String text) { ... }

@visibleForTesting
List<String> splitSections(String text) { ... }

@visibleForTesting
bool isSectionHeader(String line) { ... }

@visibleForTesting
ParseResult parseWithFlutterPdf(File pdfFile) { ... }
```

And add import: `import 'package:flutter/foundation.dart';`

- [ ] **Step 2: Create minimal test fixture**

```bash
mkdir -p test/fixtures
# Copy a small PDF or create one programmatically
```

- [ ] **Step 3: Run tests**

Run: `flutter test test/core/services/pdf_fallback_service_test.dart`
Expected: All tests pass

- [ ] **Step 4: Commit**

```bash
git add lib/core/services/pdf_fallback_service.dart test/core/services/pdf_fallback_service_test.dart test/fixtures/
git commit -m "test: add PdfFallbackService unit tests with fixture"
```

---

### Task 6: Final Verification

- [ ] **Step 1: Full test suite**

Run: `flutter test`
Expected: All tests pass (340+)

- [ ] **Step 2: Analyze**

Run: `flutter analyze`
Expected: No errors

- [ ] **Step 3: Build check**

Run: `flutter build windows --release`
Expected: Build succeeds

- [ ] **Step 4: Final commit**

```bash
git add -A
git commit -m "chore: final verification before merge"
git push origin master
```
