import 'package:flutter_test/flutter_test.dart';

import 'package:submersion/features/species_id/domain/entities/scanned_ranges.dart';
import 'package:submersion/features/species_id/domain/services/video_scan_order.dart';

const _none = ScannedRanges();

PlayheadReport _seek(int ms) => PlayheadReport(ms: ms, seek: true, sequence: 1);
PlayheadReport _pause(int ms) =>
    PlayheadReport(ms: ms, seek: false, sequence: 1);

void main() {
  group('nextVideoChunk', () {
    test('opening an unscanned video starts with a short chunk', () {
      expect(
        nextVideoChunk(
          scanned: _none,
          durationMs: 60000,
          runEndMs: null,
          report: null,
        ),
        (startMs: 0, endMs: 2000),
      );
    });

    test('opening with the length unknown starts with a short chunk', () {
      expect(
        nextVideoChunk(
          scanned: _none,
          durationMs: null,
          runEndMs: null,
          report: null,
        ),
        (startMs: 0, endMs: 2000),
      );
    });

    test('continuing takes a full chunk', () {
      expect(
        nextVideoChunk(
          scanned: _none.add(0, 2000),
          durationMs: 60000,
          runEndMs: 2000,
          report: null,
        ),
        (startMs: 2000, endMs: 12000),
      );
    });

    test('a seek moves the next chunk there, short', () {
      expect(
        nextVideoChunk(
          scanned: _none.add(0, 12000),
          durationMs: 60000,
          runEndMs: 12000,
          report: _seek(30000),
        ),
        (startMs: 30000, endMs: 32000),
      );
    });

    test('a seek into a scanned stretch goes to its end', () {
      final scanned = _none.add(0, 20000);
      expect(
        nextVideoChunk(
          scanned: scanned,
          durationMs: 60000,
          runEndMs: null,
          report: _seek(5000),
        ),
        (startMs: 20000, endMs: 22000),
      );
      expect(
        nextVideoChunk(
          scanned: scanned,
          durationMs: 60000,
          runEndMs: 20000,
          report: _seek(5000),
        ),
        (startMs: 20000, endMs: 30000),
      );
    });

    test('a chunk stops where the next scanned stretch starts', () {
      expect(
        nextVideoChunk(
          scanned: _none.add(0, 25000).add(30000, 40000),
          durationMs: 60000,
          runEndMs: 25000,
          report: null,
        ),
        (startMs: 25000, endMs: 30000),
      );
    });

    test('at the end of the video it fills the first gap from the start', () {
      expect(
        nextVideoChunk(
          scanned: _none.add(0, 10000).add(30000, 60000),
          durationMs: 60000,
          runEndMs: 60000,
          report: null,
        ),
        (startMs: 10000, endMs: 20000),
      );
    });

    test('a pause on scanned video is ignored', () {
      expect(
        nextVideoChunk(
          scanned: _none.add(0, 12000),
          durationMs: 60000,
          runEndMs: 12000,
          report: _pause(5000),
        ),
        (startMs: 12000, endMs: 22000),
      );
    });

    test('a pause on unscanned video moves the scan there', () {
      expect(
        nextVideoChunk(
          scanned: _none.add(0, 12000),
          durationMs: 60000,
          runEndMs: 12000,
          report: _pause(45000),
        ),
        (startMs: 45000, endMs: 47000),
      );
    });

    test('a scan just made starts from a remembered pause, even on scanned '
        'video', () {
      expect(
        nextVideoChunk(
          scanned: _none.add(0, 10000).add(60000, 90000),
          durationMs: 180000,
          runEndMs: null,
          report: _pause(60000),
        ),
        (startMs: 90000, endMs: 92000),
      );
    });

    test('a report beyond the known length carries on from the run', () {
      expect(
        nextVideoChunk(
          scanned: _none.add(0, 40000),
          durationMs: 60000,
          runEndMs: 40000,
          report: _seek(90000),
        ),
        (startMs: 40000, endMs: 50000),
      );
    });

    test('a report with the length unknown is taken as it is', () {
      expect(
        nextVideoChunk(
          scanned: _none,
          durationMs: null,
          runEndMs: null,
          report: _seek(90000),
        ),
        (startMs: 90000, endMs: 92000),
      );
    });

    test('a chunk ends at the end of the video', () {
      expect(
        nextVideoChunk(
          scanned: _none.add(0, 55000),
          durationMs: 60000,
          runEndMs: 55000,
          report: null,
        ),
        (startMs: 55000, endMs: 60000),
      );
    });

    test('nothing when every stretch is scanned, even with a report', () {
      final all = _none.add(0, 60000);
      expect(
        nextVideoChunk(
          scanned: all,
          durationMs: 60000,
          runEndMs: 60000,
          report: null,
        ),
        isNull,
      );
      expect(
        nextVideoChunk(
          scanned: all,
          durationMs: 60000,
          runEndMs: 20000,
          report: _seek(30000),
        ),
        isNull,
      );
    });

    test('the chunk lengths can be set', () {
      expect(
        nextVideoChunk(
          scanned: _none,
          durationMs: 60000,
          runEndMs: null,
          report: null,
          firstChunkMs: 10000,
        ),
        (startMs: 0, endMs: 10000),
      );
      expect(
        nextVideoChunk(
          scanned: _none.add(0, 1000),
          durationMs: 60000,
          runEndMs: 1000,
          report: null,
          chunkMs: 5000,
        ),
        (startMs: 1000, endMs: 6000),
      );
    });
  });

  group('reportMovesScan', () {
    const running = (startMs: 30000, endMs: 40000);
    final scanned = _none.add(0, 30000);

    test('a seek inside the running chunk does not', () {
      expect(
        reportMovesScan(
          _seek(35000),
          scanned: scanned,
          durationMs: 60000,
          running: running,
        ),
        isFalse,
      );
    });

    test('a seek to unscanned video elsewhere does', () {
      expect(
        reportMovesScan(
          _seek(50000),
          scanned: scanned,
          durationMs: 60000,
          running: running,
        ),
        isTrue,
      );
      expect(
        reportMovesScan(
          _seek(10000),
          scanned: _none.add(20000, 30000),
          durationMs: 60000,
          running: running,
        ),
        isTrue,
      );
    });

    test('a pause on scanned video does not', () {
      expect(
        reportMovesScan(
          _pause(10000),
          scanned: scanned,
          durationMs: 60000,
          running: running,
        ),
        isFalse,
      );
    });

    test('a seek whose first gap is the running chunk does not', () {
      expect(
        reportMovesScan(
          _seek(10000),
          scanned: scanned,
          durationMs: 60000,
          running: running,
        ),
        isFalse,
      );
    });

    test('a seek past the end of a known length does not', () {
      expect(
        reportMovesScan(
          _seek(90000),
          scanned: scanned,
          durationMs: 60000,
          running: running,
        ),
        isFalse,
      );
    });
  });
}
