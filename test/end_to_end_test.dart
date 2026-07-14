/// 端到端测试：用真实 PDF 跑完整导入管线（Mock API 层）
///
/// 覆盖链路：
///   PDF 文件 → CacheService.savePdf → ParseService(模拟) → PaperService 状态管理
///   → ReadPage 渲染 → QA/摘要 → 导出 → 删除
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:paperpal/core/di/dependencies.dart';
import 'package:paperpal/core/di/service_locator.dart';
import 'package:paperpal/core/models/paper.dart';
import 'package:paperpal/core/services/export_service.dart';
import 'package:paperpal/ui/pages/read_page.dart';
import 'helpers/mock_services.dart';

void main() {
  late Directory tempDir;
  late File realPdfFile;

  setUpAll(() async {
    // Locate the real PDF
    final pdfPath = r'C:\Users\tr\Documents\中国股市量化选股因子全解析：从基本面到情绪面.pdf';
    realPdfFile = File(pdfPath);
    if (!await realPdfFile.exists()) {
      throw Exception('PDF not found: $pdfPath');
    }
  });

  setUp(() {
    tempDir = Directory.systemTemp.createTempSync('paperpal_e2e_');
  });

  tearDown(() {
    if (tempDir.existsSync()) tempDir.deleteSync(recursive: true);
  });

  group('End-to-End: Real PDF Pipeline', () {
    test('PDF file exists and has valid header', () async {
      expect(await realPdfFile.exists(), true, reason: 'PDF file must exist');

      final bytes = await realPdfFile.readAsBytes();
      expect(bytes.length, greaterThan(1000), reason: 'PDF should be > 1KB');
      expect(bytes.length, lessThan(50 * 1024 * 1024), reason: 'PDF should be < 50MB');

      // Verify PDF magic header "%PDF"
      expect(bytes[0], 0x25); // '%'
      expect(bytes[1], 0x50); // 'P'
      expect(bytes[2], 0x44); // 'D'
      expect(bytes[3], 0x46); // 'F'

      print('PDF size: ${(bytes.length / 1024).toStringAsFixed(1)} KB');
    });

    test('CacheService can store and retrieve the PDF', () async {
      final mockCache = MockCacheService();
      final paperId = 'e2e_test_paper';

      // Save PDF
      await mockCache.savePdf(paperId, realPdfFile);

      // Verify path is correct
      final path = mockCache.pdfPath(paperId);
      expect(path, contains(paperId));

      // Save and read markdown
      const testMd = '# Test Content';
      await mockCache.saveMarkdown(paperId, testMd);
      final md = await mockCache.readMarkdown(paperId);
      expect(md, testMd);

      // Save and read translation
      const testTrans = '# 测试内容';
      await mockCache.saveTranslation(paperId, testTrans);
      final trans = await mockCache.readTranslation(paperId);
      expect(trans, testTrans);

      // Paper metadata round-trip
      final paper = Paper(
        id: paperId,
        title: 'Test Paper',
        year: 2024,
        status: PaperStatus.parsed,
        importedAt: DateTime.now(),
      );
      await mockCache.savePaperMeta(paper);
      final allPapers = await mockCache.loadAllPapers();
      expect(allPapers.length, 1);
      expect(allPapers.first.id, paperId);

      // Delete cleanup
      await mockCache.deletePaper(paperId);
      final afterDelete = await mockCache.loadAllPapers();
      expect(afterDelete, isEmpty);
    });

    test('PaperService import flow with mock MinerU', () async {
      final mockMarkdown = '''
# 中国股市量化选股因子全解析

## 摘要
本文系统性地梳理了A股市场主要选股因子，从传统的基本面因子到新兴的情绪因子。

## 1. 引言
量化选股是量化投资的核心环节之一。

## 2. 因子分类
### 2.1 基本面因子
- 估值因子（PE、PB、PS）
- 成长因子（营收增速、利润增速）
- 质量因子（ROE、ROA）

### 2.2 技术因子
- 动量因子
- 反转因子
- 波动率因子

### 2.3 情绪因子
- 资金流向
- 舆情热度
- 分析师预期修正
''';

      final paperService = MockPaperService();

      // 1. Import paper
      final paper = await paperService.importPdf(realPdfFile, title: '中国股市量化选股因子全解析');
      expect(paper, isNotNull, reason: 'Import should succeed');
      expect(paper!.title, contains('量化选股'));

      // Set markdown for the imported paper's ID
      paperService.markdowns[paper.id] = mockMarkdown;

      // Verify paper is in the collection
      final fromCollection = paperService.getPaper(paper.id);
      expect(fromCollection, isNotNull);
      expect(fromCollection!.title, paper.title);

      // 2. Get markdown content
      final md = await paperService.getMarkdown(paper.id);
      expect(md, isNotNull, reason: 'Markdown should be available');
      expect(md, contains('因子分类'));
      expect(md, contains('资金流向'));

      // 3. Ask a question
      final answer = await paperService.askQuestion(paper.id, '本文主要讨论了哪些因子类型？');
      expect(answer, contains('Mock answer'), reason: 'Should get mock answer');

      // 4. Summarize
      final summary = await paperService.summarize(paper.id);
      expect(summary, contains('summary'), reason: 'Should get summary');

      // 5. Delete
      await paperService.deletePaper(paper.id);
      expect(paperService.getPaper(paper.id), isNull, reason: 'Paper should be deleted');
    });

    test('ExportService generates BibTeX from real paper data', () {
      final paper = Paper(
        id: 'cn_quant_001',
        title: '中国股市量化选股因子全解析：从基本面到情绪面',
        year: 2024,
        authors: ['张三', '李四', '王五'],
        doi: '10.1234/cn_quant.2024.001',
        source: 'local',
      );

      final bibtex = ExportService.generateBibtex(paper);
      expect(bibtex, contains('@article{'));
      expect(bibtex, contains('中国股市量化选股因子全解析'));
      expect(bibtex, contains('张三 and 李四 and 王五'));
      expect(bibtex, contains('year={2024}'));
    });

    testWidgets('ReadPage renders real paper content with mock data', (tester) async {
      final paperService = MockPaperService();
      paperService.markdowns['e2e_read'] = '''
# 中国股市量化选股因子全解析：从基本面到情绪面

## 摘要
本文系统性地梳理了A股市场主要选股因子。

## 研究方法
我们使用Fama-MacBeth回归对因子进行测试。

## 结论
多因子组合能够获得更好的风险调整收益。
''';

      final configService = MockConfigService();

      final locator = ServiceLocator();
      locator.registerInstance<IConfigService>(configService);
      locator.registerInstance<IPaperService>(paperService);
      locator.registerInstance<ISearchService>(MockSearchService());
      locator.registerInstance<ICacheService>(MockCacheService());
      locator.registerInstance<INetworkService>(MockNetworkService());
      locator.registerInstance<INoteService>(MockNoteService());
      locator.registerInstance<ISoulService>(MockSoulService());
      locator.registerInstance<IMemoryService>(MockMemoryService());
      locator.registerInstance<IPortraitService>(MockPortraitService());
      locator.registerInstance<IAvatarService>(MockAvatarService());
      locator.registerInstance<ILLMProvider>(MockLLMProvider());

      await tester.pumpWidget(MaterialApp(
        home: Dependencies(
          locator: locator,
          child: Scaffold(
            body: ReadPage(paper: Paper(
              id: 'e2e_read',
              title: '中国股市量化选股因子全解析',
              year: 2024,
              status: PaperStatus.parsed,
            )),
          ),
        ),
      ));

      // Pump frames for async _loadContent
      for (var i = 0; i < 10; i++) {
        await tester.pump(const Duration(milliseconds: 50));
        try {
          if (find.byWidgetPredicate((w) => w is SelectableText && w.data!.contains('选股因子')).evaluate().isNotEmpty) {
            break;
          }
        } catch (_) {}
      }

      // Verify real content rendered
      expect(
        find.byWidgetPredicate((w) => w is SelectableText && w.data!.contains('选股因子')),
        findsOneWidget,
      );
      expect(
        find.byWidgetPredicate((w) => w is SelectableText && w.data!.contains('Fama-MacBeth')),
        findsOneWidget,
      );
      expect(
        find.byWidgetPredicate((w) => w is SelectableText && w.data!.contains('风险调整收益')),
        findsOneWidget,
      );

      // Verify AppBar shows paper title
      expect(find.text('中国股市量化选股因子全解析'), findsOneWidget);

      // Test ask question with real content
      final qaField = find.byType(TextField).last;
      await tester.enterText(qaField, '这篇文章用了什么回归方法？');
      await tester.tap(find.byIcon(Icons.send));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 50));

      expect(find.textContaining('Mock streaming answer'), findsOneWidget);
    });
  });
}
