import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:paperpal/core/models/paper.dart';
import 'package:paperpal/core/di/dependencies.dart';
import 'package:paperpal/core/di/service_locator.dart';
import 'package:paperpal/ui/pages/read_page.dart';
import '../helpers/mock_services.dart';

Widget buildApp({
  required Paper paper,
  required MockPaperService paperService,
  required MockConfigService configService,
}) {
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
  return MaterialApp(
    home: Dependencies(
      locator: locator,
      child: Scaffold(body: ReadPage(paper: paper)),
    ),
  );
}

void main() {
  late MockPaperService paperService;
  late MockConfigService configService;

  setUp(() {
    paperService = MockPaperService();
    configService = MockConfigService();
  });

  Future<void> pumpUntilLoaded(WidgetTester tester) async {
    // ReadPage uses addPostFrameCallback → _loadContent → setState
    // Mock service returns synchronously, but async chain needs frames
    for (var i = 0; i < 10; i++) {
      await tester.pump(const Duration(milliseconds: 50));
      // Check if loading is done
      try {
        final loading = find.byType(CircularProgressIndicator);
        if (loading.evaluate().isEmpty) return;
      } catch (_) {}
    }
  }

  testWidgets('shows markdown content', (tester) async {
    paperService.markdowns['test_1'] = '# Test Paper\n\nThis is the introduction section.';

    await tester.pumpWidget(buildApp(
      paper: const Paper(id: 'test_1', title: 'Test Paper', year: 2024),
      paperService: paperService,
      configService: configService,
    ));
    await pumpUntilLoaded(tester);

    // Content is rendered in SelectableText, use byWidgetPredicate
    expect(
      find.byWidgetPredicate((w) => w is SelectableText && w.data!.contains('introduction section')),
      findsOneWidget,
    );
  });

  testWidgets('shows translated content when available', (tester) async {
    paperService.markdowns['test_2'] = '# Original';
    paperService.translations['test_2'] = '# 译文';

    await tester.pumpWidget(buildApp(
      paper: const Paper(id: 'test_2', title: 'Test Paper', year: 2024),
      paperService: paperService,
      configService: configService,
    ));
    await pumpUntilLoaded(tester);

    // Default view is translated
    expect(
      find.byWidgetPredicate((w) => w is SelectableText && w.data!.contains('译文')),
      findsOneWidget,
    );
  });

  testWidgets('shows translated content when available', (tester) async {
    paperService.markdowns['test_2'] = '# Original';
    paperService.translations['test_2'] = '# 译文';

    await tester.pumpWidget(buildApp(
      paper: const Paper(id: 'test_2', title: 'Test Paper', year: 2024),
      paperService: paperService,
      configService: configService,
    ));
    await pumpUntilLoaded(tester);

    // Default view is translated
    expect(find.text('译文'), findsOneWidget);
  });

  testWidgets('switches between original and translated', (tester) async {
    paperService.markdowns['test_3'] = '# Original Content';
    paperService.translations['test_3'] = '# Translated Content';

    await tester.pumpWidget(buildApp(
      paper: const Paper(id: 'test_3', title: 'Test Paper', year: 2024),
      paperService: paperService,
      configService: configService,
    ));
    await pumpUntilLoaded(tester);

    // Initially shows translated (default)
    expect(
      find.byWidgetPredicate((w) => w is SelectableText && w.data!.contains('Translated Content')),
      findsOneWidget,
    );

    // Tap "原文" button
    await tester.tap(find.text('原文'));
    await tester.pump();

    expect(
      find.byWidgetPredicate((w) => w is SelectableText && w.data!.contains('Original Content')),
      findsOneWidget,
    );
  });

  testWidgets('shows content after loading completes', (tester) async {
    paperService.markdowns['loading_test'] = '# Loaded';

    await tester.pumpWidget(buildApp(
      paper: const Paper(id: 'loading_test', title: 'Loading', year: 2024),
      paperService: paperService,
      configService: configService,
    ));

    // After pumpUntilLoaded, loading should be done
    await pumpUntilLoaded(tester);
    expect(
      find.byWidgetPredicate((w) => w is SelectableText && w.data!.contains('Loaded')),
      findsOneWidget,
    );
  });

  testWidgets('ask question shows answer', (tester) async {
    paperService.markdowns['test_4'] = '# Q&A Test';

    await tester.pumpWidget(buildApp(
      paper: const Paper(id: 'test_4', title: 'Test Paper', year: 2024),
      paperService: paperService,
      configService: configService,
    ));
    await pumpUntilLoaded(tester);

    // Enter question in QA field
    await tester.enterText(find.byType(TextField).last, 'What is this about?');
    // Submit by pressing send button
    await tester.tap(find.byIcon(Icons.send));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 50));

    // Should show the mock answer
    expect(find.textContaining('Mock streaming answer'), findsOneWidget);
  });

  testWidgets('shows font size picker', (tester) async {
    paperService.markdowns['test_5'] = '# Font Test';

    await tester.pumpWidget(buildApp(
      paper: const Paper(id: 'test_5', title: 'Font Test', year: 2024),
      paperService: paperService,
      configService: configService,
    ));
    await pumpUntilLoaded(tester);

    // Open font size picker
    await tester.tap(find.byIcon(Icons.font_download));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 100));

    expect(find.text('字体大小'), findsOneWidget);
    expect(find.text('14 px'), findsOneWidget);
  });
}
