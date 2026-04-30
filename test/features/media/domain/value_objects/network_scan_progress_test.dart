import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/features/media/domain/value_objects/network_scan_progress.dart';

void main() {
  group('NetworkScanProgress', () {
    test('value-equality on identical fields', () {
      const a = NetworkScanProgress(
        phase: NetworkScanPhase.scanning,
        total: 10,
        done: 4,
        available: 3,
        unreachable: 1,
      );
      const b = NetworkScanProgress(
        phase: NetworkScanPhase.scanning,
        total: 10,
        done: 4,
        available: 3,
        unreachable: 1,
      );
      expect(a, b);
    });

    test('starting() factory has zeroed counters', () {
      final p = NetworkScanProgress.starting(total: 17);
      expect(p.phase, NetworkScanPhase.starting);
      expect(p.total, 17);
      expect(p.done, 0);
      expect(p.available, 0);
      expect(p.unreachable, 0);
    });

    test('fractionDone is done / total clamped to [0, 1]', () {
      const p = NetworkScanProgress(
        phase: NetworkScanPhase.scanning,
        total: 10,
        done: 5,
        available: 4,
        unreachable: 1,
      );
      expect(p.fractionDone, 0.5);

      const empty = NetworkScanProgress(
        phase: NetworkScanPhase.starting,
        total: 0,
        done: 0,
        available: 0,
        unreachable: 0,
      );
      expect(empty.fractionDone, 0.0);
    });
  });

  group('NetworkScanReport', () {
    test('round-trips counts', () {
      const r = NetworkScanReport(
        total: 12,
        available: 9,
        unreachable: 2,
        skippedNoUrl: 1,
        durationMs: 4500,
      );
      expect(r.total, 12);
      expect(r.available, 9);
      expect(r.unreachable, 2);
      expect(r.skippedNoUrl, 1);
      expect(r.durationMs, 4500);
    });

    test(
      'fromProgress builds the final report from the last progress event',
      () {
        const p = NetworkScanProgress(
          phase: NetworkScanPhase.finished,
          total: 5,
          done: 5,
          available: 4,
          unreachable: 1,
        );
        final r = NetworkScanReport.fromProgress(
          p,
          skippedNoUrl: 0,
          durationMs: 3200,
        );
        expect(r.total, 5);
        expect(r.available, 4);
        expect(r.unreachable, 1);
        expect(r.skippedNoUrl, 0);
        expect(r.durationMs, 3200);
      },
    );
  });
}
