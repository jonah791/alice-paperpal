import 'package:flutter_test/flutter_test.dart';
import 'package:paperpal/core/services/parse_service.dart';
import 'package:paperpal/core/api/mineru_api.dart';
import 'package:paperpal/core/models/parse_result.dart';

void main() {
  group('MergeService edge cases', () {
    test('single empty string batch', () {
      final r = MergeService.merge(['']);
      expect(r.markdown, '');
      expect(r.title, '');
    });

    test('empty markdown batch with title line', () {
      final r = MergeService.merge(['# OnlyTitle\n']);
      expect(r.markdown, '# OnlyTitle\n');
      expect(r.title, 'OnlyTitle');
    });

    test('title extraction from second H1', () {
      final r = MergeService.merge(['## first\nbody', '# second\nmore']);
      expect(r.title, 'second');
    });

    test('title with leading/trailing whitespace', () {
      final r = MergeService.merge(['#   Padded Title   \ntext']);
      expect(r.title, 'Padded Title');
    });

    test('no H1 title returns empty', () {
      final r = MergeService.merge(['\nbody without title']);
      expect(r.title, '');
    });

    test('single char title', () {
      final r = MergeService.merge(['# X\ntext']);
      expect(r.title, 'X');
    });

    test('unicode title', () {
      final r = MergeService.merge(['# 深度学习\ntext']);
      expect(r.title, '深度学习');
    });

    test('separator between more than 2 batches', () {
      final r = MergeService.merge(['a', 'b', 'c', 'd']);
      final parts = r.markdown.split('<!-- batch-break -->');
      expect(parts, hasLength(4));
    });
  });

  group('ParseService buildPageRanges', () {
    final api = MineruApi(apiKey: 'k');
    final ps = ParseService(api: api);

    test('single page equals single task (no splitting)', () {
      final ranges = ps.buildPageRanges(1);
      expect(ranges, isEmpty);
    });

    test('maxPagesPerTask pages equals single task', () {
      final ranges = ps.buildPageRanges(ParseService.maxPagesPerTask);
      expect(ranges, isEmpty);
    });

    test('maxPagesPerTask + 1 page splits into 2 tasks', () {
      final ranges = ps.buildPageRanges(ParseService.maxPagesPerTask + 1);
      expect(ranges, hasLength(2));
    });

    test('exactly 2x maxPagesPerTask pages splits into 2 tasks', () {
      final ranges = ps.buildPageRanges(ParseService.maxPagesPerTask * 2);
      expect(ranges, hasLength(2));
    });

    test('large document proper splitting', () {
      final ranges = ps.buildPageRanges(500);
      expect(ranges, hasLength(3));
      expect(ranges[0].start, 0);
      expect(ranges[0].end, 199);
      expect(ranges[1].start, 200);
      expect(ranges[1].end, 399);
      expect(ranges[2].start, 400);
      expect(ranges[2].end, 499);
    });

    test('exactly maxPagesPerTask boundary', () {
      final ranges = ps.buildPageRanges(200);
      expect(ranges, isEmpty);
    });
  });

  group('ParseProgress model', () {
    test('construction with defaults', () {
      final p = ParseProgress(currentBatch: 1, totalBatches: 5);
      expect(p.currentBatch, 1);
      expect(p.totalBatches, 5);
      expect(p.currentPage, 0);
      expect(p.totalPages, 0);
    });

    test('full construction', () {
      final p = ParseProgress(currentBatch: 2, totalBatches: 3, currentPage: 50, totalPages: 150);
      expect(p.currentBatch, 2);
      expect(p.totalBatches, 3);
      expect(p.currentPage, 50);
      expect(p.totalPages, 150);
    });
  });
}
