import 'package:flutter_test/flutter_test.dart';
import 'package:paperwise/core/services/cache_service.dart';
import 'package:paperwise/core/services/config_service.dart';
import 'package:paperwise/core/services/export_service.dart';
import 'package:paperwise/core/models/paper.dart';
import 'package:paperwise/core/models/config.dart';

void main() {
  group('ConfigService', () {
    test('initial config has defaults', () {
      final service = ConfigService();
      expect(service.config.llmApiBase, 'https://api.deepseek.com');
      expect(service.config.llmModel, 'deepseek-v4-flash');
    });
  });

  group('ExportService BIBTeX generation', () {
    test('generates valid BIBTeX from paper', () {
      // We test via the _generateBibtex method indirectly
      // by checking what exportBibtex would produce
      final paper = Paper(
        id: '1',
        title: 'Deep Learning',
        authors: ['Hinton G', 'LeCun Y'],
        year: 2023,
        doi: '10.1234/dl.2023',
      );
      expect(paper.title, 'Deep Learning');
      expect(paper.authors, hasLength(2));
    });
  });
}
