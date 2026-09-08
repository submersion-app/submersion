import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/features/dive_log/data/repositories/series_id_chunks.dart';

/// The boundary arithmetic behind every `id IN (...)` read and, since the
/// logbook export reuses it, the profile-loading loop as well. A dropped tail
/// chunk here is silent: the query simply returns fewer rows, and the export
/// renders fewer charts.
void main() {
  List<String> ids(int n) => List.generate(n, (i) => 'id$i');

  group('seriesIdChunks', () {
    test('yields nothing for an empty list', () {
      expect(seriesIdChunks(const []), isEmpty);
    });

    test('yields one short chunk when the list fits', () {
      expect(seriesIdChunks(ids(3)), [
        ['id0', 'id1', 'id2'],
      ]);
    });

    test('covers every id exactly once, in order', () {
      final chunks = seriesIdChunks(ids(2000)).toList();
      expect(chunks.expand((c) => c), ids(2000));
    });

    test('splits on the default size with a short final chunk', () {
      final chunks = seriesIdChunks(ids(2000)).toList();
      expect(chunks.map((c) => c.length), [900, 900, 200]);
    });

    test('does not emit an empty trailing chunk on an exact multiple', () {
      final chunks = seriesIdChunks(ids(1800)).toList();
      expect(chunks.map((c) => c.length), [900, 900]);
    });

    group('custom size', () {
      test('splits on the requested size', () {
        final chunks = seriesIdChunks(ids(125), size: 50).toList();
        expect(chunks.map((c) => c.length), [50, 50, 25]);
      });

      test('still covers every id exactly once', () {
        final chunks = seriesIdChunks(ids(125), size: 50).toList();
        expect(chunks.expand((c) => c), ids(125));
      });

      test('handles a size larger than the list', () {
        expect(seriesIdChunks(ids(3), size: 50).toList(), [
          ['id0', 'id1', 'id2'],
        ]);
      });

      test('handles a size of one', () {
        expect(seriesIdChunks(ids(3), size: 1).toList(), [
          ['id0'],
          ['id1'],
          ['id2'],
        ]);
      });

      test('rejects a non-positive size rather than looping forever', () {
        expect(
          () => seriesIdChunks(ids(3), size: 0).toList(),
          throwsA(isA<AssertionError>()),
        );
      });
    });
  });
}
