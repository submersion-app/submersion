import 'dart:convert';
import 'dart:io';

import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/legacy.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/features/dive_log/data/repositories/dive_repository_impl.dart';
import 'package:submersion/features/dive_log/data/repositories/tank_pressure_repository.dart';
import 'package:submersion/features/dive_log/domain/entities/dive.dart';
import 'package:submersion/features/divers/data/repositories/diver_repository.dart';
import 'package:submersion/features/divers/domain/entities/diver.dart';
import 'package:submersion/features/divers/presentation/providers/diver_providers.dart';
import 'package:submersion/features/settings/presentation/providers/export_providers.dart';
import 'package:submersion/features/settings/presentation/providers/settings_providers.dart';
import 'package:xml/xml.dart';

import '../../../../helpers/mock_file_picker_platform.dart';
import '../../../../helpers/mock_providers.dart';
import '../../../../helpers/test_database.dart';
import '../../../../helpers/uddf_restore.dart';

/// Issue #1874: the full UDDF backup reads its dives through `getAllDives`,
/// which never hydrates `dive.profile`, so the recorded samples and the tank
/// pressures written inside them never reached the file. These tests drive
/// both notifier paths against a real database and read the document the
/// real export service produced.
Future<void> createDiver() async {
  final now = DateTime.utc(2026, 3, 1);
  await DiverRepository().createDiver(
    Diver(
      id: 'me',
      name: 'Me',
      isDefault: true,
      createdAt: now,
      updatedAt: now,
    ),
  );
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late Directory workDir;
  late FilePickerPlatform originalPicker;
  late MockFilePickerPlatform picker;

  setUpAll(() async {
    workDir = await Directory.systemTemp.createTemp('export_uddf_profiles_');
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(
          const MethodChannel('plugins.flutter.io/path_provider'),
          (call) async => call.method == 'getApplicationDocumentsDirectory'
              ? workDir.path
              : null,
        );
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(
          const MethodChannel('dev.fluttercommunity.plus/share'),
          (call) async => null,
        );
  });

  tearDownAll(() async {
    if (await workDir.exists()) await workDir.delete(recursive: true);
  });

  setUp(() async {
    await setUpTestDatabase();
    originalPicker = FilePickerPlatform.instance;
    // A destination, or the save path reports the dialog as cancelled.
    picker = MockFilePickerPlatform()
      ..saveFileResult = Uri.file('${workDir.path}/backup.uddf');
    FilePickerPlatform.instance = picker;

    await createDiver();
    await DiveRepository().createDive(
      Dive(
        id: 'dive-a',
        diverId: 'me',
        diveNumber: 1,
        dateTime: DateTime.utc(2026, 3, 1, 9),
        bottomTime: const Duration(minutes: 2),
        maxDepth: 12.0,
        tanks: const [
          DiveTank(
            id: 'tank-a',
            volume: 11.1,
            startPressure: 200,
            endPressure: 160,
            gasMix: GasMix(o2: 32),
          ),
        ],
        profile: const [
          DiveProfilePoint(timestamp: 10, depth: 4.5, temperature: 21.0),
          DiveProfilePoint(timestamp: 60, depth: 12.0, temperature: 20.0),
          DiveProfilePoint(timestamp: 120, depth: 6.0, temperature: 20.5),
        ],
      ),
    );
    await TankPressureRepository().insertTankPressures('dive-a', {
      'tank-a': [
        (timestamp: 10, pressure: 200.0),
        (timestamp: 60, pressure: 180.0),
        (timestamp: 120, pressure: 160.0),
      ],
    });
  });

  tearDown(() async {
    FilePickerPlatform.instance = originalPicker;
    await tearDownTestDatabase();
  });

  ProviderContainer make() {
    final container = ProviderContainer(
      overrides: [
        currentDiverIdProvider.overrideWith(
          (ref) => MockCurrentDiverIdNotifier()..state = 'me',
        ),
        settingsProvider.overrideWith((ref) => _FixedSettings()),
      ],
    );
    addTearDown(container.dispose);
    return container;
  }

  /// Runs one notifier path and returns the document it wrote.
  Future<String> exportedXml({required bool save}) async {
    final container = make();
    final notifier = container.read(exportNotifierProvider.notifier);
    await (save ? notifier.saveUddfToFile() : notifier.exportDivesToUddf());

    final state = container.read(exportNotifierProvider);
    expect(state.status, ExportStatus.success, reason: state.message);
    return save
        ? utf8.decode(picker.lastSavedBytes!)
        : File(state.filePath!).readAsString();
  }

  /// The only dive in the document one notifier path wrote.
  Future<XmlElement> exportedDive({required bool save}) async =>
      XmlDocument.parse(
        await exportedXml(save: save),
      ).findAllElements('dive').single;

  for (final save in [false, true]) {
    final path = save ? 'saving' : 'sharing';

    test('$path the backup writes every recorded sample', () async {
      final dive = await exportedDive(save: save);

      final samples = [
        for (final w in dive.findAllElements('waypoint'))
          (
            w.getElement('divetime')!.innerText,
            double.parse(w.getElement('depth')!.innerText),
          ),
      ];
      expect(
        samples,
        containsAllInOrder([('10', 4.5), ('60', 12.0), ('120', 6.0)]),
      );
    });

    test('$path the backup writes the tank pressures at each sample', () async {
      final dive = await exportedDive(save: save);

      final pressures = <String, double>{
        for (final w in dive.findAllElements('waypoint'))
          for (final p in w.findElements('tankpressure'))
            if (p.getAttribute('ref') == 'tank_tank-a')
              w.getElement('divetime')!.innerText: double.parse(p.innerText),
      };
      // UDDF stores pressure in pascals: 1 bar is 100000 Pa.
      expect(pressures, {'10': 2.0e7, '60': 1.8e7, '120': 1.6e7});
    });

    test('$path then restoring brings back the profile and tank '
        'pressures', () async {
      final xml = await exportedXml(save: save);
      // A restore onto a new device: a clean database, then the import.
      await tearDownTestDatabase();
      await setUpTestDatabase();
      await createDiver();
      await restoreUddfDives(xml, diverId: 'me');

      final repository = DiveRepository();
      final listed = (await repository.getAllDives(diverId: 'me')).single;
      final restored = (await repository.getDiveById(listed.id))!;
      expect(
        restored.profile.map((p) => (p.timestamp, p.depth, p.temperature)),
        [(10, 4.5, 21.0), (60, 12.0, 20.0), (120, 6.0, 20.5)],
      );

      final tank = restored.tanks.single;
      expect(tank.gasMix.o2, 32);
      final pressures = await TankPressureRepository().getTankPressuresForDive(
        restored.id,
      );
      expect(pressures[tank.id]!.map((p) => (p.timestamp, p.pressure)), [
        (10, 200.0),
        (60, 180.0),
        (120, 160.0),
      ]);
    });
  }
}

class _FixedSettings extends StateNotifier<AppSettings>
    implements SettingsNotifier {
  _FixedSettings() : super(const AppSettings());

  @override
  dynamic noSuchMethod(Invocation invocation) => null;
}
