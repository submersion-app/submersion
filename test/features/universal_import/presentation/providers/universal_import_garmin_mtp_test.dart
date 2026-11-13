// Drives the notifier's Garmin import for a watch that connects over MTP
// (issue #4223): the files are copied off a fake MTP source into a staging
// folder, which then goes through the same dive-FIT filter and batch flow as
// a watch mounted as a drive, and is deleted with the wizard's other temp
// folders.

import 'dart:io';
import 'dart:ui' show Locale;

import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:submersion/features/settings/presentation/providers/settings_providers.dart';
import 'package:submersion/features/universal_import/data/services/garmin_device_detector.dart';
import 'package:submersion/features/universal_import/data/services/garmin_mtp_stager.dart';
import 'package:submersion/features/universal_import/data/models/garmin_import_progress.dart';
import 'package:submersion/features/universal_import/presentation/providers/universal_import_providers.dart';
import 'package:submersion/l10n/arb/app_localizations.dart';

import '../../../../helpers/test_database.dart';
import '../../data/services/fake_garmin_mtp_source.dart';

const _diveFixture = 'test/dives/005_oc-trimix-two-deco-gases.fit';

final _en = lookupAppLocalizations(const Locale('en'));

void main() {
  late Directory tmp;
  late Uint8List diveBytes;

  setUp(() async {
    await setUpTestDatabase();
    SharedPreferences.setMockInitialValues({});
    tmp = await Directory.systemTemp.createTemp('garmin_mtp_import_test');
    diveBytes = await File(_diveFixture).readAsBytes();
  });

  tearDown(() async {
    await tearDownTestDatabase();
    await tmp.delete(recursive: true);
  });

  Future<({UniversalImportNotifier notifier, List<_Snapshot?> progress})>
  notifierFor(FakeGarminMtpSource source) async {
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
          ),
        ),
      ],
    );
    addTearDown(container.dispose);
    final progress = <_Snapshot?>[];
    container.listen(universalImportNotifierProvider, (_, next) {
      final p = next.garminProgress;
      final entry = p == null
          ? null
          : (p.phase, p.current, p.total, p.deviceName);
      if (progress.isEmpty || progress.last != entry) {
        progress.add(entry);
      }
    });
    return (
      notifier: container.read(universalImportNotifierProvider.notifier),
      progress: progress,
    );
  }

  test(
    'imports the dives from an MTP watch through a staging folder',
    () async {
      final watch = fakeGarminWatch();
      final (:notifier, progress: _) = await notifierFor(
        FakeGarminMtpSource(
          devices: [watch],
          filesByDevice: {
            watch.id: {
              'dive_a.fit': diveBytes,
              'dive_b.fit': diveBytes,
              'corrupt.fit': Uint8List.fromList([0, 1, 2]),
              'settings.txt': Uint8List.fromList([1]),
            },
          },
        ),
      );

      await notifier.importFromGarminDevice();

      expect(notifier.state.error, isNull);
      expect(notifier.state.isBatch, isTrue);
      expect(
        notifier.state.files.map((f) => f.name),
        unorderedEquals(['dive_a.fit', 'dive_b.fit']),
      );
      expect(notifier.state.currentStep, ImportWizardStep.sourceConfirmation);
      // Started inside the wizard, so its next opening resets as usual.
      expect(notifier.state.wasLoadedExternally, isFalse);
      expect(notifier.state.isLoading, isFalse);

      // The files live in one staging folder the wizard now owns.
      expect(notifier.state.zipTempDirPaths, hasLength(1));
      final staging = notifier.state.zipTempDirPaths.single;
      for (final file in notifier.state.files) {
        expect(File(file.path!).parent.path, staging);
      }
    },
  );

  test('reports each phase in order, then clears it', () async {
    final watch = fakeGarminWatch();
    final (:notifier, :progress) = await notifierFor(
      FakeGarminMtpSource(
        devices: [watch],
        filesByDevice: {
          watch.id: {'a.fit': diveBytes, 'b.fit': diveBytes},
        },
      ),
    );

    await notifier.importFromGarminDevice();

    const look = GarminImportPhase.lookingForWatch;
    const scan = GarminImportPhase.scanning;
    const copy = GarminImportPhase.copying;
    const check = GarminImportPhase.checking;
    const name = 'Garmin Descent G2';
    expect(
      progress,
      containsAllInOrder([
        (look, 0, 0, null),
        (scan, 0, 0, name),
        (copy, 0, 2, name),
        (copy, 1, 2, name),
        (copy, 2, 2, name),
        (check, 0, 2, name),
        (check, 1, 2, name),
        (check, 2, 2, name),
      ]),
    );
    expect(progress.last, isNull);
    expect(notifier.state.garminProgress, isNull);
  });

  test('does not add "Garmin" to a name that already has it', () async {
    final watch = fakeGarminWatch(name: 'Garmin Descent Mk3');
    final (:notifier, :progress) = await notifierFor(
      FakeGarminMtpSource(
        devices: [watch],
        filesByDevice: {
          watch.id: {'a.fit': diveBytes},
        },
      ),
    );

    await notifier.importFromGarminDevice();

    expect(progress.whereType<_Snapshot>().map((e) => e.$4).toSet(), {
      null,
      'Garmin Descent Mk3',
    });
  });

  test(
    'the next wizard opening reads the watch again, not the last import',
    () async {
      final watch = fakeGarminWatch();
      final devices = [watch];
      final (:notifier, progress: _) = await notifierFor(
        FakeGarminMtpSource(
          devices: devices,
          filesByDevice: {
            watch.id: {'a.fit': diveBytes},
          },
        ),
      );
      await notifier.importFromGarminDevice();
      final firstStaging = notifier.state.zipTempDirPaths.single;
      expect(notifier.state.files, hasLength(1));

      // The wizard keeps a preloaded import instead of resetting; a Garmin
      // import must not count as one, or the next opening skips the reset and
      // the read (as an unplugged watch "downloaded" its last dives).
      expect(notifier.state.wasLoadedExternally, isFalse);

      devices.clear(); // Unplugged.
      notifier.reset();
      await notifier.importFromGarminDevice();
      await notifier.pendingTempCleanup;

      expect(notifier.state.files, isEmpty);
      expect(notifier.state.error, _en.universalImport_error_garminNotFound);
      expect(Directory(firstStaging).existsSync(), isFalse);
    },
  );

  test('deletes the staging folder when the wizard resets', () async {
    final watch = fakeGarminWatch();
    final (:notifier, progress: _) = await notifierFor(
      FakeGarminMtpSource(
        devices: [watch],
        filesByDevice: {
          watch.id: {'a.fit': diveBytes},
        },
      ),
    );
    await notifier.importFromGarminDevice();
    final staging = notifier.state.zipTempDirPaths.single;
    expect(Directory(staging).existsSync(), isTrue);

    notifier.reset();
    await notifier.pendingTempCleanup;

    expect(Directory(staging).existsSync(), isFalse);
  });

  test('reports a watch with no dives', () async {
    final watch = fakeGarminWatch();
    final (:notifier, progress: _) = await notifierFor(
      FakeGarminMtpSource(
        devices: [watch],
        filesByDevice: {
          watch.id: {
            'corrupt.fit': Uint8List.fromList([0, 1, 2]),
          },
        },
      ),
    );

    await notifier.importFromGarminDevice();

    expect(notifier.state.files, isEmpty);
    expect(notifier.state.error, _en.universalImport_error_garminNoDives);
    expect(notifier.state.isLoading, isFalse);
  });

  test('reports a watch another app is holding', () async {
    final (:notifier, progress: _) = await notifierFor(
      FakeGarminMtpSource(
        devices: [fakeGarminWatch()],
        listFilesError: PlatformException(code: 'busy', message: 'in use'),
      ),
    );

    await notifier.importFromGarminDevice();

    expect(notifier.state.error, _en.universalImport_error_garminBusy);
    expect(notifier.state.isLoading, isFalse);
    expect(notifier.state.garminProgress, isNull);
  });

  test('reports a watch unplugged before its files were listed', () async {
    final (:notifier, progress: _) = await notifierFor(
      FakeGarminMtpSource(
        devices: [fakeGarminWatch()],
        listFilesError: PlatformException(code: 'notFound', message: 'gone'),
      ),
    );

    await notifier.importFromGarminDevice();

    expect(notifier.state.error, _en.universalImport_error_garminNotFound);
  });

  test('reports any other MTP failure with its message', () async {
    final (:notifier, progress: _) = await notifierFor(
      FakeGarminMtpSource(
        devices: [fakeGarminWatch()],
        listFilesError: PlatformException(
          code: 'ioError',
          message: 'Listing GARMIN/Activity failed (0x8007001F)',
        ),
      ),
    );

    await notifier.importFromGarminDevice();

    expect(
      notifier.state.error,
      _en.universalImport_error_garminReadFailed(
        'Listing GARMIN/Activity failed (0x8007001F)',
      ),
    );
  });
}

/// (phase, current, total, device name) of one progress update.
typedef _Snapshot = (GarminImportPhase, int, int, String?);
