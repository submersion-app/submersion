import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/features/universal_import/data/services/garmin_activity_marker.dart';
import 'package:submersion/features/universal_import/data/services/garmin_device_importer.dart';
import 'package:submersion/features/universal_import/data/services/garmin_marker_after_import.dart';

import 'fake_garmin_download_history.dart';

/// Issue #4223: the marker moves on only once the Garmin's own import is done.
void main() {
  const marker = GarminActivityMarker(name: '2026-12-01-09-30-00.fit');
  const pending = GarminPendingMarker(
    marker: marker,
    paths: {'a.fit', 'b.fit'},
    computerId: 'dc-1',
    watchSerial: '123',
  );

  test('saves after an import of exactly the Garmin files', () async {
    final history = FakeGarminDownloadHistory();

    final saved = await saveGarminMarkerAfterImport(
      pending: pending,
      importedPaths: ['b.fit', 'a.fit'],
      dives: [
        {'diveComputerSerial': ' 3456789012 '},
        {'diveComputerSerial': ''},
        <String, dynamic>{},
      ],
      history: history,
    );

    expect(saved, isTrue);
    expect(history.saves.single.marker, marker);
    expect(history.saves.single.computerId, 'dc-1');
  });

  test('leaves it for an import of other files', () async {
    final history = FakeGarminDownloadHistory();

    for (final paths in [
      ['a.fit'],
      ['a.fit', 'b.fit', 'c.fit'],
      ['a.fit', 'picked.uddf'],
      <String?>[null],
    ]) {
      expect(
        await saveGarminMarkerAfterImport(
          pending: pending,
          importedPaths: paths,
          dives: const [],
          history: history,
        ),
        isFalse,
        reason: '$paths',
      );
    }
    expect(history.saves, isEmpty);
  });

  test('does nothing without a pending marker', () async {
    expect(
      await saveGarminMarkerAfterImport(
        pending: null,
        importedPaths: ['a.fit'],
        dives: const [],
        history: FakeGarminDownloadHistory(),
      ),
      isFalse,
    );
  });
}
