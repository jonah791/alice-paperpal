import 'package:flutter_test/flutter_test.dart';
import 'package:paperpal/core/models/soul.dart';

void main() {
  group('Soul model', () {
    test('creates preset soul', () {
      final soul = Soul(
        id: 'academic_mentor',
        name: '学术导师',
        description: '严谨专业',
        systemPrompt: '你是一位学术导师',
        isBuiltin: true,
      );
      expect(soul.id, 'academic_mentor');
      expect(soul.isBuiltin, true);
      expect(soul.traits, isEmpty);
    });

    test('creates custom soul', () {
      final soul = Soul(
        id: 'custom_1',
        name: '我的伙伴',
        description: '自定义灵魂',
        traits: ['幽默', '亲切'],
        style: '轻松',
        specialty: '科普',
        systemPrompt: '你是我的伙伴',
        speechPattern: '喜欢用比喻',
        isCustom: true,
      );
      expect(soul.isCustom, true);
      expect(soul.traits, ['幽默', '亲切']);
    });

    test('toJson and fromJson round-trip', () {
      final soul = Soul(
        id: 'test',
        name: 'Test',
        description: 'desc',
        traits: ['a', 'b'],
        style: 'style',
        specialty: 'spec',
        systemPrompt: 'prompt',
        speechPattern: 'pattern',
        isBuiltin: true,
        isCustom: false,
      );
      final json = soul.toJson();
      final restored = Soul.fromJson(json);
      expect(restored.id, soul.id);
      expect(restored.name, soul.name);
      expect(restored.traits, soul.traits);
      expect(restored.systemPrompt, soul.systemPrompt);
      expect(restored.isBuiltin, soul.isBuiltin);
    });

    test('fromJson handles missing optional fields', () {
      final restored = Soul.fromJson({'id': '1', 'name': 'Test', 'systemPrompt': 'prompt'});
      expect(restored.id, '1');
      expect(restored.traits, isEmpty);
      expect(restored.speechPattern, isNull);
    });
  });
}
