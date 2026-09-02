// Issue #1092: proves the surfacing-pressure rule is actually reached on a
// real file import, and that the diver's setting governs it. The rule itself
// is unit-tested in test/core/profile/surfacing_pressure_test.dart.

import 'dart:io';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as p;
import 'package:plugin_platform_interface/plugin_platform_interface.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:submersion/features/settings/presentation/providers/settings_providers.dart';
import 'package:submersion/features/universal_import/data/models/import_enums.dart';
import 'package:submersion/features/universal_import/presentation/providers/universal_import_providers.dart';

import '../../../../helpers/mock_file_picker_platform.dart';
import '../../../../helpers/mock_providers.dart';
import '../../../../helpers/test_database.dart';

/// A UDDF export whose end pressure was taken from the last sample: the diver
/// surfaced at 1.2 m with 41 bar of oxygen, and the recording ran on for two
/// more minutes while the cylinder bled to 4 bar through the constant mass
/// flow orifice. UDDF pressures are Pascal.
const _bleedingOxygenUddf = '''<uddf version="3.2.1">
  <profiledata>
    <repetitiongroup id="rg">
      <dive id="D1">
        <informationbeforedive><datetime>2026-01-15T10:00:00</datetime></informationbeforedive>
        <informationafterdive><greatestdepth>51.0</greatestdepth><diveduration>4140.0</diveduration></informationafterdive>
        <tankdata>
          <tankpressurebegin>20000000.0</tankpressurebegin>
          <tankpressureend>400000.0</tankpressureend>
        </tankdata>
        <samples>
          <waypoint><divetime>600.0</divetime><depth>51.0</depth><tankpressure>12000000.0</tankpressure></waypoint>
          <waypoint><divetime>3970.0</divetime><depth>1.2</depth><tankpressure>4100000.0</tankpressure></waypoint>
          <waypoint><divetime>4140.0</divetime><depth>0.0</depth><tankpressure>400000.0</tankpressure></waypoint>
        </samples>
      </dive>
    </repetitiongroup>
  </profiledata>
</uddf>''';

class _FakeFilePicker extends FilePickerPlatform
    with MockPlatformInterfaceMixin {
  List<String>? nextPickPaths;

  @override
  Future<PlatformFile?> pickFile({
    String? dialogTitle,
    String? initialDirectory,
    FileType type = FileType.any,
    List<String>? allowedExtensions,
    Function(FilePickerStatus)? onFileLoading,
    int compressionQuality = 0,
    AndroidOptions androidOptions = const AndroidOptions(),
    WindowsOptions windowsOptions = const WindowsOptions(),
    LinuxOptions linuxOptions = const LinuxOptions(),
    WebOptions webOptions = const WebOptions(),
  }) async {
    final paths = nextPickPaths;
    if (paths == null || paths.isEmpty) return null;
    return FakePlatformFile(paths.first, name: p.basename(paths.first));
  }

  @override
  Future<List<PlatformFile>> pickFiles({
    String? dialogTitle,
    String? initialDirectory,
    FileType type = FileType.any,
    List<String>? allowedExtensions,
    Function(FilePickerStatus)? onFileLoading,
    int compressionQuality = 0,
    AndroidOptions androidOptions = const AndroidOptions(),
    WindowsOptions windowsOptions = const WindowsOptions(),
    LinuxOptions linuxOptions = const LinuxOptions(),
    WebOptions webOptions = const WebOptions(),
  }) async {
    final paths = nextPickPaths;
    if (paths == null) return const [];
    return [
      for (final path in paths) FakePlatformFile(path, name: p.basename(path)),
    ];
  }
}

Future<void> _waitForAsyncWork(UniversalImportNotifier notifier) async {
  for (var i = 0; i < 200; i++) {
    await Future<void>.delayed(Duration.zero);
    if (!notifier.state.isLoading) break;
  }
}

void main() {
  late ProviderContainer container;
  late UniversalImportNotifier notifier;
  late _FakeFilePicker picker;
  late FilePickerPlatform originalPicker;
  late Directory tmp;

  Future<void> start({required bool trimAtSurfacing}) async {
    await setUpTestDatabase();
    SharedPreferences.setMockInitialValues({});
    final prefs = await SharedPreferences.getInstance();
    container = ProviderContainer(
      overrides: [
        sharedPreferencesProvider.overrideWithValue(prefs),
        settingsProvider.overrideWith(
          (ref) => MockSettingsNotifier(
            AppSettings(trimTankPressureAtSurfacing: trimAtSurfacing),
          ),
        ),
      ],
    );
    notifier = container.read(universalImportNotifierProvider.notifier);
    originalPicker = FilePickerPlatform.instance;
    picker = _FakeFilePicker();
    FilePickerPlatform.instance = picker;
    tmp = await Directory.systemTemp.createTemp('surfacing_import_test');
  }

  tearDown(() async {
    FilePickerPlatform.instance = originalPicker;
    container.dispose();
    await tearDownTestDatabase();
    await tmp.delete(recursive: true);
  });

  Future<double?> importedEndPressure({required bool trimAtSurfacing}) async {
    await start(trimAtSurfacing: trimAtSurfacing);
    final file = File(p.join(tmp.path, 'dive.uddf'));
    await file.writeAsString(_bleedingOxygenUddf);
    picker.nextPickPaths = [file.path];

    await notifier.pickFiles();
    await notifier.confirmSource();
    await _waitForAsyncWork(notifier);

    final dive = notifier.state.payload!
        .entitiesOf(ImportEntityType.dives)
        .single;
    final tanks = dive['tanks'] as List<Map<String, dynamic>>;
    return (tanks.single['endPressure'] as num?)?.toDouble();
  }

  test('a file import stores the end pressure at surfacing', () async {
    expect(await importedEndPressure(trimAtSurfacing: true), 41.0);
  });

  test(
    'a file import keeps the source end pressure when the diver opted out',
    () async {
      expect(await importedEndPressure(trimAtSurfacing: false), 4.0);
    },
  );
}
