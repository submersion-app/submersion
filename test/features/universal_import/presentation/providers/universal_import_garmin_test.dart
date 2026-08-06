// Drives the notifier's Garmin-USB import path: detect the mounted device,
// keep only dive FITs (skipping non-dive/corrupt files), and hand them to the
// wizard's single/batch flow. Uses a real Garmin dive FIT fixture and a
// temporary directory tree standing in for the mounted volume.

import 'dart:io';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as p;
import 'package:shared_preferences/shared_preferences.dart';
import 'package:submersion/features/settings/presentation/providers/settings_providers.dart';
import 'package:submersion/features/universal_import/data/services/garmin_device_detector.dart';
import 'package:submersion/features/universal_import/presentation/providers/universal_import_providers.dart';

import '../../../../helpers/test_database.dart';

const _diveFixture = 'test/dives/005_oc-trimix-two-deco-gases.fit';

void main() {
  late ProviderContainer container;
  late Directory tmp;

  setUp(() async {
    await setUpTestDatabase();
    SharedPreferences.setMockInitialValues({});
    tmp = await Directory.systemTemp.createTemp('garmin_import_test');
  });

  tearDown(() async {
    container.dispose();
    await tearDownTestDatabase();
    await tmp.delete(recursive: true);
  });

  /// Build a notifier whose detector points at [volumeRoots].
  Future<UniversalImportNotifier> notifierFor(List<String> volumeRoots) async {
    final prefs = await SharedPreferences.getInstance();
    final detector = GarminDeviceDetector(
      volumeRoots: () => [for (final r in volumeRoots) Directory(r)],
    );
    container = ProviderContainer(
      overrides: [
        sharedPreferencesProvider.overrideWithValue(prefs),
        universalImportNotifierProvider.overrideWith(
          (ref) => UniversalImportNotifier(ref, garminDeviceDetector: detector),
        ),
      ],
    );
    return container.read(universalImportNotifierProvider.notifier);
  }

  /// Create `<tmp>/<volume>/GARMIN/Activity` and populate it. Copies the dive
  /// fixture [diveCopies] times and writes [corrupt] junk .fit files.
  Future<String> makeGarminVolume(
    String volume, {
    int diveCopies = 0,
    int corrupt = 0,
  }) async {
    final activity = Directory(p.join(tmp.path, volume, 'GARMIN', 'Activity'));
    await activity.create(recursive: true);
    final diveBytes = await File(_diveFixture).readAsBytes();
    for (var i = 0; i < diveCopies; i++) {
      await File(p.join(activity.path, 'dive_$i.fit')).writeAsBytes(diveBytes);
    }
    for (var i = 0; i < corrupt; i++) {
      await File(
        p.join(activity.path, 'run_$i.fit'),
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

  test('enters batch triage when several dives are present', () async {
    final vol = await makeGarminVolume('DESCENT', diveCopies: 2, corrupt: 1);
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

  test('reports an error when the device holds no dives', () async {
    final vol = await makeGarminVolume('DESCENT', corrupt: 2);
    final notifier = await notifierFor([vol]);

    await notifier.importFromGarminDevice();

    expect(notifier.state.files, isEmpty);
    expect(notifier.state.error, contains('No dives found'));
  });
}
