// Issue #4223: a Garmin download reads only the activities after the
// watch's download marker, and can be told to read them all again.

import 'dart:io';
import 'dart:typed_data';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:submersion/features/settings/presentation/providers/settings_providers.dart';
import 'package:submersion/features/universal_import/data/services/garmin_activity_marker.dart';
import 'package:submersion/features/universal_import/data/services/garmin_device_detector.dart';
import 'package:submersion/features/universal_import/data/services/garmin_device_importer.dart';
import 'package:submersion/features/universal_import/data/services/garmin_mtp_stager.dart';
import 'package:submersion/features/universal_import/presentation/providers/universal_import_providers.dart';

import '../../../../helpers/test_database.dart';
import '../../data/services/fake_garmin_download_history.dart';
import '../../data/services/fake_garmin_mtp_source.dart';

const _diveFixture = 'test/dives/005_oc-trimix-two-deco-gases.fit';

void main() {
  late Directory tmp;
  late Uint8List diveBytes;

  const october = '2026-10-01-08-00-00.fit';
  const november = '2026-11-01-10-00-00.fit';
  const december = '2026-12-01-09-30-00.fit';
  const markerAtNovember = GarminActivityMarker(name: november);

  setUp(() async {
    await setUpTestDatabase();
    SharedPreferences.setMockInitialValues({});
    tmp = await Directory.systemTemp.createTemp('garmin_marker_test');
    diveBytes = await File(_diveFixture).readAsBytes();
  });

  tearDown(() async {
    await tearDownTestDatabase();
    await tmp.delete(recursive: true);
  });

  Future<UniversalImportNotifier> notifierFor(
    FakeGarminMtpSource source,
    FakeGarminDownloadHistory history,
  ) async {
    final prefs = await SharedPreferences.getInstance();
    final container = ProviderContainer(
      overrides: [
        sharedPreferencesProvider.overrideWithValue(prefs),
        universalImportNotifierProvider.overrideWith(
          (ref) => UniversalImportNotifier(
            ref,
            garminDeviceDetector: GarminDeviceDetector(
              volumeRoots: () => const [],
              mtpSource: source,
            ),
            garminMtpStager: GarminMtpStager(
              source: source,
              tempRoot: () async => tmp,
            ),
            garminDownloadHistory: history,
          ),
        ),
      ],
    );
    addTearDown(container.dispose);
    return container.read(universalImportNotifierProvider.notifier);
  }

  FakeGarminMtpSource watchWith(Map<String, Uint8List> files) {
    final watch = fakeGarminWatch();
    return FakeGarminMtpSource(
      devices: [watch],
      filesByDevice: {watch.id: files},
    );
  }

  test('reads only the activities after the marker', () async {
    final source = watchWith({
      october: diveBytes,
      november: diveBytes,
      december: diveBytes,
    });
    final history = FakeGarminDownloadHistory(markerAtNovember);
    final notifier = await notifierFor(source, history);

    await notifier.importFromGarminDevice(
      const GarminImportRequest(computerId: 'dc-1'),
    );

    expect(source.readObjectIds.map((id) => id.split('/').last), [december]);
    expect(notifier.state.files.single.name, december);
    expect(history.lookups.single.computerId, 'dc-1');
    expect(history.lookups.single.serialNumber, '3456789012');

    // Saved only when the import completes, not now.
    expect(history.saves, isEmpty);
    final pending = notifier.state.garminPendingMarker!;
    expect(pending.marker, const GarminActivityMarker(name: december));
    expect(pending.computerId, 'dc-1');
    expect(pending.paths, {notifier.state.files.single.path});
  });

  test('looks the marker up by the decimal unit ID, not the MTP hex', () async {
    // Windows reports unit ID 3339091223 as 0000c7067d17. Looked up as hex,
    // the saved Garmin was never found, so every download read everything.
    final watch = fakeGarminWatch(serial: '0000c7067d17');
    final source = FakeGarminMtpSource(
      devices: [watch],
      filesByDevice: {
        watch.id: {november: diveBytes, december: diveBytes},
      },
    );
    final history = FakeGarminDownloadHistory(markerAtNovember);
    final notifier = await notifierFor(source, history);

    await notifier.importFromGarminDevice();

    expect(history.lookups.single.serialNumber, '3339091223');
    expect(notifier.state.files.single.name, december);
    expect(notifier.state.garminPendingMarker?.watchSerial, '3339091223');
  });

  test('nothing new says so, and Download all reads everything', () async {
    final source = watchWith({october: diveBytes, november: diveBytes});
    final history = FakeGarminDownloadHistory(markerAtNovember);
    final notifier = await notifierFor(source, history);

    await notifier.importFromGarminDevice(
      const GarminImportRequest(computerId: 'dc-1'),
    );

    expect(notifier.state.garminNothingNew, isTrue);
    expect(notifier.state.error, isNull);
    expect(notifier.state.files, isEmpty);
    expect(notifier.state.isLoading, isFalse);
    expect(source.readObjectIds, isEmpty);

    await notifier.importAllFromGarminDevice();

    expect(notifier.state.garminNothingNew, isFalse);
    expect(notifier.state.files.map((f) => f.name), [october, november]);
    // The request kept its computer, and read past the marker.
    expect(history.lookups, hasLength(1));
    expect(notifier.state.garminPendingMarker?.computerId, 'dc-1');
  });

  test('new activities that are not dives move the marker at once', () async {
    final source = watchWith({
      november: diveBytes,
      december: Uint8List.fromList([0, 1, 2]),
    });
    final history = FakeGarminDownloadHistory(markerAtNovember);
    final notifier = await notifierFor(source, history);

    await notifier.importFromGarminDevice();

    expect(notifier.state.garminNothingNew, isTrue);
    expect(
      history.saves.single.marker,
      const GarminActivityMarker(name: december),
    );
  });

  test('without a marker every activity is read', () async {
    final source = watchWith({october: diveBytes, november: diveBytes});
    final notifier = await notifierFor(source, FakeGarminDownloadHistory());

    await notifier.importFromGarminDevice();

    expect(notifier.state.files, hasLength(2));
    expect(
      notifier.state.garminPendingMarker?.marker,
      const GarminActivityMarker(name: november),
    );
  });

  test('a watch with no dives and no marker is still an error', () async {
    final source = watchWith({
      october: Uint8List.fromList([0, 1, 2]),
    });
    final notifier = await notifierFor(source, FakeGarminDownloadHistory());

    await notifier.importFromGarminDevice();

    expect(notifier.state.garminNothingNew, isFalse);
    expect(notifier.state.error, isNotNull);
  });
}
