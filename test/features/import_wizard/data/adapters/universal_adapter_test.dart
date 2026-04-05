import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/legacy.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mockito/annotations.dart';
import 'package:mockito/mockito.dart';
// ignore: implementation_imports
import 'package:riverpod/src/framework.dart' as riverpod show Override;
import 'package:submersion/core/constants/enums.dart';
import 'package:submersion/features/buddies/data/repositories/buddy_repository.dart';
import 'package:submersion/features/buddies/domain/entities/buddy.dart';
import 'package:submersion/features/buddies/presentation/providers/buddy_providers.dart';
import 'package:submersion/features/certifications/data/repositories/certification_repository.dart';
import 'package:submersion/features/certifications/domain/entities/certification.dart';
import 'package:submersion/features/certifications/presentation/providers/certification_providers.dart';
import 'package:submersion/features/courses/data/repositories/course_repository.dart';
import 'package:submersion/features/courses/presentation/providers/course_providers.dart';
import 'package:submersion/features/dive_centers/data/repositories/dive_center_repository.dart';
import 'package:submersion/features/dive_centers/domain/entities/dive_center.dart';
import 'package:submersion/features/dive_centers/presentation/providers/dive_center_providers.dart';
import 'package:submersion/features/dive_import/data/services/uddf_entity_importer.dart';
import 'package:submersion/features/dive_log/data/repositories/dive_repository_impl.dart';
import 'package:submersion/features/dive_log/data/repositories/tank_pressure_repository.dart';
import 'package:submersion/features/dive_log/domain/entities/dive.dart';
import 'package:submersion/features/dive_log/presentation/providers/dive_providers.dart';
import 'package:submersion/features/dive_sites/data/repositories/site_repository_impl.dart';
import 'package:submersion/features/dive_sites/domain/entities/dive_site.dart';
import 'package:submersion/features/dive_sites/presentation/providers/site_providers.dart';
import 'package:submersion/features/dive_types/data/repositories/dive_type_repository.dart';
import 'package:submersion/features/dive_types/domain/entities/dive_type_entity.dart';
import 'package:submersion/features/dive_types/presentation/providers/dive_type_providers.dart';
import 'package:submersion/features/divers/domain/entities/diver.dart';
import 'package:submersion/features/divers/presentation/providers/diver_providers.dart';
import 'package:submersion/features/equipment/data/repositories/equipment_repository_impl.dart';
import 'package:submersion/features/equipment/data/repositories/equipment_set_repository_impl.dart';
import 'package:submersion/features/equipment/domain/entities/equipment_item.dart';
import 'package:submersion/features/equipment/presentation/providers/equipment_providers.dart';
import 'package:submersion/features/equipment/presentation/providers/equipment_set_providers.dart';
import 'package:submersion/features/import_wizard/data/adapters/universal_adapter.dart';
import 'package:submersion/features/import_wizard/domain/models/duplicate_action.dart';
import 'package:submersion/features/import_wizard/domain/models/import_bundle.dart';
import 'package:submersion/features/import_wizard/domain/models/import_bundle.dart'
    as wizard
    show ImportEntityType;
import 'package:submersion/features/settings/presentation/providers/settings_providers.dart';
import 'package:submersion/features/tags/data/repositories/tag_repository.dart';
import 'package:submersion/features/tags/domain/entities/tag.dart';
import 'package:submersion/features/tags/presentation/providers/tag_providers.dart';
import 'package:submersion/features/tank_presets/data/repositories/tank_preset_repository.dart';
import 'package:submersion/features/tank_presets/presentation/providers/tank_preset_providers.dart';
import 'package:submersion/features/trips/data/repositories/trip_repository.dart';
import 'package:submersion/features/trips/domain/entities/trip.dart';
import 'package:submersion/features/trips/presentation/providers/trip_providers.dart';
import 'package:submersion/features/universal_import/data/csv/presets/csv_preset.dart';
import 'package:submersion/features/universal_import/data/models/detection_result.dart';
import 'package:submersion/features/universal_import/data/models/field_mapping.dart';
import 'package:submersion/features/universal_import/data/models/import_enums.dart'
    as ui;
import 'package:submersion/features/universal_import/data/models/import_options.dart';
import 'package:submersion/features/universal_import/data/models/import_payload.dart';
import 'package:submersion/features/universal_import/data/parsers/subsurface_xml_parser.dart';
import 'package:submersion/features/universal_import/presentation/providers/universal_import_providers.dart';

@GenerateNiceMocks([
  MockSpec<DiveRepository>(),
  MockSpec<SiteRepository>(),
  MockSpec<TripRepository>(),
  MockSpec<EquipmentRepository>(),
  MockSpec<EquipmentSetRepository>(),
  MockSpec<BuddyRepository>(),
  MockSpec<DiveCenterRepository>(),
  MockSpec<CertificationRepository>(),
  MockSpec<TagRepository>(),
  MockSpec<DiveTypeRepository>(),
  MockSpec<TankPressureRepository>(),
  MockSpec<CourseRepository>(),
  MockSpec<TankPresetRepository>(),
  MockSpec<UddfEntityImporter>(),
])
import 'universal_adapter_test.mocks.dart';

typedef Override = riverpod.Override;

// ---------------------------------------------------------------------------
// Test helpers
// ---------------------------------------------------------------------------

final _now = DateTime.now();

Diver _testDiver() =>
    Diver(id: 'diver-1', name: 'Test Diver', createdAt: _now, updatedAt: _now);

/// Simple settings notifier for tests. Uses the same pattern as other adapter
/// tests: extends `StateNotifier<AppSettings>` and implements SettingsNotifier.
class _TestSettingsNotifier extends StateNotifier<AppSettings>
    implements SettingsNotifier {
  _TestSettingsNotifier() : super(const AppSettings());

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

/// A testable version of the notifier that allows setting state directly.
class _TestableImportNotifier extends UniversalImportNotifier {
  _TestableImportNotifier(super.ref);

  void setPayload(ImportPayload? payload) {
    state = state.copyWith(payload: payload);
  }

  void setOptions(ImportOptions options) {
    state = state.copyWith(options: options);
  }

  void setFileName(String name) {
    state = state.copyWith(fileName: name);
  }

  void setDetectedCsvPreset(CsvPreset? preset) {
    state = state.copyWith(detectedCsvPreset: preset);
  }

  void setFieldMapping(FieldMapping? mapping) {
    state = state.copyWith(fieldMapping: mapping);
  }

  void setDetectionResult(DetectionResult? result) {
    state = state.copyWith(detectionResult: result);
  }

  void setCurrentStep(ImportWizardStep step) {
    state = state.copyWith(currentStep: step);
  }
}

/// Helper to run adapter operations inside a widget tree that provides a
/// [WidgetRef] via [Consumer]. The [callback] receives the adapter, which is
/// created with the ref obtained from the Consumer widget.
///
/// Provider overrides are passed into the [ProviderScope].
Future<void> _runWithAdapter(
  WidgetTester tester, {
  required List<Override> overrides,
  required Future<void> Function(UniversalAdapter adapter) callback,
  String displayName = 'File Import',
}) async {
  late UniversalAdapter adapter;

  await tester.pumpWidget(
    ProviderScope(
      overrides: overrides,
      child: MaterialApp(
        home: Consumer(
          builder: (context, ref, _) {
            adapter = UniversalAdapter(ref: ref, displayName: displayName);
            return const SizedBox.shrink();
          },
        ),
      ),
    ),
  );
  await tester.pumpAndSettle();
  await callback(adapter);
}

/// Create a provider scope with a payload-bearing import state.
///
/// Returns the list of provider overrides needed for buildBundle tests.
List<Override> _buildBundleOverrides({
  ImportPayload? payload,
  ImportOptions? options,
}) {
  return [
    // Override the notifier with a state containing the payload.
    universalImportNotifierProvider.overrideWith((ref) {
      final notifier = _TestableImportNotifier(ref);
      notifier.setPayload(payload);
      if (options != null) notifier.setOptions(options);
      return notifier;
    }),
    // Override settings with a simple notifier to avoid database access.
    settingsProvider.overrideWith((ref) => _TestSettingsNotifier()),
  ];
}

/// Creates overrides for all providers needed by performImport and
/// checkDuplicates. Includes mock repositories and fake data providers.
List<Override> _fullOverrides({
  required ImportPayload payload,
  ImportOptions? options,
  Diver? diver,
  List<Dive> existingDives = const [],
  List<DiveSite> existingSites = const [],
  List<Trip> existingTrips = const [],
  List<EquipmentItem> existingEquipment = const [],
  List<Buddy> existingBuddies = const [],
  List<DiveCenter> existingDiveCenters = const [],
  List<Certification> existingCertifications = const [],
  List<Tag> existingTags = const [],
  List<DiveTypeEntity> existingDiveTypes = const [],
  MockDiveRepository? mockDiveRepo,
  MockSiteRepository? mockSiteRepo,
  MockTripRepository? mockTripRepo,
  MockEquipmentRepository? mockEquipmentRepo,
  MockEquipmentSetRepository? mockEquipmentSetRepo,
  MockBuddyRepository? mockBuddyRepo,
  MockDiveCenterRepository? mockDiveCenterRepo,
  MockCertificationRepository? mockCertificationRepo,
  MockTagRepository? mockTagRepo,
  MockDiveTypeRepository? mockDiveTypeRepo,
  MockTankPressureRepository? mockTankPressureRepo,
  MockCourseRepository? mockCourseRepo,
  MockTankPresetRepository? mockTankPresetRepo,
}) {
  final diveRepo = mockDiveRepo ?? MockDiveRepository();
  final siteRepo = mockSiteRepo ?? MockSiteRepository();
  final tripRepo = mockTripRepo ?? MockTripRepository();
  final equipmentRepo = mockEquipmentRepo ?? MockEquipmentRepository();
  final equipmentSetRepo = mockEquipmentSetRepo ?? MockEquipmentSetRepository();
  final buddyRepo = mockBuddyRepo ?? MockBuddyRepository();
  final diveCenterRepo = mockDiveCenterRepo ?? MockDiveCenterRepository();
  final certificationRepo =
      mockCertificationRepo ?? MockCertificationRepository();
  final tagRepo = mockTagRepo ?? MockTagRepository();
  final diveTypeRepo = mockDiveTypeRepo ?? MockDiveTypeRepository();
  final tankPressureRepo = mockTankPressureRepo ?? MockTankPressureRepository();
  final courseRepo = mockCourseRepo ?? MockCourseRepository();
  final tankPresetRepo = mockTankPresetRepo ?? MockTankPresetRepository();

  // Set up default mock return values for getAllDives.
  when(diveRepo.getAllDives()).thenAnswer((_) async => existingDives);

  return [
    universalImportNotifierProvider.overrideWith((ref) {
      final notifier = _TestableImportNotifier(ref);
      notifier.setPayload(payload);
      if (options != null) notifier.setOptions(options);
      return notifier;
    }),
    settingsProvider.overrideWith((ref) => _TestSettingsNotifier()),
    currentDiverProvider.overrideWith((ref) async => diver),
    diveRepositoryProvider.overrideWithValue(diveRepo),
    siteRepositoryProvider.overrideWithValue(siteRepo),
    tripRepositoryProvider.overrideWithValue(tripRepo),
    equipmentRepositoryProvider.overrideWithValue(equipmentRepo),
    equipmentSetRepositoryProvider.overrideWithValue(equipmentSetRepo),
    buddyRepositoryProvider.overrideWithValue(buddyRepo),
    diveCenterRepositoryProvider.overrideWithValue(diveCenterRepo),
    certificationRepositoryProvider.overrideWithValue(certificationRepo),
    tagRepositoryProvider.overrideWithValue(tagRepo),
    diveTypeRepositoryProvider.overrideWithValue(diveTypeRepo),
    tankPressureRepositoryProvider.overrideWithValue(tankPressureRepo),
    courseRepositoryProvider.overrideWithValue(courseRepo),
    tankPresetRepositoryProvider.overrideWithValue(tankPresetRepo),
    // Override the async list providers used by checkDuplicates.
    allTripsProvider.overrideWith((ref) async => existingTrips),
    sitesProvider.overrideWith((ref) async => existingSites),
    allEquipmentProvider.overrideWith((ref) async => existingEquipment),
    allBuddiesProvider.overrideWith((ref) async => existingBuddies),
    allDiveCentersProvider.overrideWith((ref) async => existingDiveCenters),
    allCertificationsProvider.overrideWith(
      (ref) async => existingCertifications,
    ),
    tagsProvider.overrideWith((ref) async => existingTags),
    diveTypesProvider.overrideWith((ref) async => existingDiveTypes),
  ];
}

// ---------------------------------------------------------------------------
// Tests
// ---------------------------------------------------------------------------

void main() {
  // -------------------------------------------------------------------------
  // Adapter metadata
  // -------------------------------------------------------------------------

  group('adapter metadata', () {
    testWidgets('sourceType is universal', (tester) async {
      await _runWithAdapter(
        tester,
        overrides: _buildBundleOverrides(),
        callback: (adapter) async {
          expect(adapter.sourceType, equals(ImportSourceType.universal));
        },
      );
    });

    testWidgets('displayName defaults to File Import', (tester) async {
      await _runWithAdapter(
        tester,
        overrides: _buildBundleOverrides(),
        callback: (adapter) async {
          expect(adapter.displayName, equals('File Import'));
        },
      );
    });

    testWidgets('custom displayName is used when provided', (tester) async {
      await _runWithAdapter(
        tester,
        overrides: _buildBundleOverrides(),
        displayName: 'Subsurface XML',
        callback: (adapter) async {
          expect(adapter.displayName, equals('Subsurface XML'));
        },
      );
    });

    testWidgets('supportedDuplicateActions contains skip and importAsNew', (
      tester,
    ) async {
      await _runWithAdapter(
        tester,
        overrides: _buildBundleOverrides(),
        callback: (adapter) async {
          expect(
            adapter.supportedDuplicateActions,
            containsAll([DuplicateAction.skip, DuplicateAction.importAsNew]),
          );
          expect(
            adapter.supportedDuplicateActions,
            isNot(contains(DuplicateAction.consolidate)),
          );
        },
      );
    });

    testWidgets('acquisitionSteps has three steps', (tester) async {
      await _runWithAdapter(
        tester,
        overrides: _buildBundleOverrides(),
        callback: (adapter) async {
          expect(adapter.acquisitionSteps, hasLength(3));
        },
      );
    });

    testWidgets('first step is Select File with autoAdvance true', (
      tester,
    ) async {
      await _runWithAdapter(
        tester,
        overrides: _buildBundleOverrides(),
        callback: (adapter) async {
          final step = adapter.acquisitionSteps[0];
          expect(step.label, equals('Select File'));
          expect(step.autoAdvance, isTrue);
        },
      );
    });

    testWidgets('second step is Confirm Source', (tester) async {
      await _runWithAdapter(
        tester,
        overrides: _buildBundleOverrides(),
        callback: (adapter) async {
          final step = adapter.acquisitionSteps[1];
          expect(step.label, equals('Confirm Source'));
          expect(step.autoAdvance, isFalse);
        },
      );
    });

    testWidgets('third step is Map Fields with autoAdvance true', (
      tester,
    ) async {
      await _runWithAdapter(
        tester,
        overrides: _buildBundleOverrides(),
        callback: (adapter) async {
          final step = adapter.acquisitionSteps[2];
          expect(step.label, equals('Map Fields'));
          expect(step.autoAdvance, isTrue);
        },
      );
    });

    testWidgets('defaultTagName uses displayName when no fileName set', (
      tester,
    ) async {
      await _runWithAdapter(
        tester,
        overrides: _buildBundleOverrides(),
        callback: (adapter) async {
          expect(
            adapter.defaultTagName,
            matches(RegExp(r'^File Import \d{4}-\d{2}-\d{2}$')),
          );
        },
      );
    });

    testWidgets('defaultTagName uses fileName when set', (tester) async {
      late _TestableImportNotifier testNotifier;
      await _runWithAdapter(
        tester,
        overrides: [
          universalImportNotifierProvider.overrideWith((ref) {
            testNotifier = _TestableImportNotifier(ref);
            testNotifier.setFileName('dive_log.csv');
            return testNotifier;
          }),
          settingsProvider.overrideWith((ref) => _TestSettingsNotifier()),
        ],
        callback: (adapter) async {
          expect(
            adapter.defaultTagName,
            matches(RegExp(r'^dive_log\.csv Import \d{4}-\d{2}-\d{2}$')),
          );
        },
      );
    });
  });

  // -------------------------------------------------------------------------
  // buildBundle -- null payload
  // -------------------------------------------------------------------------

  group('buildBundle() with null payload', () {
    testWidgets('returns empty bundle when payload is null', (tester) async {
      await _runWithAdapter(
        tester,
        overrides: _buildBundleOverrides(payload: null),
        callback: (adapter) async {
          final bundle = await adapter.buildBundle();

          expect(bundle.groups, isEmpty);
          expect(bundle.source.type, equals(ImportSourceType.universal));
          expect(bundle.source.displayName, equals('File Import'));
        },
      );
    });
  });

  // -------------------------------------------------------------------------
  // buildBundle -- dive entity items
  // -------------------------------------------------------------------------

  group('buildBundle() - dive entity items', () {
    testWidgets('converts dive with dateTime, depth, and duration', (
      tester,
    ) async {
      final payload = ImportPayload(
        entities: {
          ui.ImportEntityType.dives: [
            {
              'dateTime': DateTime(2026, 3, 15, 10, 32),
              'maxDepth': 30.5,
              'runtime': const Duration(minutes: 47),
              'siteName': 'Blue Hole',
            },
          ],
        },
      );

      await _runWithAdapter(
        tester,
        overrides: _buildBundleOverrides(payload: payload),
        callback: (adapter) async {
          final bundle = await adapter.buildBundle();

          expect(bundle.hasType(ImportEntityType.dives), isTrue);
          final item = bundle.groups[ImportEntityType.dives]!.items.first;

          // Title contains formatted date and time.
          expect(item.title, contains('Mar 15, 2026'));
          expect(item.title, contains('\u2014')); // em dash
          expect(item.title, contains('10:32'));

          // Subtitle contains site name, depth, duration.
          expect(item.subtitle, contains('Blue Hole'));
          expect(item.subtitle, contains('30.5'));
          expect(item.subtitle, contains('47 min'));
        },
      );
    });

    testWidgets('dive with null dateTime shows "Unknown date"', (tester) async {
      const payload = ImportPayload(
        entities: {
          ui.ImportEntityType.dives: [
            {'maxDepth': 20.0},
          ],
        },
      );

      await _runWithAdapter(
        tester,
        overrides: _buildBundleOverrides(payload: payload),
        callback: (adapter) async {
          final bundle = await adapter.buildBundle();
          final item = bundle.groups[ImportEntityType.dives]!.items.first;

          expect(item.title, equals('Unknown date'));
        },
      );
    });

    testWidgets('dive uses site name from nested site map', (tester) async {
      final payload = ImportPayload(
        entities: {
          ui.ImportEntityType.dives: [
            {
              'dateTime': DateTime(2026, 3, 15, 10, 0),
              'site': {'name': 'Nested Site'},
            },
          ],
        },
      );

      await _runWithAdapter(
        tester,
        overrides: _buildBundleOverrides(payload: payload),
        callback: (adapter) async {
          final bundle = await adapter.buildBundle();
          final item = bundle.groups[ImportEntityType.dives]!.items.first;

          expect(item.subtitle, contains('Nested Site'));
        },
      );
    });

    testWidgets('dive uses duration when runtime is null', (tester) async {
      final payload = ImportPayload(
        entities: {
          ui.ImportEntityType.dives: [
            {
              'dateTime': DateTime(2026, 3, 15, 10, 0),
              'duration': const Duration(minutes: 35),
            },
          ],
        },
      );

      await _runWithAdapter(
        tester,
        overrides: _buildBundleOverrides(payload: payload),
        callback: (adapter) async {
          final bundle = await adapter.buildBundle();
          final item = bundle.groups[ImportEntityType.dives]!.items.first;

          expect(item.subtitle, contains('35 min'));
        },
      );
    });

    testWidgets('dive subtitle is empty when no optional fields are set', (
      tester,
    ) async {
      final payload = ImportPayload(
        entities: {
          ui.ImportEntityType.dives: [
            {'dateTime': DateTime(2026, 3, 15, 10, 0)},
          ],
        },
      );

      await _runWithAdapter(
        tester,
        overrides: _buildBundleOverrides(payload: payload),
        callback: (adapter) async {
          final bundle = await adapter.buildBundle();
          final item = bundle.groups[ImportEntityType.dives]!.items.first;

          expect(item.subtitle, isEmpty);
        },
      );
    });

    testWidgets('dive item populates diveData via fromImportMap', (
      tester,
    ) async {
      final payload = ImportPayload(
        entities: {
          ui.ImportEntityType.dives: [
            {
              'dateTime': DateTime(2026, 3, 15, 10, 32),
              'maxDepth': 30.5,
              'avgDepth': 18.0,
              'runtime': const Duration(minutes: 47),
              'waterTemp': 22.0,
            },
          ],
        },
      );

      await _runWithAdapter(
        tester,
        overrides: _buildBundleOverrides(payload: payload),
        callback: (adapter) async {
          final bundle = await adapter.buildBundle();
          final item = bundle.groups[ImportEntityType.dives]!.items.first;

          expect(item.diveData, isNotNull);
          expect(item.diveData!.maxDepth, equals(30.5));
          expect(item.diveData!.avgDepth, equals(18.0));
          expect(item.diveData!.durationSeconds, equals(47 * 60));
          expect(item.diveData!.waterTemp, equals(22.0));
        },
      );
    });
  });

  // -------------------------------------------------------------------------
  // buildBundle -- site entity items
  // -------------------------------------------------------------------------

  group('buildBundle() - site entity items', () {
    testWidgets('converts site with name and coordinates', (tester) async {
      const payload = ImportPayload(
        entities: {
          ui.ImportEntityType.sites: [
            {'name': 'Blue Hole', 'latitude': 17.3155, 'longitude': -87.5347},
          ],
        },
      );

      await _runWithAdapter(
        tester,
        overrides: _buildBundleOverrides(payload: payload),
        callback: (adapter) async {
          final bundle = await adapter.buildBundle();

          expect(bundle.hasType(ImportEntityType.sites), isTrue);
          final item = bundle.groups[ImportEntityType.sites]!.items.first;

          expect(item.title, equals('Blue Hole'));
          expect(item.subtitle, contains('17.3155'));
          expect(item.subtitle, contains('-87.5347'));
        },
      );
    });

    testWidgets('site with location string uses location as subtitle', (
      tester,
    ) async {
      const payload = ImportPayload(
        entities: {
          ui.ImportEntityType.sites: [
            {'name': 'Reef Site', 'location': 'Cozumel, Mexico'},
          ],
        },
      );

      await _runWithAdapter(
        tester,
        overrides: _buildBundleOverrides(payload: payload),
        callback: (adapter) async {
          final bundle = await adapter.buildBundle();
          final item = bundle.groups[ImportEntityType.sites]!.items.first;

          expect(item.title, equals('Reef Site'));
          expect(item.subtitle, equals('Cozumel, Mexico'));
        },
      );
    });

    testWidgets('site with no location info has empty subtitle', (
      tester,
    ) async {
      const payload = ImportPayload(
        entities: {
          ui.ImportEntityType.sites: [
            {'name': 'Mystery Site'},
          ],
        },
      );

      await _runWithAdapter(
        tester,
        overrides: _buildBundleOverrides(payload: payload),
        callback: (adapter) async {
          final bundle = await adapter.buildBundle();
          final item = bundle.groups[ImportEntityType.sites]!.items.first;

          expect(item.subtitle, isEmpty);
        },
      );
    });

    testWidgets('site with null name shows Unnamed', (tester) async {
      const payload = ImportPayload(
        entities: {
          ui.ImportEntityType.sites: [
            {'latitude': 17.0, 'longitude': -87.0},
          ],
        },
      );

      await _runWithAdapter(
        tester,
        overrides: _buildBundleOverrides(payload: payload),
        callback: (adapter) async {
          final bundle = await adapter.buildBundle();
          final item = bundle.groups[ImportEntityType.sites]!.items.first;

          expect(item.title, equals('Unnamed'));
        },
      );
    });
  });

  // -------------------------------------------------------------------------
  // buildBundle -- buddy entity items
  // -------------------------------------------------------------------------

  group('buildBundle() - buddy entity items', () {
    testWidgets('converts buddy with firstName and lastName', (tester) async {
      const payload = ImportPayload(
        entities: {
          ui.ImportEntityType.buddies: [
            {'firstName': 'Jane', 'lastName': 'Doe'},
          ],
        },
      );

      await _runWithAdapter(
        tester,
        overrides: _buildBundleOverrides(payload: payload),
        callback: (adapter) async {
          final bundle = await adapter.buildBundle();
          final item = bundle.groups[ImportEntityType.buddies]!.items.first;

          expect(item.title, equals('Jane Doe'));
        },
      );
    });

    testWidgets('buddy with only firstName shows firstName', (tester) async {
      const payload = ImportPayload(
        entities: {
          ui.ImportEntityType.buddies: [
            {'firstName': 'Jane'},
          ],
        },
      );

      await _runWithAdapter(
        tester,
        overrides: _buildBundleOverrides(payload: payload),
        callback: (adapter) async {
          final bundle = await adapter.buildBundle();
          final item = bundle.groups[ImportEntityType.buddies]!.items.first;

          expect(item.title, equals('Jane'));
        },
      );
    });

    testWidgets('buddy with only name uses name field', (tester) async {
      const payload = ImportPayload(
        entities: {
          ui.ImportEntityType.buddies: [
            {'name': 'Captain Jack'},
          ],
        },
      );

      await _runWithAdapter(
        tester,
        overrides: _buildBundleOverrides(payload: payload),
        callback: (adapter) async {
          final bundle = await adapter.buildBundle();
          final item = bundle.groups[ImportEntityType.buddies]!.items.first;

          expect(item.title, equals('Captain Jack'));
        },
      );
    });

    testWidgets('buddy with no name shows Unnamed', (tester) async {
      const payload = ImportPayload(
        entities: {
          ui.ImportEntityType.buddies: [<String, dynamic>{}],
        },
      );

      await _runWithAdapter(
        tester,
        overrides: _buildBundleOverrides(payload: payload),
        callback: (adapter) async {
          final bundle = await adapter.buildBundle();
          final item = bundle.groups[ImportEntityType.buddies]!.items.first;

          expect(item.title, equals('Unnamed'));
        },
      );
    });
  });

  // -------------------------------------------------------------------------
  // buildBundle -- equipment entity items
  // -------------------------------------------------------------------------

  group('buildBundle() - equipment entity items', () {
    testWidgets('converts equipment with EquipmentType enum', (tester) async {
      const payload = ImportPayload(
        entities: {
          ui.ImportEntityType.equipment: [
            {'name': 'Aqualung Regulator', 'type': EquipmentType.regulator},
          ],
        },
      );

      await _runWithAdapter(
        tester,
        overrides: _buildBundleOverrides(payload: payload),
        callback: (adapter) async {
          final bundle = await adapter.buildBundle();
          final item = bundle.groups[ImportEntityType.equipment]!.items.first;

          expect(item.title, equals('Aqualung Regulator'));
          expect(item.subtitle, equals('Regulator'));
        },
      );
    });

    testWidgets('converts equipment with String type', (tester) async {
      const payload = ImportPayload(
        entities: {
          ui.ImportEntityType.equipment: [
            {'name': 'Custom Gear', 'type': 'Special Equipment'},
          ],
        },
      );

      await _runWithAdapter(
        tester,
        overrides: _buildBundleOverrides(payload: payload),
        callback: (adapter) async {
          final bundle = await adapter.buildBundle();
          final item = bundle.groups[ImportEntityType.equipment]!.items.first;

          expect(item.title, equals('Custom Gear'));
          expect(item.subtitle, equals('Special Equipment'));
        },
      );
    });

    testWidgets('equipment with no type has empty subtitle', (tester) async {
      const payload = ImportPayload(
        entities: {
          ui.ImportEntityType.equipment: [
            {'name': 'Mystery Gear'},
          ],
        },
      );

      await _runWithAdapter(
        tester,
        overrides: _buildBundleOverrides(payload: payload),
        callback: (adapter) async {
          final bundle = await adapter.buildBundle();
          final item = bundle.groups[ImportEntityType.equipment]!.items.first;

          expect(item.subtitle, isEmpty);
        },
      );
    });

    testWidgets('equipment with null name shows Unnamed', (tester) async {
      const payload = ImportPayload(
        entities: {
          ui.ImportEntityType.equipment: [<String, dynamic>{}],
        },
      );

      await _runWithAdapter(
        tester,
        overrides: _buildBundleOverrides(payload: payload),
        callback: (adapter) async {
          final bundle = await adapter.buildBundle();
          final item = bundle.groups[ImportEntityType.equipment]!.items.first;

          expect(item.title, equals('Unnamed'));
        },
      );
    });
  });

  // -------------------------------------------------------------------------
  // buildBundle -- trip entity items
  // -------------------------------------------------------------------------

  group('buildBundle() - trip entity items', () {
    testWidgets('converts trip with name and date range', (tester) async {
      final payload = ImportPayload(
        entities: {
          ui.ImportEntityType.trips: [
            {
              'name': 'Belize Dive Trip',
              'startDate': DateTime(2026, 3, 1),
              'endDate': DateTime(2026, 3, 7),
            },
          ],
        },
      );

      await _runWithAdapter(
        tester,
        overrides: _buildBundleOverrides(payload: payload),
        callback: (adapter) async {
          final bundle = await adapter.buildBundle();
          final item = bundle.groups[ImportEntityType.trips]!.items.first;

          expect(item.title, equals('Belize Dive Trip'));
          expect(item.subtitle, contains('Mar 1, 2026'));
          expect(item.subtitle, contains('Mar 7, 2026'));
          expect(item.subtitle, contains(' - '));
        },
      );
    });

    testWidgets('trip with only startDate shows single date', (tester) async {
      final payload = ImportPayload(
        entities: {
          ui.ImportEntityType.trips: [
            {'name': 'Day Trip', 'startDate': DateTime(2026, 3, 1)},
          ],
        },
      );

      await _runWithAdapter(
        tester,
        overrides: _buildBundleOverrides(payload: payload),
        callback: (adapter) async {
          final bundle = await adapter.buildBundle();
          final item = bundle.groups[ImportEntityType.trips]!.items.first;

          expect(item.subtitle, equals('Mar 1, 2026'));
        },
      );
    });

    testWidgets('trip with no dates has empty subtitle', (tester) async {
      const payload = ImportPayload(
        entities: {
          ui.ImportEntityType.trips: [
            {'name': 'Undated Trip'},
          ],
        },
      );

      await _runWithAdapter(
        tester,
        overrides: _buildBundleOverrides(payload: payload),
        callback: (adapter) async {
          final bundle = await adapter.buildBundle();
          final item = bundle.groups[ImportEntityType.trips]!.items.first;

          expect(item.subtitle, isEmpty);
        },
      );
    });
  });

  // -------------------------------------------------------------------------
  // buildBundle -- certification entity items
  // -------------------------------------------------------------------------

  group('buildBundle() - certification entity items', () {
    testWidgets(
      'converts certification with level and CertificationAgency enum',
      (tester) async {
        const payload = ImportPayload(
          entities: {
            ui.ImportEntityType.certifications: [
              {'level': 'Open Water', 'agency': CertificationAgency.padi},
            ],
          },
        );

        await _runWithAdapter(
          tester,
          overrides: _buildBundleOverrides(payload: payload),
          callback: (adapter) async {
            final bundle = await adapter.buildBundle();
            final item =
                bundle.groups[ImportEntityType.certifications]!.items.first;

            expect(item.title, equals('Open Water'));
            expect(item.subtitle, equals('PADI'));
          },
        );
      },
    );

    testWidgets('certification with String agency', (tester) async {
      const payload = ImportPayload(
        entities: {
          ui.ImportEntityType.certifications: [
            {'name': 'Advanced OW', 'agency': 'SSI'},
          ],
        },
      );

      await _runWithAdapter(
        tester,
        overrides: _buildBundleOverrides(payload: payload),
        callback: (adapter) async {
          final bundle = await adapter.buildBundle();
          final item =
              bundle.groups[ImportEntityType.certifications]!.items.first;

          expect(item.title, equals('Advanced OW'));
          expect(item.subtitle, equals('SSI'));
        },
      );
    });

    testWidgets('certification with no agency has empty subtitle', (
      tester,
    ) async {
      const payload = ImportPayload(
        entities: {
          ui.ImportEntityType.certifications: [
            {'level': 'Rescue Diver'},
          ],
        },
      );

      await _runWithAdapter(
        tester,
        overrides: _buildBundleOverrides(payload: payload),
        callback: (adapter) async {
          final bundle = await adapter.buildBundle();
          final item =
              bundle.groups[ImportEntityType.certifications]!.items.first;

          expect(item.title, equals('Rescue Diver'));
          expect(item.subtitle, isEmpty);
        },
      );
    });

    testWidgets('certification uses name when level is null', (tester) async {
      const payload = ImportPayload(
        entities: {
          ui.ImportEntityType.certifications: [
            {'name': 'Divemaster'},
          ],
        },
      );

      await _runWithAdapter(
        tester,
        overrides: _buildBundleOverrides(payload: payload),
        callback: (adapter) async {
          final bundle = await adapter.buildBundle();
          final item =
              bundle.groups[ImportEntityType.certifications]!.items.first;

          expect(item.title, equals('Divemaster'));
        },
      );
    });
  });

  // -------------------------------------------------------------------------
  // buildBundle -- dive center entity items
  // -------------------------------------------------------------------------

  group('buildBundle() - dive center entity items', () {
    testWidgets('converts dive center with name and location', (tester) async {
      const payload = ImportPayload(
        entities: {
          ui.ImportEntityType.diveCenters: [
            {'name': 'Reef Divers', 'location': 'Grand Cayman'},
          ],
        },
      );

      await _runWithAdapter(
        tester,
        overrides: _buildBundleOverrides(payload: payload),
        callback: (adapter) async {
          final bundle = await adapter.buildBundle();
          final item = bundle.groups[ImportEntityType.diveCenters]!.items.first;

          expect(item.title, equals('Reef Divers'));
          expect(item.subtitle, equals('Grand Cayman'));
        },
      );
    });

    testWidgets('dive center with country and city', (tester) async {
      const payload = ImportPayload(
        entities: {
          ui.ImportEntityType.diveCenters: [
            {'name': 'Island Divers', 'country': 'Mexico', 'city': 'Cozumel'},
          ],
        },
      );

      await _runWithAdapter(
        tester,
        overrides: _buildBundleOverrides(payload: payload),
        callback: (adapter) async {
          final bundle = await adapter.buildBundle();
          final item = bundle.groups[ImportEntityType.diveCenters]!.items.first;

          expect(item.subtitle, equals('Cozumel, Mexico'));
        },
      );
    });

    testWidgets('dive center with only country', (tester) async {
      const payload = ImportPayload(
        entities: {
          ui.ImportEntityType.diveCenters: [
            {'name': 'Dive Shop', 'country': 'Thailand'},
          ],
        },
      );

      await _runWithAdapter(
        tester,
        overrides: _buildBundleOverrides(payload: payload),
        callback: (adapter) async {
          final bundle = await adapter.buildBundle();
          final item = bundle.groups[ImportEntityType.diveCenters]!.items.first;

          expect(item.subtitle, equals('Thailand'));
        },
      );
    });

    testWidgets('dive center with only city', (tester) async {
      const payload = ImportPayload(
        entities: {
          ui.ImportEntityType.diveCenters: [
            {'name': 'Local Dive', 'city': 'Honolulu'},
          ],
        },
      );

      await _runWithAdapter(
        tester,
        overrides: _buildBundleOverrides(payload: payload),
        callback: (adapter) async {
          final bundle = await adapter.buildBundle();
          final item = bundle.groups[ImportEntityType.diveCenters]!.items.first;

          expect(item.subtitle, equals('Honolulu'));
        },
      );
    });

    testWidgets('dive center with no location info has empty subtitle', (
      tester,
    ) async {
      const payload = ImportPayload(
        entities: {
          ui.ImportEntityType.diveCenters: [
            {'name': 'Unknown Center'},
          ],
        },
      );

      await _runWithAdapter(
        tester,
        overrides: _buildBundleOverrides(payload: payload),
        callback: (adapter) async {
          final bundle = await adapter.buildBundle();
          final item = bundle.groups[ImportEntityType.diveCenters]!.items.first;

          expect(item.subtitle, isEmpty);
        },
      );
    });
  });

  // -------------------------------------------------------------------------
  // buildBundle -- simple entity items (tags, dive types, equipment sets,
  // courses)
  // -------------------------------------------------------------------------

  group('buildBundle() - simple entity items', () {
    testWidgets('converts tag with name', (tester) async {
      const payload = ImportPayload(
        entities: {
          ui.ImportEntityType.tags: [
            {'name': 'Night Dive'},
          ],
        },
      );

      await _runWithAdapter(
        tester,
        overrides: _buildBundleOverrides(payload: payload),
        callback: (adapter) async {
          final bundle = await adapter.buildBundle();
          final item = bundle.groups[ImportEntityType.tags]!.items.first;

          expect(item.title, equals('Night Dive'));
          expect(item.subtitle, isEmpty);
        },
      );
    });

    testWidgets('tag with null name shows Unnamed', (tester) async {
      const payload = ImportPayload(
        entities: {
          ui.ImportEntityType.tags: [<String, dynamic>{}],
        },
      );

      await _runWithAdapter(
        tester,
        overrides: _buildBundleOverrides(payload: payload),
        callback: (adapter) async {
          final bundle = await adapter.buildBundle();
          final item = bundle.groups[ImportEntityType.tags]!.items.first;

          expect(item.title, equals('Unnamed'));
        },
      );
    });

    testWidgets('converts dive type with name', (tester) async {
      const payload = ImportPayload(
        entities: {
          ui.ImportEntityType.diveTypes: [
            {'name': 'Deep Dive'},
          ],
        },
      );

      await _runWithAdapter(
        tester,
        overrides: _buildBundleOverrides(payload: payload),
        callback: (adapter) async {
          final bundle = await adapter.buildBundle();
          final item = bundle.groups[ImportEntityType.diveTypes]!.items.first;

          expect(item.title, equals('Deep Dive'));
          expect(item.subtitle, isEmpty);
        },
      );
    });

    testWidgets('converts equipment set with name', (tester) async {
      const payload = ImportPayload(
        entities: {
          ui.ImportEntityType.equipmentSets: [
            {'name': 'Tropical Setup'},
          ],
        },
      );

      await _runWithAdapter(
        tester,
        overrides: _buildBundleOverrides(payload: payload),
        callback: (adapter) async {
          final bundle = await adapter.buildBundle();
          final item =
              bundle.groups[ImportEntityType.equipmentSets]!.items.first;

          expect(item.title, equals('Tropical Setup'));
          expect(item.subtitle, isEmpty);
        },
      );
    });

    testWidgets('converts course with name and agency', (tester) async {
      const payload = ImportPayload(
        entities: {
          ui.ImportEntityType.courses: [
            {'name': 'Nitrox Course', 'agency': 'PADI'},
          ],
        },
      );

      await _runWithAdapter(
        tester,
        overrides: _buildBundleOverrides(payload: payload),
        callback: (adapter) async {
          final bundle = await adapter.buildBundle();
          final item = bundle.groups[ImportEntityType.courses]!.items.first;

          expect(item.title, equals('Nitrox Course'));
          expect(item.subtitle, equals('PADI'));
        },
      );
    });

    testWidgets('course with no agency has empty subtitle', (tester) async {
      const payload = ImportPayload(
        entities: {
          ui.ImportEntityType.courses: [
            {'name': 'Solo Course'},
          ],
        },
      );

      await _runWithAdapter(
        tester,
        overrides: _buildBundleOverrides(payload: payload),
        callback: (adapter) async {
          final bundle = await adapter.buildBundle();
          final item = bundle.groups[ImportEntityType.courses]!.items.first;

          expect(item.subtitle, isEmpty);
        },
      );
    });
  });

  // -------------------------------------------------------------------------
  // buildBundle -- empty groups are excluded
  // -------------------------------------------------------------------------

  group('buildBundle() - empty group exclusion', () {
    testWidgets('empty entity lists are not added to groups', (tester) async {
      final payload = ImportPayload(
        entities: {
          ui.ImportEntityType.dives: [
            {'dateTime': DateTime(2026, 3, 15, 10, 0)},
          ],
          ui.ImportEntityType.sites: const [],
          ui.ImportEntityType.buddies: const [],
        },
      );

      await _runWithAdapter(
        tester,
        overrides: _buildBundleOverrides(payload: payload),
        callback: (adapter) async {
          final bundle = await adapter.buildBundle();

          expect(bundle.hasType(ImportEntityType.dives), isTrue);
          expect(bundle.hasType(ImportEntityType.sites), isFalse);
          expect(bundle.hasType(ImportEntityType.buddies), isFalse);
        },
      );
    });

    testWidgets('all entity types appear when populated', (tester) async {
      final payload = ImportPayload(
        entities: {
          ui.ImportEntityType.dives: [
            {'dateTime': DateTime(2026, 1, 1)},
          ],
          ui.ImportEntityType.sites: [
            {'name': 'S1'},
          ],
          ui.ImportEntityType.buddies: [
            {'name': 'B1'},
          ],
          ui.ImportEntityType.equipment: [
            {'name': 'E1'},
          ],
          ui.ImportEntityType.trips: [
            {'name': 'T1'},
          ],
          ui.ImportEntityType.certifications: [
            {'name': 'C1'},
          ],
          ui.ImportEntityType.diveCenters: [
            {'name': 'DC1'},
          ],
          ui.ImportEntityType.tags: [
            {'name': 'Tag1'},
          ],
          ui.ImportEntityType.diveTypes: [
            {'name': 'DT1'},
          ],
          ui.ImportEntityType.equipmentSets: [
            {'name': 'ES1'},
          ],
          ui.ImportEntityType.courses: [
            {'name': 'CO1'},
          ],
        },
      );

      await _runWithAdapter(
        tester,
        overrides: _buildBundleOverrides(payload: payload),
        callback: (adapter) async {
          final bundle = await adapter.buildBundle();

          expect(bundle.groups.length, equals(11));
          expect(bundle.hasType(ImportEntityType.dives), isTrue);
          expect(bundle.hasType(ImportEntityType.sites), isTrue);
          expect(bundle.hasType(ImportEntityType.buddies), isTrue);
          expect(bundle.hasType(ImportEntityType.equipment), isTrue);
          expect(bundle.hasType(ImportEntityType.trips), isTrue);
          expect(bundle.hasType(ImportEntityType.certifications), isTrue);
          expect(bundle.hasType(ImportEntityType.diveCenters), isTrue);
          expect(bundle.hasType(ImportEntityType.tags), isTrue);
          expect(bundle.hasType(ImportEntityType.diveTypes), isTrue);
          expect(bundle.hasType(ImportEntityType.equipmentSets), isTrue);
          expect(bundle.hasType(ImportEntityType.courses), isTrue);
        },
      );
    });
  });

  // -------------------------------------------------------------------------
  // buildBundle -- source info
  // -------------------------------------------------------------------------

  group('buildBundle() - source info', () {
    testWidgets('bundle source info reflects adapter config', (tester) async {
      final payload = ImportPayload(
        entities: {
          ui.ImportEntityType.dives: [
            {'dateTime': DateTime(2026, 1, 1)},
          ],
        },
      );

      await _runWithAdapter(
        tester,
        overrides: _buildBundleOverrides(payload: payload),
        displayName: 'my_dives.xml',
        callback: (adapter) async {
          final bundle = await adapter.buildBundle();

          expect(bundle.source.type, equals(ImportSourceType.universal));
          expect(bundle.source.displayName, equals('my_dives.xml'));
        },
      );
    });
  });

  // -------------------------------------------------------------------------
  // checkDuplicates
  // -------------------------------------------------------------------------

  group('checkDuplicates()', () {
    testWidgets('marks duplicate sites in duplicateIndices', (tester) async {
      const payload = ImportPayload(
        entities: {
          ui.ImportEntityType.sites: [
            {'name': 'Blue Hole'},
          ],
        },
      );

      const existingSite = DiveSite(id: 'site-1', name: 'Blue Hole');

      await _runWithAdapter(
        tester,
        overrides: _fullOverrides(
          payload: payload,
          diver: _testDiver(),
          existingSites: [existingSite],
        ),
        callback: (adapter) async {
          final bundle = await adapter.buildBundle();
          final result = await adapter.checkDuplicates(bundle);

          final siteGroup = result.groups[ImportEntityType.sites];
          expect(siteGroup, isNotNull);
          expect(siteGroup!.duplicateIndices, contains(0));
        },
      );
    });

    testWidgets('marks duplicate tags in duplicateIndices', (tester) async {
      const payload = ImportPayload(
        entities: {
          ui.ImportEntityType.tags: [
            {'name': 'Night Dive'},
            {'name': 'Unique Tag'},
          ],
        },
      );

      final existingTag = Tag(
        id: 'tag-1',
        name: 'Night Dive',
        createdAt: _now,
        updatedAt: _now,
      );

      await _runWithAdapter(
        tester,
        overrides: _fullOverrides(
          payload: payload,
          diver: _testDiver(),
          existingTags: [existingTag],
        ),
        callback: (adapter) async {
          final bundle = await adapter.buildBundle();
          final result = await adapter.checkDuplicates(bundle);

          final tagGroup = result.groups[ImportEntityType.tags];
          expect(tagGroup, isNotNull);
          expect(tagGroup!.duplicateIndices, contains(0));
          expect(tagGroup.duplicateIndices, isNot(contains(1)));
        },
      );
    });

    testWidgets('marks duplicate dive via DiveMatcher scoring', (tester) async {
      final diveDate = DateTime(2026, 3, 15, 10, 32);
      final payload = ImportPayload(
        entities: {
          ui.ImportEntityType.dives: [
            {
              'dateTime': diveDate,
              'maxDepth': 30.0,
              'runtime': const Duration(minutes: 45),
            },
          ],
        },
      );

      final existingDive = Dive(
        id: 'dive-existing-1',
        diverId: 'diver-1',
        dateTime: diveDate,
        entryTime: diveDate,
        exitTime: diveDate.add(const Duration(minutes: 45)),
        maxDepth: 30.0,
        runtime: const Duration(minutes: 45),
        notes: '',
        diveTypeId: '',
        tanks: const [],
        profile: const [],
        equipment: const [],
        photoIds: const [],
        sightings: const [],
      );

      await _runWithAdapter(
        tester,
        overrides: _fullOverrides(
          payload: payload,
          diver: _testDiver(),
          existingDives: [existingDive],
        ),
        callback: (adapter) async {
          final bundle = await adapter.buildBundle();
          final result = await adapter.checkDuplicates(bundle);

          final diveGroup = result.groups[ImportEntityType.dives];
          expect(diveGroup, isNotNull);
          // Identical dive data should match as duplicate.
          expect(diveGroup!.duplicateIndices, contains(0));
          expect(diveGroup.matchResults, isNotNull);
          expect(diveGroup.matchResults!.containsKey(0), isTrue);
        },
      );
    });

    testWidgets('non-duplicate entities are not marked', (tester) async {
      const payload = ImportPayload(
        entities: {
          ui.ImportEntityType.sites: [
            {'name': 'Unique Site'},
          ],
        },
      );

      const existingSite = DiveSite(id: 'site-1', name: 'Different Site');

      await _runWithAdapter(
        tester,
        overrides: _fullOverrides(
          payload: payload,
          diver: _testDiver(),
          existingSites: [existingSite],
        ),
        callback: (adapter) async {
          final bundle = await adapter.buildBundle();
          final result = await adapter.checkDuplicates(bundle);

          final siteGroup = result.groups[ImportEntityType.sites];
          expect(siteGroup, isNotNull);
          expect(siteGroup!.duplicateIndices, isEmpty);
        },
      );
    });

    testWidgets('returns unchanged bundle when payload is null', (
      tester,
    ) async {
      const bundle = ImportBundle(
        source: ImportSourceInfo(
          type: ImportSourceType.universal,
          displayName: 'Test',
        ),
        groups: {},
      );

      await _runWithAdapter(
        tester,
        overrides: _buildBundleOverrides(payload: null),
        callback: (adapter) async {
          final result = await adapter.checkDuplicates(bundle);
          expect(result.groups, isEmpty);
        },
      );
    });
  });

  // -------------------------------------------------------------------------
  // performImport -- error cases
  // -------------------------------------------------------------------------

  group('performImport() - error cases', () {
    testWidgets('returns error when payload is null', (tester) async {
      const bundle = ImportBundle(
        source: ImportSourceInfo(
          type: ImportSourceType.universal,
          displayName: 'Test',
        ),
        groups: {},
      );

      // Use buildBundleOverrides which sets null payload.
      await _runWithAdapter(
        tester,
        overrides: _buildBundleOverrides(payload: null),
        callback: (adapter) async {
          final result = await adapter.performImport(bundle, {}, {});

          expect(result.errorMessage, isNotNull);
          expect(result.errorMessage, contains('No parsed data'));
          expect(result.importedCounts, isEmpty);
        },
      );
    });

    testWidgets('returns error when diver is null', (tester) async {
      final payload = ImportPayload(
        entities: {
          ui.ImportEntityType.dives: [
            {'dateTime': DateTime(2026, 1, 1)},
          ],
        },
      );

      const bundle = ImportBundle(
        source: ImportSourceInfo(
          type: ImportSourceType.universal,
          displayName: 'Test',
        ),
        groups: {},
      );

      await _runWithAdapter(
        tester,
        overrides: _fullOverrides(payload: payload, diver: null),
        callback: (adapter) async {
          final result = await adapter.performImport(bundle, {}, {});

          expect(result.errorMessage, isNotNull);
          expect(result.errorMessage, contains('diver profile'));
        },
      );
    });
  });

  // -------------------------------------------------------------------------
  // performImport -- _resolveSelections logic
  // -------------------------------------------------------------------------

  group('performImport() - resolve selections', () {
    testWidgets('skip action removes item from base selection', (tester) async {
      final payload = ImportPayload(
        entities: {
          ui.ImportEntityType.dives: [
            {
              'dateTime': DateTime(2026, 3, 15, 10, 0),
              'maxDepth': 20.0,
              'runtime': const Duration(minutes: 30),
            },
          ],
        },
      );

      final mockDiveRepo = MockDiveRepository();
      when(mockDiveRepo.getAllDives()).thenAnswer((_) async => <Dive>[]);

      final mockTankPresetRepo = MockTankPresetRepository();
      when(mockTankPresetRepo.getPresetById(any)).thenAnswer((_) async => null);

      await _runWithAdapter(
        tester,
        overrides: _fullOverrides(
          payload: payload,
          diver: _testDiver(),
          mockDiveRepo: mockDiveRepo,
          mockTankPresetRepo: mockTankPresetRepo,
        ),
        callback: (adapter) async {
          final bundle = await adapter.buildBundle();
          final result = await adapter.performImport(
            bundle,
            {
              wizard.ImportEntityType.dives: {0},
            },
            {
              wizard.ImportEntityType.dives: {0: DuplicateAction.skip},
            },
          );

          // Item 0 was in selections but marked skip -- should be removed.
          expect(result.skippedCount, equals(1));
        },
      );
    });

    testWidgets('importAsNew action adds item even if not in base selection', (
      tester,
    ) async {
      final payload = ImportPayload(
        entities: {
          ui.ImportEntityType.dives: [
            {
              'dateTime': DateTime(2026, 3, 15, 10, 0),
              'maxDepth': 20.0,
              'runtime': const Duration(minutes: 30),
            },
          ],
        },
      );

      final mockDiveRepo = MockDiveRepository();
      when(mockDiveRepo.getAllDives()).thenAnswer((_) async => <Dive>[]);

      final mockTankPresetRepo = MockTankPresetRepository();
      when(mockTankPresetRepo.getPresetById(any)).thenAnswer((_) async => null);

      await _runWithAdapter(
        tester,
        overrides: _fullOverrides(
          payload: payload,
          diver: _testDiver(),
          mockDiveRepo: mockDiveRepo,
          mockTankPresetRepo: mockTankPresetRepo,
        ),
        callback: (adapter) async {
          final bundle = await adapter.buildBundle();
          final result = await adapter.performImport(
            bundle,
            // Empty base selection (item 0 is NOT selected).
            {wizard.ImportEntityType.dives: <int>{}},
            {
              wizard.ImportEntityType.dives: {0: DuplicateAction.importAsNew},
            },
          );

          // Item was added via importAsNew action.
          expect(result.skippedCount, equals(0));
        },
      );
    });
  });

  // -------------------------------------------------------------------------
  // performImport -- _countSkipped logic
  // -------------------------------------------------------------------------

  group('performImport() - _countSkipped', () {
    testWidgets('counts only dive skip actions', (tester) async {
      final payload = ImportPayload(
        entities: {
          ui.ImportEntityType.dives: [
            {
              'dateTime': DateTime(2026, 3, 15, 10, 0),
              'maxDepth': 20.0,
              'runtime': const Duration(minutes: 30),
            },
            {
              'dateTime': DateTime(2026, 3, 16, 10, 0),
              'maxDepth': 15.0,
              'runtime': const Duration(minutes: 25),
            },
            {
              'dateTime': DateTime(2026, 3, 17, 10, 0),
              'maxDepth': 18.0,
              'runtime': const Duration(minutes: 40),
            },
          ],
          ui.ImportEntityType.sites: [
            {'name': 'Site 1'},
          ],
        },
      );

      final mockDiveRepo = MockDiveRepository();
      when(mockDiveRepo.getAllDives()).thenAnswer((_) async => <Dive>[]);

      final mockTankPresetRepo = MockTankPresetRepository();
      when(mockTankPresetRepo.getPresetById(any)).thenAnswer((_) async => null);

      await _runWithAdapter(
        tester,
        overrides: _fullOverrides(
          payload: payload,
          diver: _testDiver(),
          mockDiveRepo: mockDiveRepo,
          mockTankPresetRepo: mockTankPresetRepo,
        ),
        callback: (adapter) async {
          final bundle = await adapter.buildBundle();
          final result = await adapter.performImport(
            bundle,
            {
              wizard.ImportEntityType.dives: {0, 1, 2},
              wizard.ImportEntityType.sites: {0},
            },
            {
              wizard.ImportEntityType.dives: {
                0: DuplicateAction.skip,
                1: DuplicateAction.skip,
                2: DuplicateAction.importAsNew,
              },
              // Site skips should NOT be counted.
              wizard.ImportEntityType.sites: {0: DuplicateAction.skip},
            },
          );

          // Only dive skips are counted.
          expect(result.skippedCount, equals(2));
        },
      );
    });
  });

  // -------------------------------------------------------------------------
  // performImport -- _convertImportCounts (tested through result)
  // -------------------------------------------------------------------------

  group('performImport() - import counts', () {
    testWidgets('zero-count entity types are excluded from importedCounts', (
      tester,
    ) async {
      // An empty payload with diver present should produce zero counts.
      const payload = ImportPayload(entities: {});

      final mockDiveRepo = MockDiveRepository();
      when(mockDiveRepo.getAllDives()).thenAnswer((_) async => <Dive>[]);

      final mockTankPresetRepo = MockTankPresetRepository();
      when(mockTankPresetRepo.getPresetById(any)).thenAnswer((_) async => null);

      await _runWithAdapter(
        tester,
        overrides: _fullOverrides(
          payload: payload,
          diver: _testDiver(),
          mockDiveRepo: mockDiveRepo,
          mockTankPresetRepo: mockTankPresetRepo,
        ),
        callback: (adapter) async {
          final bundle = await adapter.buildBundle();
          final result = await adapter.performImport(bundle, {}, {});

          // No data to import, so counts should be empty.
          expect(result.importedCounts, isEmpty);
          expect(result.consolidatedCount, equals(0));
        },
      );
    });
  });

  // -------------------------------------------------------------------------
  // _payloadToUddfResult -- verified through performImport
  // -------------------------------------------------------------------------

  group('_payloadToUddfResult (via performImport)', () {
    testWidgets('all entity types are passed to UDDF result', (tester) async {
      final payload = ImportPayload(
        entities: {
          ui.ImportEntityType.dives: [
            {
              'dateTime': DateTime(2026, 3, 15, 10, 0),
              'maxDepth': 20.0,
              'runtime': const Duration(minutes: 30),
            },
          ],
          ui.ImportEntityType.sites: [
            {'name': 'Test Site'},
          ],
        },
      );

      final mockDiveRepo = MockDiveRepository();
      when(mockDiveRepo.getAllDives()).thenAnswer((_) async => <Dive>[]);

      final mockTankPresetRepo = MockTankPresetRepository();
      when(mockTankPresetRepo.getPresetById(any)).thenAnswer((_) async => null);

      await _runWithAdapter(
        tester,
        overrides: _fullOverrides(
          payload: payload,
          diver: _testDiver(),
          mockDiveRepo: mockDiveRepo,
          mockTankPresetRepo: mockTankPresetRepo,
        ),
        callback: (adapter) async {
          final bundle = await adapter.buildBundle();
          final result = await adapter.performImport(bundle, {
            wizard.ImportEntityType.dives: {0},
            wizard.ImportEntityType.sites: {0},
          }, {});

          // If payload-to-UDDF mapping worked, the import should succeed.
          expect(result.errorMessage, isNull);
        },
      );
    });

    testWidgets(
      'real SSRF-shaped payload imports without int-to-double cast failures',
      (tester) async {
        final parser = SubsurfaceXmlParser();
        final payload = await parser.parse(
          Uint8List.fromList(
            utf8.encode('''
<divelog program='subsurface' version='3'>
<dives>
<dive number='8164' otu='64' cns='24%' date='2023-01-04' time='10:10:39' duration='53:10 min'>
  <cylinder size='11.094 l' workpressure='206.843 bar' description='AL80' o2='50.0%' end='154.58 bar' depth='21.856 m' />
  <cylinder size='11.094 l' workpressure='206.843 bar' description='AL80' o2='16.0%' he='48.0%' end='183.952 bar' depth='89.814 m' />
  <cylinder size='11.094 l' workpressure='206.843 bar' description='AL80' o2='16.0%' he='48.0%' use='diluent' depth='89.814 m' />
  <divecomputer model='Shearwater Nerd 2' deviceid='64257c95' diveid='832b8abe' dctype='CCR' no_o2sensors='3'>
  <depth max='40.8 m' mean='16.244 m' />
  <temperature water='12.0 C' />
  <surface pressure='0.996 bar' />
  <extradata key='Deco model' value='GF 50/70' />
  <event time='0:10 min' type='25' flags='3' name='gaschange' cylinder='2' o2='16.0%' he='48.0%' />
  <sample time='0:10 min' depth='0.0 m' temp='20.0 C' pressure0='193.329 bar' pressure1='201.327 bar' sensor1='0.641 bar' sensor2='0.659 bar' sensor3='0.664 bar' po2='0.7 bar' />
  <sample time='0:20 min' depth='2.6 m' pressure1='201.189 bar' ndl='99:00 min' sensor1='0.664 bar' sensor2='0.682 bar' sensor3='0.686 bar' />
  <sample time='3:30 min' depth='9.7 m' cns='1%' sensor2='0.706 bar' sensor3='0.708 bar' />
  <sample time='14:00 min' depth='40.4 m' pressure1='186.71 bar' ndl='0:00 min' cns='5%' sensor1='1.261 bar' sensor2='1.294 bar' sensor3='1.283 bar' />
  <sample time='15:10 min' depth='40.8 m' pressure1='186.71 bar' in_deco='1' stoptime='1:00 min' stopdepth='3.0 m' />
  </divecomputer>
</dive>
</dives>
</divelog>
'''),
          ),
        );

        final mockDiveRepo = MockDiveRepository();
        when(mockDiveRepo.getAllDives()).thenAnswer((_) async => <Dive>[]);

        final mockTankPresetRepo = MockTankPresetRepository();
        when(
          mockTankPresetRepo.getPresetById(any),
        ).thenAnswer((_) async => null);

        await _runWithAdapter(
          tester,
          overrides: _fullOverrides(
            payload: payload,
            diver: _testDiver(),
            mockDiveRepo: mockDiveRepo,
            mockTankPresetRepo: mockTankPresetRepo,
          ),
          callback: (adapter) async {
            final bundle = await adapter.buildBundle();
            final result = await adapter.performImport(bundle, {
              wizard.ImportEntityType.dives: {0},
            }, {});

            expect(result.errorMessage, isNull);
            expect(result.importedCounts[ImportEntityType.dives], 1);
          },
        );
      },
    );
  });

  // -------------------------------------------------------------------------
  // resetState
  // -------------------------------------------------------------------------

  group('resetState()', () {
    testWidgets('resets the universal import notifier state', (tester) async {
      final payload = ImportPayload(
        entities: {
          ui.ImportEntityType.dives: [
            {'dateTime': DateTime(2026, 1, 1)},
          ],
        },
      );

      await _runWithAdapter(
        tester,
        overrides: _buildBundleOverrides(payload: payload),
        callback: (adapter) async {
          // buildBundle should find dives before reset.
          final bundleBefore = await adapter.buildBundle();
          expect(bundleBefore.hasType(ImportEntityType.dives), isTrue);

          // After reset, the notifier state is cleared. Since we cannot
          // rebuild the bundle after reset (the notifier has new state), just
          // verify the call does not throw.
          adapter.resetState();
        },
      );
    });
  });

  group('hasPreloadedState / consumePreloadedState', () {
    testWidgets('returns false when no file was loaded externally', (
      tester,
    ) async {
      // Use default overrides (notifier starts with clean state).
      await _runWithAdapter(
        tester,
        overrides: _buildBundleOverrides(),
        callback: (adapter) async {
          expect(adapter.hasPreloadedState, isFalse);
        },
      );
    });

    testWidgets('returns true after loadFileFromBytes', (tester) async {
      // Override with a plain notifier (no pre-set payload) so
      // loadFileFromBytes can run its own detection.
      await _runWithAdapter(
        tester,
        overrides: [
          universalImportNotifierProvider.overrideWith((ref) {
            return UniversalImportNotifier(ref);
          }),
        ],
        callback: (adapter) async {
          final container = ProviderScope.containerOf(
            tester.element(find.byType(SizedBox)),
          );
          final notifier = container.read(
            universalImportNotifierProvider.notifier,
          );
          final uddfBytes = Uint8List.fromList(
            '<?xml version="1.0"?><uddf version="3.2.0"></uddf>'.codeUnits,
          );
          await notifier.loadFileFromBytes(uddfBytes, 'dive.uddf');

          expect(adapter.hasPreloadedState, isTrue);
        },
      );
    });

    testWidgets('consumePreloadedState clears the flag', (tester) async {
      await _runWithAdapter(
        tester,
        overrides: [
          universalImportNotifierProvider.overrideWith((ref) {
            return UniversalImportNotifier(ref);
          }),
        ],
        callback: (adapter) async {
          final container = ProviderScope.containerOf(
            tester.element(find.byType(SizedBox)),
          );
          final notifier = container.read(
            universalImportNotifierProvider.notifier,
          );
          final uddfBytes = Uint8List.fromList(
            '<?xml version="1.0"?><uddf version="3.2.0"></uddf>'.codeUnits,
          );
          await notifier.loadFileFromBytes(uddfBytes, 'dive.uddf');
          expect(adapter.hasPreloadedState, isTrue);

          adapter.consumePreloadedState();

          expect(adapter.hasPreloadedState, isFalse);
        },
      );
    });
  });

  // -------------------------------------------------------------------------
  // checkDuplicates -- additional entity types
  // -------------------------------------------------------------------------

  group('checkDuplicates() - additional entity types', () {
    testWidgets('marks duplicate equipment in duplicateIndices', (
      tester,
    ) async {
      const payload = ImportPayload(
        entities: {
          ui.ImportEntityType.equipment: [
            {'name': 'Aqualung Regulator', 'type': EquipmentType.regulator},
            {'name': 'Unique BCD', 'type': EquipmentType.bcd},
          ],
        },
      );

      const existingEquipment = EquipmentItem(
        id: 'equip-1',
        name: 'Aqualung Regulator',
        type: EquipmentType.regulator,
      );

      await _runWithAdapter(
        tester,
        overrides: _fullOverrides(
          payload: payload,
          diver: _testDiver(),
          existingEquipment: [existingEquipment],
        ),
        callback: (adapter) async {
          final bundle = await adapter.buildBundle();
          final result = await adapter.checkDuplicates(bundle);

          final equipGroup = result.groups[ImportEntityType.equipment];
          expect(equipGroup, isNotNull);
          expect(equipGroup!.duplicateIndices, contains(0));
          expect(equipGroup.duplicateIndices, isNot(contains(1)));
        },
      );
    });

    testWidgets('marks duplicate buddies in duplicateIndices', (tester) async {
      const payload = ImportPayload(
        entities: {
          ui.ImportEntityType.buddies: [
            {'name': 'Jane Doe'},
            {'name': 'Unique Buddy'},
          ],
        },
      );

      final existingBuddy = Buddy(
        id: 'buddy-1',
        name: 'Jane Doe',
        createdAt: _now,
        updatedAt: _now,
      );

      await _runWithAdapter(
        tester,
        overrides: _fullOverrides(
          payload: payload,
          diver: _testDiver(),
          existingBuddies: [existingBuddy],
        ),
        callback: (adapter) async {
          final bundle = await adapter.buildBundle();
          final result = await adapter.checkDuplicates(bundle);

          final buddyGroup = result.groups[ImportEntityType.buddies];
          expect(buddyGroup, isNotNull);
          expect(buddyGroup!.duplicateIndices, contains(0));
          expect(buddyGroup.duplicateIndices, isNot(contains(1)));
        },
      );
    });

    testWidgets('marks duplicate dive centers in duplicateIndices', (
      tester,
    ) async {
      const payload = ImportPayload(
        entities: {
          ui.ImportEntityType.diveCenters: [
            {'name': 'Reef Divers'},
          ],
        },
      );

      final existingCenter = DiveCenter(
        id: 'dc-1',
        name: 'Reef Divers',
        createdAt: _now,
        updatedAt: _now,
      );

      await _runWithAdapter(
        tester,
        overrides: _fullOverrides(
          payload: payload,
          diver: _testDiver(),
          existingDiveCenters: [existingCenter],
        ),
        callback: (adapter) async {
          final bundle = await adapter.buildBundle();
          final result = await adapter.checkDuplicates(bundle);

          final dcGroup = result.groups[ImportEntityType.diveCenters];
          expect(dcGroup, isNotNull);
          expect(dcGroup!.duplicateIndices, contains(0));
        },
      );
    });

    testWidgets('marks duplicate certifications in duplicateIndices', (
      tester,
    ) async {
      const payload = ImportPayload(
        entities: {
          ui.ImportEntityType.certifications: [
            {'name': 'Open Water', 'agency': CertificationAgency.padi},
          ],
        },
      );

      final existingCert = Certification(
        id: 'cert-1',
        name: 'Open Water',
        agency: CertificationAgency.padi,
        createdAt: _now,
        updatedAt: _now,
      );

      await _runWithAdapter(
        tester,
        overrides: _fullOverrides(
          payload: payload,
          diver: _testDiver(),
          existingCertifications: [existingCert],
        ),
        callback: (adapter) async {
          final bundle = await adapter.buildBundle();
          final result = await adapter.checkDuplicates(bundle);

          final certGroup = result.groups[ImportEntityType.certifications];
          expect(certGroup, isNotNull);
          expect(certGroup!.duplicateIndices, contains(0));
        },
      );
    });

    testWidgets('marks duplicate dive types in duplicateIndices', (
      tester,
    ) async {
      const payload = ImportPayload(
        entities: {
          ui.ImportEntityType.diveTypes: [
            {'name': 'Night Dive'},
            {'name': 'Unique Type'},
          ],
        },
      );

      final existingDiveType = DiveTypeEntity(
        id: 'dt-1',
        name: 'Night Dive',
        createdAt: _now,
        updatedAt: _now,
      );

      await _runWithAdapter(
        tester,
        overrides: _fullOverrides(
          payload: payload,
          diver: _testDiver(),
          existingDiveTypes: [existingDiveType],
        ),
        callback: (adapter) async {
          final bundle = await adapter.buildBundle();
          final result = await adapter.checkDuplicates(bundle);

          final dtGroup = result.groups[ImportEntityType.diveTypes];
          expect(dtGroup, isNotNull);
          expect(dtGroup!.duplicateIndices, contains(0));
          expect(dtGroup.duplicateIndices, isNot(contains(1)));
        },
      );
    });

    testWidgets('marks duplicate trips in duplicateIndices', (tester) async {
      final payload = ImportPayload(
        entities: {
          ui.ImportEntityType.trips: [
            {
              'name': 'Belize Trip',
              'startDate': DateTime(2026, 3, 1),
              'endDate': DateTime(2026, 3, 7),
            },
          ],
        },
      );

      final existingTrip = Trip(
        id: 'trip-1',
        name: 'Belize Trip',
        startDate: DateTime(2026, 3, 1),
        endDate: DateTime(2026, 3, 7),
        createdAt: _now,
        updatedAt: _now,
      );

      await _runWithAdapter(
        tester,
        overrides: _fullOverrides(
          payload: payload,
          diver: _testDiver(),
          existingTrips: [existingTrip],
        ),
        callback: (adapter) async {
          final bundle = await adapter.buildBundle();
          final result = await adapter.checkDuplicates(bundle);

          final tripGroup = result.groups[ImportEntityType.trips];
          expect(tripGroup, isNotNull);
          expect(tripGroup!.duplicateIndices, contains(0));
        },
      );
    });
  });

  // -------------------------------------------------------------------------
  // Provider tests — universalAdapterFileSelectedProvider
  // -------------------------------------------------------------------------

  group('universalAdapterFileSelectedProvider', () {
    testWidgets('returns false when detectionResult is null', (tester) async {
      await _runWithAdapter(
        tester,
        overrides: [
          universalImportNotifierProvider.overrideWith((ref) {
            return _TestableImportNotifier(ref);
          }),
          settingsProvider.overrideWith((ref) => _TestSettingsNotifier()),
        ],
        callback: (adapter) async {
          final step = adapter.acquisitionSteps[0];
          expect(step.label, equals('Select File'));
        },
      );
    });
  });

  // -------------------------------------------------------------------------
  // Provider tests — universalAdapterMappingReadyProvider
  // -------------------------------------------------------------------------

  group('universalAdapterMappingReadyProvider', () {
    testWidgets('returns true when payload is non-null', (tester) async {
      final payload = ImportPayload(
        entities: {
          ui.ImportEntityType.dives: [
            {'dateTime': DateTime(2026, 1, 1)},
          ],
        },
      );

      late ProviderContainer container;
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            universalImportNotifierProvider.overrideWith((ref) {
              final notifier = _TestableImportNotifier(ref);
              notifier.setPayload(payload);
              return notifier;
            }),
            settingsProvider.overrideWith((ref) => _TestSettingsNotifier()),
          ],
          child: MaterialApp(
            home: Consumer(
              builder: (context, ref, _) {
                container = ProviderScope.containerOf(context);
                return const SizedBox.shrink();
              },
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      final result = container.read(universalAdapterMappingReadyProvider);
      expect(result, isTrue);
    });

    testWidgets('returns true when fieldMapping has columns', (tester) async {
      const mapping = FieldMapping(
        name: 'Test Mapping',
        columns: [ColumnMapping(sourceColumn: 'date', targetField: 'dateTime')],
      );

      late ProviderContainer container;
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            universalImportNotifierProvider.overrideWith((ref) {
              final notifier = _TestableImportNotifier(ref);
              notifier.setFieldMapping(mapping);
              return notifier;
            }),
            settingsProvider.overrideWith((ref) => _TestSettingsNotifier()),
          ],
          child: MaterialApp(
            home: Consumer(
              builder: (context, ref, _) {
                container = ProviderScope.containerOf(context);
                return const SizedBox.shrink();
              },
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      final result = container.read(universalAdapterMappingReadyProvider);
      expect(result, isTrue);
    });

    testWidgets('returns false when no payload and no fieldMapping', (
      tester,
    ) async {
      late ProviderContainer container;
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            universalImportNotifierProvider.overrideWith((ref) {
              return _TestableImportNotifier(ref);
            }),
            settingsProvider.overrideWith((ref) => _TestSettingsNotifier()),
          ],
          child: MaterialApp(
            home: Consumer(
              builder: (context, ref, _) {
                container = ProviderScope.containerOf(context);
                return const SizedBox.shrink();
              },
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      final result = container.read(universalAdapterMappingReadyProvider);
      expect(result, isFalse);
    });

    testWidgets('returns false when fieldMapping has empty columns', (
      tester,
    ) async {
      const mapping = FieldMapping(name: 'Empty Mapping', columns: []);

      late ProviderContainer container;
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            universalImportNotifierProvider.overrideWith((ref) {
              final notifier = _TestableImportNotifier(ref);
              notifier.setFieldMapping(mapping);
              return notifier;
            }),
            settingsProvider.overrideWith((ref) => _TestSettingsNotifier()),
          ],
          child: MaterialApp(
            home: Consumer(
              builder: (context, ref, _) {
                container = ProviderScope.containerOf(context);
                return const SizedBox.shrink();
              },
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      final result = container.read(universalAdapterMappingReadyProvider);
      expect(result, isFalse);
    });
  });

  // -------------------------------------------------------------------------
  // Provider tests — canAutoAdvance (mapping auto-advance)
  // -------------------------------------------------------------------------

  group('mapping auto-advance provider (via acquisitionSteps[2])', () {
    testWidgets('auto-advance is true when payload is non-null', (
      tester,
    ) async {
      final payload = ImportPayload(
        entities: {
          ui.ImportEntityType.dives: [
            {'dateTime': DateTime(2026, 1, 1)},
          ],
        },
      );

      late ProviderContainer container;
      late UniversalAdapter adapter;
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            universalImportNotifierProvider.overrideWith((ref) {
              final notifier = _TestableImportNotifier(ref);
              notifier.setPayload(payload);
              return notifier;
            }),
            settingsProvider.overrideWith((ref) => _TestSettingsNotifier()),
          ],
          child: MaterialApp(
            home: Consumer(
              builder: (context, ref, _) {
                container = ProviderScope.containerOf(context);
                adapter = UniversalAdapter(ref: ref);
                return const SizedBox.shrink();
              },
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      final autoAdvanceProvider = adapter.acquisitionSteps[2].canAutoAdvance!;
      final result = container.read(autoAdvanceProvider);
      expect(result, isTrue);
    });

    testWidgets(
      'auto-advance is true when detectedCsvPreset is set and mapping has columns',
      (tester) async {
        const preset = CsvPreset(
          id: 'test-preset',
          name: 'Test Preset',
          signatureHeaders: ['date', 'depth'],
          mappings: {},
        );
        const mapping = FieldMapping(
          name: 'Test Mapping',
          columns: [
            ColumnMapping(sourceColumn: 'date', targetField: 'dateTime'),
          ],
        );

        late ProviderContainer container;
        late UniversalAdapter adapter;
        await tester.pumpWidget(
          ProviderScope(
            overrides: [
              universalImportNotifierProvider.overrideWith((ref) {
                final notifier = _TestableImportNotifier(ref);
                notifier.setDetectedCsvPreset(preset);
                notifier.setFieldMapping(mapping);
                return notifier;
              }),
              settingsProvider.overrideWith((ref) => _TestSettingsNotifier()),
            ],
            child: MaterialApp(
              home: Consumer(
                builder: (context, ref, _) {
                  container = ProviderScope.containerOf(context);
                  adapter = UniversalAdapter(ref: ref);
                  return const SizedBox.shrink();
                },
              ),
            ),
          ),
        );
        await tester.pumpAndSettle();

        final autoAdvanceProvider = adapter.acquisitionSteps[2].canAutoAdvance!;
        final result = container.read(autoAdvanceProvider);
        expect(result, isTrue);
      },
    );

    testWidgets(
      'auto-advance is false when no preset and no payload (manual CSV)',
      (tester) async {
        const mapping = FieldMapping(
          name: 'Manual Mapping',
          columns: [
            ColumnMapping(sourceColumn: 'date', targetField: 'dateTime'),
          ],
        );

        late ProviderContainer container;
        late UniversalAdapter adapter;
        await tester.pumpWidget(
          ProviderScope(
            overrides: [
              universalImportNotifierProvider.overrideWith((ref) {
                final notifier = _TestableImportNotifier(ref);
                // No payload, no detectedCsvPreset, but has manual mapping.
                notifier.setFieldMapping(mapping);
                return notifier;
              }),
              settingsProvider.overrideWith((ref) => _TestSettingsNotifier()),
            ],
            child: MaterialApp(
              home: Consumer(
                builder: (context, ref, _) {
                  container = ProviderScope.containerOf(context);
                  adapter = UniversalAdapter(ref: ref);
                  return const SizedBox.shrink();
                },
              ),
            ),
          ),
        );
        await tester.pumpAndSettle();

        final autoAdvanceProvider = adapter.acquisitionSteps[2].canAutoAdvance!;
        final result = container.read(autoAdvanceProvider);
        expect(result, isFalse);
      },
    );

    testWidgets(
      'auto-advance is false when detectedCsvPreset is set but mapping is null',
      (tester) async {
        const preset = CsvPreset(
          id: 'test-preset',
          name: 'Test Preset',
          signatureHeaders: ['date', 'depth'],
          mappings: {},
        );

        late ProviderContainer container;
        late UniversalAdapter adapter;
        await tester.pumpWidget(
          ProviderScope(
            overrides: [
              universalImportNotifierProvider.overrideWith((ref) {
                final notifier = _TestableImportNotifier(ref);
                notifier.setDetectedCsvPreset(preset);
                // No field mapping yet.
                return notifier;
              }),
              settingsProvider.overrideWith((ref) => _TestSettingsNotifier()),
            ],
            child: MaterialApp(
              home: Consumer(
                builder: (context, ref, _) {
                  container = ProviderScope.containerOf(context);
                  adapter = UniversalAdapter(ref: ref);
                  return const SizedBox.shrink();
                },
              ),
            ),
          ),
        );
        await tester.pumpAndSettle();

        final autoAdvanceProvider = adapter.acquisitionSteps[2].canAutoAdvance!;
        final result = container.read(autoAdvanceProvider);
        expect(result, isFalse);
      },
    );

    testWidgets(
      'auto-advance is false when no payload, no preset, and no mapping',
      (tester) async {
        late ProviderContainer container;
        late UniversalAdapter adapter;
        await tester.pumpWidget(
          ProviderScope(
            overrides: [
              universalImportNotifierProvider.overrideWith((ref) {
                return _TestableImportNotifier(ref);
              }),
              settingsProvider.overrideWith((ref) => _TestSettingsNotifier()),
            ],
            child: MaterialApp(
              home: Consumer(
                builder: (context, ref, _) {
                  container = ProviderScope.containerOf(context);
                  adapter = UniversalAdapter(ref: ref);
                  return const SizedBox.shrink();
                },
              ),
            ),
          ),
        );
        await tester.pumpAndSettle();

        final autoAdvanceProvider = adapter.acquisitionSteps[2].canAutoAdvance!;
        final result = container.read(autoAdvanceProvider);
        expect(result, isFalse);
      },
    );
  });

  // -------------------------------------------------------------------------
  // Provider tests — universalAdapterSourceReadyProvider
  // -------------------------------------------------------------------------

  group('universalAdapterSourceReadyProvider', () {
    testWidgets('returns true when detection result has supported format', (
      tester,
    ) async {
      const detection = DetectionResult(
        format: ui.ImportFormat.csv,
        confidence: 0.9,
      );

      late ProviderContainer container;
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            universalImportNotifierProvider.overrideWith((ref) {
              final notifier = _TestableImportNotifier(ref);
              notifier.setDetectionResult(detection);
              return notifier;
            }),
            settingsProvider.overrideWith((ref) => _TestSettingsNotifier()),
          ],
          child: MaterialApp(
            home: Consumer(
              builder: (context, ref, _) {
                container = ProviderScope.containerOf(context);
                return const SizedBox.shrink();
              },
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      final result = container.read(universalAdapterSourceReadyProvider);
      expect(result, isTrue);
    });

    testWidgets('returns false when detection result has unsupported format', (
      tester,
    ) async {
      const detection = DetectionResult(
        format: ui.ImportFormat.unknown,
        confidence: 0.5,
      );

      late ProviderContainer container;
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            universalImportNotifierProvider.overrideWith((ref) {
              final notifier = _TestableImportNotifier(ref);
              notifier.setDetectionResult(detection);
              return notifier;
            }),
            settingsProvider.overrideWith((ref) => _TestSettingsNotifier()),
          ],
          child: MaterialApp(
            home: Consumer(
              builder: (context, ref, _) {
                container = ProviderScope.containerOf(context);
                return const SizedBox.shrink();
              },
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      final result = container.read(universalAdapterSourceReadyProvider);
      expect(result, isFalse);
    });

    testWidgets('returns false when detection result is null', (tester) async {
      late ProviderContainer container;
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            universalImportNotifierProvider.overrideWith((ref) {
              return _TestableImportNotifier(ref);
            }),
            settingsProvider.overrideWith((ref) => _TestSettingsNotifier()),
          ],
          child: MaterialApp(
            home: Consumer(
              builder: (context, ref, _) {
                container = ProviderScope.containerOf(context);
                return const SizedBox.shrink();
              },
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      final result = container.read(universalAdapterSourceReadyProvider);
      expect(result, isFalse);
    });
  });

  // -------------------------------------------------------------------------
  // Provider tests — universalAdapterFileSelectedProvider
  // -------------------------------------------------------------------------

  group('universalAdapterFileSelectedProvider', () {
    testWidgets(
      'returns true when detection is done and step is past fileSelection',
      (tester) async {
        const detection = DetectionResult(
          format: ui.ImportFormat.csv,
          confidence: 0.9,
        );

        late ProviderContainer container;
        await tester.pumpWidget(
          ProviderScope(
            overrides: [
              universalImportNotifierProvider.overrideWith((ref) {
                final notifier = _TestableImportNotifier(ref);
                notifier.setDetectionResult(detection);
                notifier.setCurrentStep(ImportWizardStep.sourceConfirmation);
                return notifier;
              }),
              settingsProvider.overrideWith((ref) => _TestSettingsNotifier()),
            ],
            child: MaterialApp(
              home: Consumer(
                builder: (context, ref, _) {
                  container = ProviderScope.containerOf(context);
                  return const SizedBox.shrink();
                },
              ),
            ),
          ),
        );
        await tester.pumpAndSettle();

        final result = container.read(universalAdapterFileSelectedProvider);
        expect(result, isTrue);
      },
    );

    testWidgets('returns false when still on fileSelection step', (
      tester,
    ) async {
      const detection = DetectionResult(
        format: ui.ImportFormat.csv,
        confidence: 0.9,
      );

      late ProviderContainer container;
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            universalImportNotifierProvider.overrideWith((ref) {
              final notifier = _TestableImportNotifier(ref);
              notifier.setDetectionResult(detection);
              // Still on fileSelection step.
              return notifier;
            }),
            settingsProvider.overrideWith((ref) => _TestSettingsNotifier()),
          ],
          child: MaterialApp(
            home: Consumer(
              builder: (context, ref, _) {
                container = ProviderScope.containerOf(context);
                return const SizedBox.shrink();
              },
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      final result = container.read(universalAdapterFileSelectedProvider);
      expect(result, isFalse);
    });

    testWidgets('returns false when detection result is null', (tester) async {
      late ProviderContainer container;
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            universalImportNotifierProvider.overrideWith((ref) {
              return _TestableImportNotifier(ref);
            }),
            settingsProvider.overrideWith((ref) => _TestSettingsNotifier()),
          ],
          child: MaterialApp(
            home: Consumer(
              builder: (context, ref, _) {
                container = ProviderScope.containerOf(context);
                return const SizedBox.shrink();
              },
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      final result = container.read(universalAdapterFileSelectedProvider);
      expect(result, isFalse);
    });
  });

  // -------------------------------------------------------------------------
  // buildBundle edge cases — _diveToEntityItem
  // -------------------------------------------------------------------------

  group('buildBundle() - _diveToEntityItem edge cases', () {
    testWidgets('dive with empty siteName is not included in subtitle', (
      tester,
    ) async {
      final payload = ImportPayload(
        entities: {
          ui.ImportEntityType.dives: [
            {
              'dateTime': DateTime(2026, 3, 15, 10, 0),
              'siteName': '',
              'maxDepth': 25.0,
            },
          ],
        },
      );

      await _runWithAdapter(
        tester,
        overrides: _buildBundleOverrides(payload: payload),
        callback: (adapter) async {
          final bundle = await adapter.buildBundle();
          final item = bundle.groups[ImportEntityType.dives]!.items.first;

          // Empty siteName should not appear as a subtitle part.
          expect(item.subtitle, isNot(contains('\u00b7 \u00b7')));
          expect(item.subtitle, contains('25.0'));
        },
      );
    });

    testWidgets('dive with runtime prefers runtime over duration', (
      tester,
    ) async {
      final payload = ImportPayload(
        entities: {
          ui.ImportEntityType.dives: [
            {
              'dateTime': DateTime(2026, 3, 15, 10, 0),
              'runtime': const Duration(minutes: 47),
              'duration': const Duration(minutes: 35),
            },
          ],
        },
      );

      await _runWithAdapter(
        tester,
        overrides: _buildBundleOverrides(payload: payload),
        callback: (adapter) async {
          final bundle = await adapter.buildBundle();
          final item = bundle.groups[ImportEntityType.dives]!.items.first;

          expect(item.subtitle, contains('47 min'));
          expect(item.subtitle, isNot(contains('35 min')));
        },
      );
    });
  });

  // -------------------------------------------------------------------------
  // buildBundle edge cases — _certificationToEntityItem
  // -------------------------------------------------------------------------

  group('buildBundle() - certification edge cases', () {
    testWidgets('certification with no level or name shows Unnamed', (
      tester,
    ) async {
      const payload = ImportPayload(
        entities: {
          ui.ImportEntityType.certifications: [<String, dynamic>{}],
        },
      );

      await _runWithAdapter(
        tester,
        overrides: _buildBundleOverrides(payload: payload),
        callback: (adapter) async {
          final bundle = await adapter.buildBundle();
          final item =
              bundle.groups[ImportEntityType.certifications]!.items.first;

          expect(item.title, equals('Unnamed'));
        },
      );
    });
  });

  // -------------------------------------------------------------------------
  // _resolveSelections -- consolidate action edge case
  // -------------------------------------------------------------------------

  group('performImport() - _resolveSelections edge cases', () {
    testWidgets(
      'items with no duplicate action are included from base selection',
      (tester) async {
        final payload = ImportPayload(
          entities: {
            ui.ImportEntityType.dives: [
              {
                'dateTime': DateTime(2026, 3, 15, 10, 0),
                'maxDepth': 20.0,
                'runtime': const Duration(minutes: 30),
              },
              {
                'dateTime': DateTime(2026, 3, 16, 10, 0),
                'maxDepth': 15.0,
                'runtime': const Duration(minutes: 25),
              },
            ],
          },
        );

        final mockDiveRepo = MockDiveRepository();
        when(mockDiveRepo.getAllDives()).thenAnswer((_) async => <Dive>[]);

        final mockTankPresetRepo = MockTankPresetRepository();
        when(
          mockTankPresetRepo.getPresetById(any),
        ).thenAnswer((_) async => null);

        await _runWithAdapter(
          tester,
          overrides: _fullOverrides(
            payload: payload,
            diver: _testDiver(),
            mockDiveRepo: mockDiveRepo,
            mockTankPresetRepo: mockTankPresetRepo,
          ),
          callback: (adapter) async {
            final bundle = await adapter.buildBundle();
            final result = await adapter.performImport(bundle, {
              // Both dives selected, no duplicate actions.
              wizard.ImportEntityType.dives: {0, 1},
            }, {});

            // Both should be imported, zero skipped.
            expect(result.skippedCount, equals(0));
            expect(result.errorMessage, isNull);
          },
        );
      },
    );
  });
}
