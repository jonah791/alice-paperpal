import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:paperpal/core/di/dependencies.dart';
import 'package:paperpal/core/di/service_locator.dart';
import 'package:paperpal/ui/widgets/avatar_picker.dart';
import '../helpers/mock_services.dart';

Widget buildApp({
  required MockAvatarService avatarService,
  required MockConfigService configService,
}) {
  final locator = ServiceLocator();
  locator.registerInstance<IConfigService>(configService);
  locator.registerInstance<IPaperService>(MockPaperService());
  locator.registerInstance<ISearchService>(MockSearchService());
  locator.registerInstance<ICacheService>(MockCacheService());
  locator.registerInstance<INetworkService>(MockNetworkService());
  locator.registerInstance<INoteService>(MockNoteService());
  locator.registerInstance<ISoulService>(MockSoulService());
  locator.registerInstance<IMemoryService>(MockMemoryService());
  locator.registerInstance<IPortraitService>(MockPortraitService());
  locator.registerInstance<IAvatarService>(avatarService);
  locator.registerInstance<ILLMProvider>(MockLLMProvider());
  return MaterialApp(
    home: Dependencies(
      locator: locator,
      child: const Scaffold(body: AvatarPicker()),
    ),
  );
}

void main() {
  late MockConfigService configService;

  setUp(() {
    configService = MockConfigService();
  });

  testWidgets('shows default avatar and buttons', (tester) async {
    final avatarService = MockAvatarService();
    avatarService.hasCustomAvatar = false;

    await tester.pumpWidget(buildApp(
      avatarService: avatarService,
      configService: configService,
    ));

    expect(find.byType(CircleAvatar), findsOneWidget);
    expect(find.text('学'), findsOneWidget);
    expect(find.text('默认头像'), findsOneWidget);
    expect(find.text('从相册选择'), findsOneWidget);
    expect(find.text('恢复默认'), findsNothing);
  });

  testWidgets('shows restore button when custom avatar exists', (tester) async {
    final avatarService = MockAvatarService();
    avatarService.hasCustomAvatar = true;
    avatarService.currentPath = '/tmp/test.png';

    await tester.pumpWidget(buildApp(
      avatarService: avatarService,
      configService: configService,
    ));

    expect(find.byType(CircleAvatar), findsNothing);
    expect(find.text('自定义头像'), findsOneWidget);
    expect(find.text('恢复默认'), findsOneWidget);
  });
}
