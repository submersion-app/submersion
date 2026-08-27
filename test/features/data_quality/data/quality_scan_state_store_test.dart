import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:submersion/features/data_quality/data/services/quality_scan_state_store.dart';
import 'package:submersion/features/data_quality/domain/detectors/quality_detector_registry.dart';

void main() {
  late SharedPreferences prefs;
  late QualityScanStateStore store;

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    prefs = await SharedPreferences.getInstance();
    store = QualityScanStateStore(prefs);
  });

  test('reads null/empty defaults before any scan is recorded', () {
    expect(store.lastFullScanAt, isNull);
    expect(store.lastScanDetectorVersions, isEmpty);
  });

  test('hasNewDetectorVersions is false when the device never scanned', () {
    // lastFullScanAt == null short-circuits to false (shows the scan CTA).
    expect(store.hasNewDetectorVersions, isFalse);
  });

  test('recordFullScan persists the timestamp and detector versions', () async {
    final at = DateTime.utc(2026, 7, 10, 9);
    await store.recordFullScan(at, {'gas_mod': 1, 'split_pair': 1});

    expect(
      store.lastFullScanAt!.millisecondsSinceEpoch,
      at.millisecondsSinceEpoch,
    );
    expect(store.lastScanDetectorVersions, {'gas_mod': 1, 'split_pair': 1});
  });

  test(
    'hasNewDetectorVersions is false after recording current versions',
    () async {
      await store.recordFullScan(
        DateTime.utc(2026, 7, 10),
        qualityDetectorVersions(),
      );
      expect(store.hasNewDetectorVersions, isFalse);
    },
  );

  test(
    'hasNewDetectorVersions is true when a detector is newer than the last scan',
    () async {
      // Every detector recorded at version 0: all current versions exceed it.
      final stale = {
        for (final e in qualityDetectorVersions().entries) e.key: 0,
      };
      await store.recordFullScan(DateTime.utc(2026, 7, 10), stale);
      expect(store.hasNewDetectorVersions, isTrue);
    },
  );

  test(
    'hasNewDetectorVersions is true when a detector is absent from the last scan',
    () async {
      // Recorded map lacks all current detectors: (last[key] ?? 0) < version.
      await store.recordFullScan(DateTime.utc(2026, 7, 10), {'obsolete': 99});
      expect(store.hasNewDetectorVersions, isTrue);
    },
  );
}
