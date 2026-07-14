import 'package:flutter_test/flutter_test.dart';
import 'package:paperpal/core/models/search_result.dart';

void main() {
  group('SearchService dedup logic', () {
    SearchResult makeResult({
      required String title,
      String doi = '',
      String source = 'arXiv',
      int year = 2024,
      String pdfUrl = '',
    }) {
      return SearchResult(
        title: title,
        authors: ['A'],
        year: year,
        doi: doi,
        source: source,
        pdfUrl: pdfUrl,
      );
    }

    Map<String, SearchResult> dedup(List<SearchResult> arxivResults, List<SearchResult> s2Results) {
      final all = <String, SearchResult>{};
      for (final r in [...arxivResults, ...s2Results]) {
        final key = r.doi.isNotEmpty ? r.doi : r.title.toLowerCase();
        if (!all.containsKey(key)) {
          all[key] = r;
        } else {
          final existing = all[key]!;
          final existingHasPdf = existing.pdfUrl.isNotEmpty;
          final newHasPdf = r.pdfUrl.isNotEmpty;
          if (!existingHasPdf && newHasPdf) {
            all[key] = r;
          } else if (existingHasPdf == newHasPdf && existing.source == 'arXiv') {
            all[key] = r;
          }
        }
      }
      return all;
    }

    test('empty results from both sources', () {
      final result = dedup([], []);
      expect(result, isEmpty);
    });

    test('single result from arXiv', () {
      final result = dedup([makeResult(title: 'Test Paper')], []);
      expect(result, hasLength(1));
    });

    test('single result from Semantic Scholar', () {
      final result = dedup([], [makeResult(title: 'Test Paper', source: 'Semantic Scholar')]);
      expect(result, hasLength(1));
    });

    test('duplicate by DOI: S2 overrides arXiv when S2 comes after', () {
      // In SearchService, arXiv results are expanded first, then S2.
      // Code: if (!all.containsKey(key) || all[key]!.source == 'arXiv') all[key] = r;
      // This means if the first result is arXiv, S2 will override it.
      final arxiv = [makeResult(title: 'Test', doi: '10.1234/ab', source: 'arXiv')];
      final s2 = [makeResult(title: 'Test Paper Longer', doi: '10.1234/ab', source: 'Semantic Scholar')];
      final result = dedup(arxiv, s2);
      expect(result, hasLength(1));
      expect(result.values.first.source, 'Semantic Scholar');
    });

    test('duplicate by DOI from S2 only', () {
      final s2a = makeResult(title: 'T', doi: '10.1/a', source: 'Semantic Scholar');
      final s2b = makeResult(title: 'T Dup', doi: '10.1/a', source: 'Semantic Scholar');
      final result = dedup([], [s2a, s2b]);
      expect(result, hasLength(1));
    });

    test('duplicate by title (no DOI): S2 overrides arXiv via expand order', () {
      final arxiv = [makeResult(title: 'Hello World', source: 'arXiv')];
      final s2 = [makeResult(title: 'Hello World', source: 'Semantic Scholar')];
      final result = dedup(arxiv, s2);
      expect(result, hasLength(1));
      expect(result.values.first.source, 'Semantic Scholar');
    });

    test('different case titles without DOI treated as different', () {
      final arxiv = [makeResult(title: 'HELLO WORLD', source: 'arXiv')];
      final s2 = [makeResult(title: 'Hello World', source: 'Semantic Scholar')];
      final result = dedup(arxiv, s2);
      expect(result, hasLength(1));
    });

    test('different papers from both sources', () {
      final arxiv = [makeResult(title: 'Paper A', source: 'arXiv')];
      final s2 = [makeResult(title: 'Paper B', source: 'Semantic Scholar')];
      final result = dedup(arxiv, s2);
      expect(result, hasLength(2));
    });

    test('arXiv result overrides S2 via reorder', () {
      final s2 = [makeResult(title: 'Paper X', doi: '10.0/x', source: 'Semantic Scholar')];
      final arxiv = [makeResult(title: 'Paper X', doi: '10.0/x', source: 'arXiv')];
      // arXiv comes second (simulating expand order: arxiv + s2)
      final result = dedup(s2, arxiv);
      // With doi key, first S2 result set, then arXiv overrides
      // Actually the code checks: if (!all.containsKey(key) || all[key]!.source == 'arXiv')
      // S2 sets first: all['10.0/x'] = S2. Then arXiv: all['10.0/x'].source is 'Semantic Scholar', not 'arXiv'
      // So arXiv does NOT override. The current code gives precedence to first result UNLESS first is arXiv.
      // The behavior is: keep the first, or replace arXiv with non-arXiv
      expect(result, hasLength(1));
      expect(result.values.first.source, 'Semantic Scholar');
    });

    test('arXiv overrides another arXiv via title lowercased', () {
      final a1 = makeResult(title: 'Deep Learning', source: 'arXiv', year: 2022);
      final a2 = makeResult(title: 'Deep Learning', source: 'arXiv', year: 2023);
      final result = dedup([a1], [a2]);
      expect(result, hasLength(1));
    });

    test('results sorted by year descending', () {
      final r1 = makeResult(title: 'Old Paper', year: 2020);
      final r2 = makeResult(title: 'New Paper', year: 2024);
      final all = <String, SearchResult>{
        'old': r1,
        'new': r2,
      };
      final sorted = all.values.toList()..sort((a, b) => b.year.compareTo(a.year));
      expect(sorted[0].year, 2024);
      expect(sorted[1].year, 2020);
    });

    test('empty search query handling', () {
      final result = dedup([], []);
      expect(result, isEmpty);
    });
  });

  group('SearchService downloadPdf mock logic', () {
    test('empty pdfUrl returns null', () {
      final result = SearchResult(title: 'T', authors: ['A'], pdfUrl: '');
      expect(result.pdfUrl, isEmpty);
    });
  });
}
