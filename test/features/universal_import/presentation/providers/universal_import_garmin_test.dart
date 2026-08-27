// Drives the notifier's Garmin-USB import path: detect the mounted device,
// keep only dive FITs (skipping non-dive/corrupt files), and hand them to the
// wizard's single/batch flow. A temporary directory tree stands in for the
// mounted volume, populated from a real Garmin dive FIT fixture, FIT files
// built in-test for valid non-dive activities, and junk bytes for corrupt
// ones -- the parser rejects the last two through different branches.

import 'dart:io';
import 'dart:typed_data';

import 'package:fit_tool/fit_tool.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as p;
import 'package:shared_preferences/shared_preferences.dart';
import 'package:submersion/features/settings/presentation/providers/settings_providers.dart';
import 'package:submersion/features/universal_import/data/services/garmin_device_detector.dart';
import 'package:submersion/features/universal_import/presentation/providers/universal_import_providers.dart';

import '../../../../helpers/test_database.dart';

const _diveFixture = 'test/dives/005_oc-trimix-two-deco-gases.fit';

/// A structurally valid FIT file for a non-dive activity (a run).
///
/// Two properties make this fixture do its job, and both are deliberate:
///
/// 1. It is not corrupt. It decodes cleanly and carries a [SessionMessage],
///    so the parser reaches its sport check instead of bailing on a decode
///    failure -- a different branch from the junk bytes written by `corrupt:`.
/// 2. It carries depth records even though a real run would not. The parser
///    rejects a FIT both for `sport != Sport.diving` and for having no usable
///    profile samples; without depth here the file would be dropped by the
///    latter, and these tests would still pass if the sport filter were
///    deleted. The depth samples make `sport` the only reason it is skipped,
///    which is what pins the filtering behaviour down.
Uint8List _runningFitBytes({int serialNumber = 99999}) {
  final start = DateTime.utc(2025, 6, 1, 7, 0, 0);
  final builder = FitFileBuilder(autoDefine: true, minStringSize: 50);

  builder.add(
    FileIdMessage()
      ..type = FileType.activity
      ..manufacturer = 1
      ..serialNumber = serialNumber
      ..timeCreated = start.millisecondsSinceEpoch,
  );

  for (var i = 0; i < 5; i++) {
    builder.add(
      RecordMessage()
        ..timestamp = start
            .add(Duration(seconds: i * 60))
            .millisecondsSinceEpoch
        ..depth = 5.0 + i
        ..heartRate = 140 + i,
    );
  }

  builder.add(
    SessionMessage()
      ..sport = Sport.running
      ..startTime = start.millisecondsSinceEpoch
      ..timestamp = start
          .add(const Duration(minutes: 30))
          .millisecondsSinceEpoch
      ..totalElapsedTime = 1800
      ..totalTimerTime = 1800,
  );

  return builder.build().toBytes();
}

void main() {
  late Directory tmp;

  setUp(() async {
    await setUpTestDatabase();
    SharedPreferences.setMockInitialValues({});
    tmp = await Directory.systemTemp.createTemp('garmin_import_test');
  });

  tearDown(() async {
    await tearDownTestDatabase();
    await tmp.delete(recursive: true);
  });

  /// Build a notifier whose detector points at [volumeRoots]. The container is
  /// disposed via [addTearDown] so a throw here cannot leave the enclosing
  /// tearDown disposing an uninitialized field.
  Future<UniversalImportNotifier> notifierFor(List<String> volumeRoots) async {
    final prefs = await SharedPreferences.getInstance();
    final detector = GarminDeviceDetector(
      volumeRoots: () => [for (final r in volumeRoots) Directory(r)],
    );
    final container = ProviderContainer(
      overrides: [
        sharedPreferencesProvider.overrideWithValue(prefs),
        universalImportNotifierProvider.overrideWith(
          (ref) => UniversalImportNotifier(ref, garminDeviceDetector: detector),
        ),
      ],
    );
    addTearDown(container.dispose);
    return container.read(universalImportNotifierProvider.notifier);
  }

  /// Create `<tmp>/<volume>/GARMIN/Activity` and populate it: the dive fixture
  /// [diveCopies] times, [nonDive] valid running activities, and [corrupt]
  /// junk .fit files.
  Future<String> makeGarminVolume(
    String volume, {
    int diveCopies = 0,
    int nonDive = 0,
    int corrupt = 0,
  }) async {
    final activity = Directory(p.join(tmp.path, volume, 'GARMIN', 'Activity'));
    await activity.create(recursive: true);
    final diveBytes = await File(_diveFixture).readAsBytes();
    for (var i = 0; i < diveCopies; i++) {
      await File(p.join(activity.path, 'dive_$i.fit')).writeAsBytes(diveBytes);
    }
    for (var i = 0; i < nonDive; i++) {
      await File(
        p.join(activity.path, 'run_$i.fit'),
      ).writeAsBytes(_runningFitBytes(serialNumber: 99999 + i));
    }
    for (var i = 0; i < corrupt; i++) {
      await File(
        p.join(activity.path, 'corrupt_$i.fit'),
      ).writeAsBytes([0, 1, 2, 3, 4]);
    }
    return p.join(tmp.path, volume);
  }

  test('imports a single dive, skipping a corrupt FIT', () async {
    final vol = await makeGarminVolume('DESCENT', diveCopies: 1, corrupt: 1);
    final notifier = await notifierFor([vol]);

    await notifier.importFromGarminDevice();

    expect(notifier.state.error, isNull);
    expect(notifier.state.files, hasLength(1));
    expect(notifier.state.isBatch, isFalse);
    expect(notifier.state.currentStep, ImportWizardStep.sourceConfirmation);
    expect(notifier.state.fileName, 'dive_0.fit');
    expect(notifier.state.wasLoadedExternally, isTrue);
    expect(notifier.state.isLoading, isFalse);
  });

  test('the non-dive fixture is a valid FIT, not a corrupt one', () {
    // Guards the tests below: if this ever stopped decoding it would exercise
    // the corrupt-file branch and silently stop covering the sport filter.
    final fitFile = FitFile.fromBytes(_runningFitBytes());
    final session = fitFile.records
        .map((r) => r.message)
        .whereType<SessionMessage>()
        .first;
    expect(session.sport, Sport.running);
  });

  test('skips a valid non-dive activity, importing only the dive', () async {
    final vol = await makeGarminVolume('DESCENT', diveCopies: 1, nonDive: 1);
    final notifier = await notifierFor([vol]);

    await notifier.importFromGarminDevice();

    expect(notifier.state.error, isNull);
    expect(notifier.state.files, hasLength(1));
    expect(notifier.state.isBatch, isFalse);
    expect(notifier.state.fileName, 'dive_0.fit');
  });

  test(
    'reports an error when the device holds only non-dive activities',
    () async {
      final vol = await makeGarminVolume('DESCENT', nonDive: 2);
      final notifier = await notifierFor([vol]);

      await notifier.importFromGarminDevice();

      expect(notifier.state.files, isEmpty);
      expect(notifier.state.isLoading, isFalse);
      expect(notifier.state.error, contains('No dives found'));
    },
  );

  test('enters batch triage when several dives are present', () async {
    final vol = await makeGarminVolume(
      'DESCENT',
      diveCopies: 2,
      nonDive: 1,
      corrupt: 1,
    );
    final notifier = await notifierFor([vol]);

    await notifier.importFromGarminDevice();

    expect(notifier.state.error, isNull);
    expect(notifier.state.isBatch, isTrue);
    expect(notifier.state.files, hasLength(2));
    expect(notifier.state.currentStep, ImportWizardStep.sourceConfirmation);
  });

  test('reports an error when no Garmin device is connected', () async {
    final notifier = await notifierFor(const []);

    await notifier.importFromGarminDevice();

    expect(notifier.state.files, isEmpty);
    expect(notifier.state.isLoading, isFalse);
    expect(notifier.state.error, contains('No connected Garmin device'));
  });

  test('reports an error when the device holds only corrupt FITs', () async {
    final vol = await makeGarminVolume('DESCENT', corrupt: 2);
    final notifier = await notifierFor([vol]);

    await notifier.importFromGarminDevice();

    expect(notifier.state.files, isEmpty);
    expect(notifier.state.error, contains('No dives found'));
  });
}
