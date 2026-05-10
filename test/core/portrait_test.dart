import 'package:flutter_test/flutter_test.dart';
import 'package:paperpal/core/services/portrait_service.dart';

void main() {
  group('PortraitService', () {
    test('summarize returns empty for empty portrait', () {
      final service = PortraitService();
      final result = service.summarize();
      expect(result, isEmpty);
    });

    test('summarize does not crash before init', () {
      final service = PortraitService();
      expect(() => service.summarize(), returnsNormally);
    });

    test('deepMerge simple top-level fields', () {
      final service = PortraitService();
      final target = <String, dynamic>{'name': 'Alice', 'age': 25};
      service.deepMerge(target, {'age': 26, 'city': 'NYC'});
      expect(target['name'], 'Alice');
      expect(target['age'], 26);
      expect(target['city'], 'NYC');
    });

    test('deepMerge nested maps recursively', () {
      final service = PortraitService();
      final target = <String, dynamic>{
        'user': {'name': 'Bob', 'age': 30},
        'active': true,
      };
      service.deepMerge(target, {
        'user': {'age': 31, 'city': 'SF'},
        'extra': 'data',
      });
      expect((target['user'] as Map)['name'], 'Bob');
      expect((target['user'] as Map)['age'], 31);
      expect((target['user'] as Map)['city'], 'SF');
      expect(target['active'], true);
      expect(target['extra'], 'data');
    });

    test('deepMerge scalar overwrites scalar', () {
      final service = PortraitService();
      final target = <String, dynamic>{'key': 'old'};
      service.deepMerge(target, {'key': 'new'});
      expect(target['key'], 'new');
    });

    test('deepMerge scalar with map replaces value', () {
      final service = PortraitService();
      final target = <String, dynamic>{'key': 'string_value'};
      service.deepMerge(target, {'key': {'nested': 'value'}});
      expect(target['key'], {'nested': 'value'});
    });

    test('deepMerge empty source does nothing', () {
      final service = PortraitService();
      final target = <String, dynamic>{'a': 1};
      service.deepMerge(target, {});
      expect(target, {'a': 1});
    });

    test('deepMerge empty target receives source', () {
      final service = PortraitService();
      final target = <String, dynamic>{};
      service.deepMerge(target, {'a': 1, 'b': {'c': 2}});
      expect(target['a'], 1);
      expect((target['b'] as Map)['c'], 2);
    });

    test('deepMerge deeply nested maps', () {
      final service = PortraitService();
      final target = <String, dynamic>{
        'level1': {
          'level2': {
            'level3': 'deep_value',
            'keep_me': 'preserved',
          },
        },
      };
      service.deepMerge(target, {
        'level1': {
          'level2': {
            'level3': 'updated',
            'new_key': 'added',
          },
        },
      });
      final l1 = target['level1'] as Map;
      final l2 = l1['level2'] as Map;
      expect(l2['level3'], 'updated');
      expect(l2['keep_me'], 'preserved');
      expect(l2['new_key'], 'added');
    });
  });
}
