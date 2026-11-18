import 'dart:convert';
import 'dart:io';

import 'package:drift/drift.dart' show Value;
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/legacy.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as p;
import 'package:submersion/core/constants/enums.dart';
import 'package:submersion/core/database/database.dart' show SpeciesCompanion;
import 'package:submersion/core/services/database_service.dart';
import 'package:submersion/features/dive_import/data/services/uddf_entity_importer.dart';
import 'package:submersion/features/dive_log/data/repositories/dive_repository_impl.dart';
import 'package:submersion/features/dive_log/domain/entities/dive.dart';
import 'package:submersion/features/divers/presentation/providers/diver_providers.dart';
import 'package:submersion/features/import_wizard/data/adapters/universal_adapter.dart';
import 'package:submersion/features/marine_life/data/repositories/species_repository.dart';
import 'package:submersion/features/settings/presentation/providers/export_providers.dart';
import 'package:submersion/features/settings/presentation/providers/settings_providers.dart';
import 'package:submersion/features/universal_import/data/parsers/uddf_import_parser.dart';
import 'package:xml/xml.dart';

import '../../../../helpers/mock_channels.dart';
import '../../../../helpers/mock_file_picker_platform.dart';
import '../../../../helpers/mock_providers.dart';
import '../../../../helpers/test_database.dart';
import '../../../../core/services/export/uddf/uddf_observations_round_trip_test.dart'
    show buildRepositories;
import 'export_uddf_profiles_test.dart' show createDiver;

/// A bundled species row, as the seeded catalogue holds it.
Future<void> _insertBundled(String id, String name) async {
  final db = DatabaseService.instance.database;
  await db
      .into(db.species)
      .insert(
        SpeciesCompanion.insert(
          id: id,
          commonName: name,
          category: SpeciesCategory.fish.name,
          isBuiltIn: const Value(true),
        ),
      );
}

/// Issue #4578: the full UDDF backup wrote all of the bundled species. Both
/// notifier paths now declare every custom species and only the bundled ones
/// the exported dives' sightings name.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late Directory workDir;
  late FilePickerPlatform originalPicker;
  late MockFilePickerPlatform picker;
  late String customId;

  setUpAll(() async {
    workDir = await Directory.systemTemp.createTemp('export_uddf_species_');
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(
          const MethodChannel('plugins.flutter.io/path_provider'),
          (call) async => switch (call.method) {
            'getApplicationDocumentsDirectory' ||
            'getTemporaryDirectory' => workDir.path,
            _ => null,
          },
        );
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(
          const MethodChannel('dev.fluttercommunity.plus/share'),
          (call) async => null,
        );
  });
  tearDownAll(clearPathAndShareChannelMocks);

  tearDownAll(() async {
    if (await workDir.exists()) await workDir.delete(recursive: true);
  });

  setUp(() async {
    await setUpTestDatabase();
    originalPicker = FilePickerPlatform.instance;
    picker = MockFilePickerPlatform()
      ..saveFileResult = Uri.file(p.join(workDir.path, 'backup.uddf'));
    FilePickerPlatform.instance = picker;

    await createDiver();
    await DiveRepository().createDive(
      Dive(
        id: 'dive-a',
        diverId: 'me',
        diveNumber: 1,
        dateTime: DateTime.utc(2026, 3, 1, 9),
      ),
    );
    await _insertBundled('bundled-seen', 'Seen Wrasse');
    await _insertBundled('bundled-unseen', 'Unseen Wrasse');
    final species = SpeciesRepository();
    customId = (await species.createSpecies(
      commonName: 'My Own Slug',
      category: SpeciesCategory.invertebrate,
    )).id;
    await species.addSighting(diveId: 'dive-a', speciesId: 'bundled-seen');
  });

  tearDown(() async {
    FilePickerPlatform.instance = originalPicker;
    await tearDownTestDatabase();
  });

  Future<String> exportedXml({required bool save}) async {
    final container = ProviderContainer(
      overrides: [
        currentDiverIdProvider.overrideWith(
          (ref) => MockCurrentDiverIdNotifier()..state = 'me',
        ),
        settingsProvider.overrideWith((ref) => _FixedSettings()),
      ],
    );
    addTearDown(container.dispose);
    final notifier = container.read(exportNotifierProvider.notifier);
    await (save ? notifier.saveUddfToFile() : notifier.exportDivesToUddf());

    final state = container.read(exportNotifierProvider);
    expect(state.status, ExportStatus.success, reason: state.message);
    return save
        ? utf8.decode(picker.lastSavedBytes!)
        : File(state.filePath!).readAsString();
  }

  for (final save in [false, true]) {
    final path = save ? 'saving' : 'sharing';

    test('$path the backup declares custom and sighted species only', () async {
      final doc = XmlDocument.parse(await exportedXml(save: save));

      final declared = {
        for (final spec in doc.findAllElements('spec')) spec.getAttribute('id'),
      };
      expect(declared, {'species_bundled-seen', 'species_$customId'});
      expect(
        doc.findAllElements('sighting').single.getAttribute('speciesref'),
        'species_bundled-seen',
      );
    });

    test('$path then restoring brings back the custom species no dive '
        'sighted', () async {
      final xml = await exportedXml(save: save);
      // A restore onto a new device, the way the import wizard runs it:
      // parse, rebuild the importer's input from the payload, import.
      await tearDownTestDatabase();
      await setUpTestDatabase();
      await createDiver();
      final payload = await UddfImportParser().parse(
        Uint8List.fromList(utf8.encode(xml)),
      );
      final data = UniversalAdapter.payloadToUddfResult(payload);
      await UddfEntityImporter().import(
        data: data,
        selections: UddfImportSelections.selectAll(data),
        repositories: buildRepositories(),
        diverId: 'me',
      );

      final species = SpeciesRepository();
      final slug = await species.findSpeciesByCommonName('My Own Slug');
      expect(slug.single.category, SpeciesCategory.invertebrate);
      final dive = (await DiveRepository().getAllDives(diverId: 'me')).single;
      expect(
        (await species.getSightingsForDive(dive.id)).single.speciesName,
        'Seen Wrasse',
      );
    });
  }
}

class _FixedSettings extends StateNotifier<AppSettings>
    implements SettingsNotifier {
  _FixedSettings() : super(const AppSettings());

  @override
  dynamic noSuchMethod(Invocation invocation) => null;
}
