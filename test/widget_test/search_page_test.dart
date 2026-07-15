import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:paperpal/core/models/search_result.dart';
import 'package:paperpal/core/di/dependencies.dart';
import 'package:paperpal/core/di/service_locator.dart';
import 'package:paperpal/ui/pages/search_page.dart';
import '../helpers/mock_services.dart';

Widget buildApp({
  required MockSearchService searchService,
  required MockPaperService paperService,
  required MockNetworkService networkService,
  required MockConfigService configService,
}) {
  final locator = ServiceLocator();
  locator.registerInstance<IConfigService>(configService);
  locator.registerInstance<IPaperService>(paperService);
  locator.registerInstance<ISearchService>(searchService);
  locator.registerInstance<ICacheService>(MockCacheService());
  locator.registerInstance<INetworkService>(networkService);
  locator.registerInstance<INoteService>(MockNoteService());
  locator.registerInstance<ISoulService>(MockSoulService());
  locator.registerInstance<IMemoryService>(MockMemoryService());
  locator.registerInstance<IPortraitService>(MockPortraitService());
  locator.registerInstance<IAvatarService>(MockAvatarService());
  locator.registerInstance<ILLMProvider>(MockLLMProvider());
  return MaterialApp(
    home: Dependencies(
      locator: locator,
      child: const Scaffold(body: SearchPage()),
    ),
  );
}

void main() {
  group('SearchPage', () {
    late MockSearchService searchService;
    late MockPaperService paperService;
    late MockNetworkService networkService;
    late MockConfigService configService;

    setUp(() {
      searchService = MockSearchService();
      paperService = MockPaperService();
      networkService = MockNetworkService();
      configService = MockConfigService();
    });

    testWidgets('shows empty state initially', (tester) async {
      await tester.pumpWidget(buildApp(
        searchService: searchService,
        paperService: paperService,
        networkService: networkService,
        configService: configService,
      ));
      await tester.pumpAndSettle();

      expect(find.text('输入关键词开始搜索论文'), findsOneWidget);
      expect(find.text('或点击"上传 PDF"导入本地论文'), findsOneWidget);
    });

    testWidgets('shows search results after query', (tester) async {
      searchService.mockResults = [
        const SearchResult(
          title: 'Attention Is All You Need',
          authors: ['Vaswani et al.'],
          year: 2017,
          abstract: 'A seminal paper on transformers.',
          pdfUrl: 'https://arxiv.org/pdf/1706.03762.pdf',
          source: 'arXiv',
          citationCount: 50000,
        ),
        const SearchResult(
          title: 'BERT: Pre-training of Deep Bidirectional Transformers',
          authors: ['Devlin et al.'],
          year: 2019,
          source: 'Semantic Scholar',
          citationCount: 30000,
        ),
      ];

      await tester.pumpWidget(buildApp(
        searchService: searchService,
        paperService: paperService,
        networkService: networkService,
        configService: configService,
      ));
      await tester.pumpAndSettle();

      // Enter search query
      await tester.enterText(find.byType(TextField), 'transformer');
      await tester.testTextInput.receiveAction(TextInputAction.done);
      await tester.pumpAndSettle();

      // Results should appear
      expect(find.text('Attention Is All You Need'), findsOneWidget);
      expect(find.text('BERT: Pre-training of Deep Bidirectional Transformers'), findsOneWidget);
    });

    testWidgets('shows error when search fails', (tester) async {
      searchService.mockError = '网络请求失败，请检查网络连接';

      await tester.pumpWidget(buildApp(
        searchService: searchService,
        paperService: paperService,
        networkService: networkService,
        configService: configService,
      ));
      await tester.pumpAndSettle();

      await tester.enterText(find.byType(TextField), 'test');
      await tester.testTextInput.receiveAction(TextInputAction.done);
      await tester.pumpAndSettle();

      expect(find.text('网络请求失败，请检查网络连接'), findsOneWidget);
    });

    testWidgets('shows no results message', (tester) async {
      searchService.mockResults = [];

      await tester.pumpWidget(buildApp(
        searchService: searchService,
        paperService: paperService,
        networkService: networkService,
        configService: configService,
      ));
      await tester.pumpAndSettle();

      await tester.enterText(find.byType(TextField), 'xyznonexistent');
      await tester.testTextInput.receiveAction(TextInputAction.done);
      await tester.pumpAndSettle();

      expect(find.text('未找到相关论文，试试其他关键词'), findsOneWidget);
    });

    testWidgets('shows offline message when network unavailable', (tester) async {
      networkService.isOnline = false;

      await tester.pumpWidget(buildApp(
        searchService: searchService,
        paperService: paperService,
        networkService: networkService,
        configService: configService,
      ));
      await tester.pumpAndSettle();

      await tester.enterText(find.byType(TextField), 'test');
      await tester.testTextInput.receiveAction(TextInputAction.done);
      await tester.pumpAndSettle();

      expect(find.text('网络不可用，请检查网络连接后重试'), findsOneWidget);
    });

    testWidgets('imports paper when result is tapped', (tester) async {
      searchService.mockResults = [
        const SearchResult(
          title: 'Test Paper',
          authors: ['Author'],
          year: 2024,
          pdfUrl: 'https://example.com/paper.pdf',
          source: 'arXiv',
        ),
      ];

      await tester.pumpWidget(buildApp(
        searchService: searchService,
        paperService: paperService,
        networkService: networkService,
        configService: configService,
      ));
      await tester.pumpAndSettle();

      await tester.enterText(find.byType(TextField), 'test');
      await tester.testTextInput.receiveAction(TextInputAction.done);
      await tester.pumpAndSettle();

      // Tap the result card
      await tester.tap(find.text('Test Paper'));
      await tester.pumpAndSettle();

      // Should show import success
      expect(find.textContaining('导入成功'), findsOneWidget);
      expect(paperService.papers.length, 1);
      expect(paperService.papers.first.title, 'Test Paper');
    });

    testWidgets('shows error when importing paper without PDF URL', (tester) async {
      searchService.mockResults = [
        const SearchResult(
          title: 'No PDF Paper',
          authors: ['Author'],
          year: 2024,
          source: 'arXiv',
        ),
      ];

      await tester.pumpWidget(buildApp(
        searchService: searchService,
        paperService: paperService,
        networkService: networkService,
        configService: configService,
      ));
      await tester.pumpAndSettle();

      await tester.enterText(find.byType(TextField), 'test');
      await tester.testTextInput.receiveAction(TextInputAction.done);
      await tester.pumpAndSettle();

      await tester.tap(find.text('No PDF Paper'));
      await tester.pumpAndSettle();

      expect(find.text('该论文无开放获取 PDF 链接'), findsOneWidget);
    });

    testWidgets('shows URL import field when link button toggled', (tester) async {
      await tester.pumpWidget(buildApp(
        searchService: searchService,
        paperService: paperService,
        networkService: networkService,
        configService: configService,
      ));
      await tester.pumpAndSettle();

      expect(find.text('贴链接'), findsOneWidget);
      await tester.tap(find.text('贴链接'));
      await tester.pumpAndSettle();

      expect(find.text('粘贴 arXiv 链接或 PDF 直链...'), findsOneWidget);
    });
  });
}
