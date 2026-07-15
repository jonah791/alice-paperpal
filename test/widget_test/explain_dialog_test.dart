import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:paperpal/core/di/dependencies.dart';
import 'package:paperpal/core/di/service_locator.dart';
import 'package:paperpal/ui/widgets/explain_dialog.dart';
import '../helpers/mock_services.dart';

Widget buildApp() {
  final locator = ServiceLocator();
  locator.registerInstance<IConfigService>(MockConfigService());
  locator.registerInstance<IPaperService>(MockPaperService());
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
      child: Scaffold(
        body: Builder(builder: (context) => ElevatedButton(
          onPressed: () => ExplainDialog.showFormula(context, paperId: 'test_1', latex: 'E=mc^2', sectionContext: 'relativity'),
          child: const Text('Explain'),
        )),
      ),
    ),
  );
}

void main() {
  testWidgets('showFormula opens dialog', (tester) async {
    await tester.pumpWidget(buildApp());
    await tester.tap(find.text('Explain'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 50));

    expect(find.text('公式解释'), findsOneWidget);
    expect(find.text('关闭'), findsOneWidget);
  });
}
