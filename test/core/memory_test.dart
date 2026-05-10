import 'package:flutter_test/flutter_test.dart';
import 'package:paperpal/core/services/memory_service.dart';

void main() {
  group('MemoryItem model', () {
    test('toJson and fromJson round-trip', () {
      final now = DateTime(2026, 5, 10, 12, 0, 0);
      final item = MemoryItem(
        id: 'mem_1',
        summary: '用户对 transformer 感兴趣',
        paperId: 'paper_1',
        timestamp: now,
      );
      final json = item.toJson();
      final restored = MemoryItem.fromJson(json);
      expect(restored.id, item.id);
      expect(restored.summary, item.summary);
      expect(restored.paperId, item.paperId);
      expect(restored.timestamp.toIso8601String(), now.toIso8601String());
    });

    test('handles null paperId', () {
      final item = MemoryItem(
        id: 'mem_2',
        summary: 'summary',
        timestamp: DateTime.now(),
      );
      expect(item.paperId, isNull);
    });

    test('handles missing fields gracefully', () {
      final restored = MemoryItem.fromJson({'id': 'mem_3', 'summary': 'test'});
      expect(restored.id, 'mem_3');
      expect(restored.summary, 'test');
      expect(restored.paperId, isNull);
    });

    test('handles invalid timestamp falls back to now', () {
      final restored = MemoryItem.fromJson({
        'id': 'mem_4',
        'summary': 'test',
        'timestamp': 'not-a-date',
      });
      expect(restored.id, 'mem_4');
      expect(restored.timestamp, isA<DateTime>());
    });

    test('handles missing timestamp', () {
      final restored = MemoryItem.fromJson({'id': 'mem_5', 'summary': 'test'});
      expect(restored.timestamp, isA<DateTime>());
    });

    test('handles empty summary', () {
      final restored = MemoryItem.fromJson({'id': 'mem_6', 'summary': ''});
      expect(restored.summary, '');
    });
  });

  group('MemoryService state logic', () {
    test('getRecent returns empty before init', () {
      final service = MemoryService();
      expect(service.getRecent(), isEmpty);
    });

    test('getRecent with custom limit', () {
      final service = MemoryService();
      expect(service.getRecent(limit: 5), isEmpty);
    });

    test('summarizeRecent returns empty for empty memories', () {
      final service = MemoryService();
      expect(service.summarizeRecent(), isEmpty);
    });

    test('summarizeRecent with limit returns empty', () {
      final service = MemoryService();
      expect(service.summarizeRecent(limit: 3), isEmpty);
    });

    test('summarizeRecent empty string for zero limit', () {
      final service = MemoryService();
      expect(service.summarizeRecent(limit: 0), isEmpty);
    });
  });
}
