import 'package:flutter_test/flutter_test.dart';
import 'package:paperpal/core/api/mineru_api.dart';

void main() {
  group('MineruTaskState', () {
    final api = MineruApi(apiKey: 'test-key');

    test('done maps to done', () {
      expect(api.parseState('done'), MineruTaskState.done);
    });

    test('failed maps to failed', () {
      expect(api.parseState('failed'), MineruTaskState.failed);
    });

    test('running maps to running', () {
      expect(api.parseState('running'), MineruTaskState.running);
    });

    test('pending maps to pending', () {
      expect(api.parseState('pending'), MineruTaskState.pending);
      expect(api.parseState('waiting-file'), MineruTaskState.pending);
    });

    test('uploading maps to running (same as in-progress)', () {
      expect(api.parseState('uploading'), MineruTaskState.running);
    });

    test('converting maps to converting', () {
      expect(api.parseState('converting'), MineruTaskState.converting);
    });

    test('unknown string maps to pending', () {
      expect(api.parseState(''), MineruTaskState.pending);
      expect(api.parseState('invalid'), MineruTaskState.pending);
    });
  });

  group('MineruTask', () {
    test('done is terminal', () {
      expect(const MineruTask(id: '1', state: MineruTaskState.done).isTerminal, true);
    });

    test('failed is terminal', () {
      expect(const MineruTask(id: '1', state: MineruTaskState.failed).isTerminal, true);
    });

    test('running is not terminal', () {
      expect(const MineruTask(id: '1', state: MineruTaskState.running).isTerminal, false);
    });

    test('pending is not terminal', () {
      expect(const MineruTask(id: '1', state: MineruTaskState.pending).isTerminal, false);
    });

    test('converting is not terminal', () {
      expect(const MineruTask(id: '1', state: MineruTaskState.converting).isTerminal, false);
    });

    test('full constructor with optional fields', () {
      final t = MineruTask(
        id: 'task_1', state: MineruTaskState.done, zipUrl: 'https://cdn.mineru.net/result.zip',
        errorMessage: null, extractedPages: 10, totalPages: 50,
      );
      expect(t.id, 'task_1');
      expect(t.zipUrl, 'https://cdn.mineru.net/result.zip');
      expect(t.extractedPages, 10);
      expect(t.totalPages, 50);
    });

    test('errorMessage populated on failed', () {
      final t = MineruTask(id: '1', state: MineruTaskState.failed, errorMessage: 'file too large');
      expect(t.errorMessage, 'file too large');
    });
  });

  group('MineruResult', () {
    test('defaults', () {
      const r = MineruResult(markdown: '# test');
      expect(r.imagePaths, isEmpty);
      expect(r.contentListJson, '');
    });

    test('full fields', () {
      const r = MineruResult(markdown: '# full', imagePaths: ['a.png'], contentListJson: '{}');
      expect(r.imagePaths, ['a.png']);
      expect(r.contentListJson, '{}');
    });
  });
}
