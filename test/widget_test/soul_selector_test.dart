import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:paperpal/core/models/soul.dart';
import 'package:paperpal/core/di/dependencies.dart';
import 'package:paperpal/core/di/service_locator.dart';
import 'package:paperpal/ui/widgets/soul_selector.dart';
import '../helpers/mock_services.dart';

const _academicMentor = Soul(
  id: 'academic_mentor',
  name: '学术导师',
  description: '严谨专业的学术伙伴',
  systemPrompt: '你是一位严谨的学术导师。',
  speechPattern: '让我们来分析这篇论文...',
);

const _creativeWriter = Soul(
  id: 'creative_writer',
  name: '创意作家',
  description: '富有创意的写作伙伴',
  systemPrompt: '你是一位创意作家。',
);

Widget buildApp({
  required MockSoulService soulService,
  required MockConfigService configService,
}) {
  final locator = ServiceLocator();
  locator.registerInstance<IConfigService>(configService);
  locator.registerInstance<IPaperService>(MockPaperService());
  locator.registerInstance<ISearchService>(MockSearchService());
  locator.registerInstance<ICacheService>(MockCacheService());
  locator.registerInstance<INetworkService>(MockNetworkService());
  locator.registerInstance<INoteService>(MockNoteService());
  locator.registerInstance<ISoulService>(soulService);
  locator.registerInstance<IMemoryService>(MockMemoryService());
  locator.registerInstance<IPortraitService>(MockPortraitService());
  locator.registerInstance<IAvatarService>(MockAvatarService());
  locator.registerInstance<ILLMProvider>(MockLLMProvider());
  return MaterialApp(
    home: Dependencies(
      locator: locator,
      child: const Scaffold(body: SoulSelector()),
    ),
  );
}

void main() {
  late MockConfigService configService;

  setUp(() {
    configService = MockConfigService();
  });

  testWidgets('shows current active soul name', (tester) async {
    final soulService = MockSoulService();
    soulService.presets = [_academicMentor];

    await tester.pumpWidget(buildApp(
      soulService: soulService,
      configService: configService,
    ));

    expect(find.text('学术导师'), findsNWidgets(2));
    expect(find.text('严谨专业的学术伙伴'), findsOneWidget);
  });

  testWidgets('shows preset souls as ChoiceChips', (tester) async {
    final soulService = MockSoulService();
    soulService.presets = [_academicMentor, _creativeWriter];

    await tester.pumpWidget(buildApp(
      soulService: soulService,
      configService: configService,
    ));

    expect(find.text('学术导师'), findsWidgets);
    expect(find.text('创意作家'), findsOneWidget);
    expect(find.byType(ChoiceChip), findsNWidgets(2));
  });

  testWidgets('tapping preset soul calls setActiveSoul', (tester) async {
    final soulService = MockSoulService();
    soulService.presets = [_academicMentor, _creativeWriter];

    await tester.pumpWidget(buildApp(
      soulService: soulService,
      configService: configService,
    ));

    await tester.tap(find.text('创意作家'));
    await tester.pump();

    expect(soulService.activeSoul!.id, 'creative_writer');
  });

  testWidgets('shows create button and creator form on tap', (tester) async {
    final soulService = MockSoulService();
    soulService.presets = [_academicMentor];

    await tester.pumpWidget(buildApp(
      soulService: soulService,
      configService: configService,
    ));

    expect(find.text('创建新伙伴'), findsOneWidget);

    await tester.tap(find.text('创建新伙伴'));
    await tester.pump();

    expect(find.text('创建新伙伴'), findsNothing);
    expect(find.text('给伙伴起个名字'), findsOneWidget);
    expect(find.text('生成并保存'), findsOneWidget);
  });
}
