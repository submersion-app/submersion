// Drives the notifier's Garmin import for a watch that connects over MTP
// (issue #4223): the files are copied off a fake MTP source into a staging
// folder, which then goes through the same dive-FIT filter and batch flow as
// a watch mounted as a drive, and is deleted with the wizard's other temp
// folders.

import 'dart:async';
import 'dart:io';
import 'dart:ui' show Locale;

import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:submersion/features/import_wizard/data/adapters/batch_source_files.dart';
import 'package:submersion/features/settings/presentation/providers/settings_providers.dart';
import 'package:submersion/features/universal_import/data/models/import_enums.dart';
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

  group('a download the wizard has moved on from', () {
    FakeGarminMtpSource twoDives() {
      final watch = fakeGarminWatch();
      return FakeGarminMtpSource(
        devices: [watch],
        filesByDevice: {
          watch.id: {'a.fit': diveBytes, 'b.fit': diveBytes},
        },
      );
    }

    test('is dropped by a reset, with its staging folder', () async {
      // Copying a watch takes a while. Backing out and reopening the
      // wizard must not have the old download land in the new session.
      final (:notifier, :progress) = await notifierFor(twoDives());

      final download = notifier.importFromGarminDevice();
      notifier.reset();
      await download;
      await notifier.pendingTempCleanup;

      expect(notifier.state.files, isEmpty);
      expect(notifier.state.error, isNull);
      expect(notifier.state.isLoading, isFalse);
      expect(notifier.state.garminProgress, isNull);
      expect(notifier.state.zipTempDirPaths, isEmpty);
      expect(tmp.listSync(), isEmpty);
      // Nothing it reported after the reset reached the page.
      expect(progress.whereType<_Snapshot>().length, lessThanOrEqualTo(1));
    });

    /// A watch whose files are named as Garmin names them, so the download
    /// has a marker to hold and says so just before it loads the dives.
    FakeGarminMtpSource datedDives(int count) {
      final watch = fakeGarminWatch();
      return FakeGarminMtpSource(
        devices: [watch],
        filesByDevice: {
          watch.id: {
            for (var day = 1; day <= count; day++)
              '2026-11-0$day-10-00-00.fit': diveBytes,
          },
        },
      );
    }

    /// Resets the wizard at the first state for which [when] holds, as the
    /// diver leaving and reopening it at that moment would.
    void resetWhen(
      UniversalImportNotifier notifier,
      bool Function(UniversalImportState state) when,
    ) {
      var armed = true;
      final remove = notifier.addListener((state) {
        if (armed && when(state)) {
          armed = false;
          scheduleMicrotask(notifier.reset);
        }
      }, fireImmediately: false);
      addTearDown(remove);
    }

    for (final count in [1, 2]) {
      test('does not load its $count dive file(s) after a reset that lands '
          'while they are being read', () async {
        // The dives are found and the download is still the current one
        // when it starts reading them. Reading takes a moment; a reset in
        // that moment must win.
        final (:notifier, progress: _) = await notifierFor(datedDives(count));
        resetWhen(notifier, (state) => state.garminPendingMarker != null);

        await notifier.importFromGarminDevice();
        await notifier.pendingTempCleanup;

        expect(notifier.state.files, isEmpty);
        expect(notifier.state.currentStep, ImportWizardStep.fileSelection);
        expect(notifier.state.isLoading, isFalse);
        expect(notifier.state.garminPendingMarker, isNull);
      });
    }

    test('removes its own staging folder when the reset could not', () async {
      // A reset deletes the staging folder while this download may still be
      // reading it, and on Windows a folder with a file open in it cannot be
      // deleted. The download removes it once it has stopped reading.
      final (:notifier, progress: _) = await notifierFor(twoDives());
      final delete = notifier.deleteTempDir;
      var failuresLeft = 1;
      notifier.deleteTempDir = (dir) async {
        if (failuresLeft-- > 0) {
          throw FileSystemException('The folder is in use', dir.path);
        }
        await delete(dir);
      };
      resetWhen(notifier, (state) => state.zipTempDirPaths.isNotEmpty);

      await notifier.importFromGarminDevice();
      await notifier.pendingTempCleanup;

      expect(notifier.state.files, isEmpty);
      expect(tmp.listSync(), isEmpty);
    });

    test('is replaced by a second download, not mixed with it', () async {
      final (:notifier, progress: _) = await notifierFor(twoDives());

      final first = notifier.importFromGarminDevice();
      final second = notifier.importFromGarminDevice();
      await Future.wait([first, second]);
      await notifier.pendingTempCleanup;

      expect(notifier.state.error, isNull);
      expect(notifier.state.files, hasLength(2));
      // One staging folder is left, and it is the one the files are in.
      final staging = notifier.state.zipTempDirPaths.single;
      expect(tmp.listSync().map((e) => e.path), [staging]);
      for (final file in notifier.state.files) {
        expect(File(file.path!).existsSync(), isTrue);
      }
    });
  });

  group('the original FIT file', () {
    // The importer stores a copy of each dive's source file, read through
    // these sources (issue #478). For a watch over MTP the staged copy is
    // the only place those bytes exist, so it must reach the importer whole.
    test('reaches the importer for every dive of a batch', () async {
      final watch = fakeGarminWatch();
      final (:notifier, progress: _) = await notifierFor(
        FakeGarminMtpSource(
          devices: [watch],
          filesByDevice: {
            watch.id: {'dive_a.fit': diveBytes, 'dive_b.fit': diveBytes},
          },
        ),
      );

      await notifier.importFromGarminDevice();

      final sources = batchSourceFiles(notifier.state.files);
      expect(sources, hasLength(2));
      for (final source in sources.values) {
        expect(source.format, ImportFormat.fit);
        expect(await source.readBytes(), diveBytes);
      }
      expect(
        sources.values.map((s) => s.fileName),
        unorderedEquals(['dive_a.fit', 'dive_b.fit']),
      );
    });

    test('reaches the importer for a single dive', () async {
      final watch = fakeGarminWatch();
      final (:notifier, progress: _) = await notifierFor(
        FakeGarminMtpSource(
          devices: [watch],
          filesByDevice: {
            watch.id: {'2026-11-01-10-22-31.fit': diveBytes},
          },
        ),
      );

      await notifier.importFromGarminDevice();

      // The single-file flow hands the importer these two.
      expect(notifier.state.fileName, '2026-11-01-10-22-31.fit');
      expect(notifier.state.fileBytes, diveBytes);
      expect(notifier.state.detectionResult?.format, ImportFormat.fit);
    });
  });

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
