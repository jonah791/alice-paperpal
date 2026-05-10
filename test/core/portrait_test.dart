import 'package:flutter_test/flutter_test.dart';
import 'package:paperpal/core/services/portrait_service.dart';

void main() {
  group('PortraitService', () {
    test('summarize returns empty for empty portrait', () {
      // PortraitService requires init, testing via direct behavior
      final service = PortraitService();
      // Before init, summarize should return empty string
      final result = service.summarize();
      expect(result, isEmpty);
    });
  });
}
