import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:paperpal/ui/theme/app_theme.dart';

void main() {
  testWidgets('AppTheme light and dark themes are valid', (WidgetTester tester) async {
    await tester.pumpWidget(MaterialApp(
      theme: AppTheme.light,
      darkTheme: AppTheme.dark,
      themeMode: ThemeMode.system,
      home: const Scaffold(body: Center(child: Text('PaperPal'))),
    ));
    expect(find.text('PaperPal'), findsOneWidget);
  });
}
