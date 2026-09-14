import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/legacy.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mockito/mockito.dart';

import 'package:submersion/core/constants/map_style.dart';
import 'package:submersion/features/buddies/presentation/providers/buddy_providers.dart';
import 'package:submersion/features/certifications/presentation/providers/certification_providers.dart';
import 'package:submersion/features/dive_centers/presentation/providers/dive_center_providers.dart';
import 'package:submersion/features/dive_import/domain/services/dive_matcher.dart';
import 'package:submersion/features/dive_log/data/repositories/dive_repository_impl.dart';
import 'package:submersion/features/import_wizard/domain/models/duplicate_action.dart';
import 'package:submersion/features/dive_log/presentation/providers/dive_providers.dart';
import 'package:submersion/features/dive_sites/data/repositories/site_repository_impl.dart';
import 'package:submersion/features/dive_sites/domain/entities/dive_site.dart';
import 'package:submersion/features/dive_sites/presentation/providers/site_providers.dart';
import 'package:submersion/features/dive_types/presentation/providers/dive_type_providers.dart';
import 'package:submersion/features/divers/data/repositories/diver_repository.dart';
import 'package:submersion/features/divers/domain/entities/diver.dart';
import 'package:submersion/features/divers/presentation/providers/diver_providers.dart';
import 'package:submersion/features/equipment/presentation/providers/equipment_providers.dart';
import 'package:submersion/features/import_wizard/data/adapters/universal_adapter.dart';
import 'package:submersion/features/import_wizard/domain/models/import_bundle.dart';
import 'package:submersion/features/settings/presentation/providers/settings_providers.dart';
import 'package:submersion/features/tags/presentation/providers/tag_providers.dart';
import 'package:submersion/features/tank_presets/presentation/providers/tank_preset_providers.dart';
import 'package:submersion/features/trips/presentation/providers/trip_providers.dart';
import 'package:submersion/features/universal_import/data/models/diver_target.dart';
import 'package:submersion/features/universal_import/data/models/import_enums.dart'
    as ui;
import 'package:submersion/features/universal_import/data/models/import_payload.dart';
import 'package:submersion/features/universal_import/data/models/source_diver.dart';
import 'package:submersion/features/universal_import/presentation/providers/universal_import_providers.dart';

import '../../../../helpers/test_database.dart';
import 'universal_adapter_test.mocks.dart';

final _now = DateTime(2026);

Diver _diver(String id, String name) =>
    Diver(id: id, name: name, createdAt: _now, updatedAt: _now);

class _TestSettingsNotifier extends StateNotifier<AppSettings>
    implements SettingsNotifier {
  _TestSettingsNotifier() : super(const AppSettings());

  @override
  Future<void> setMapStyle(MapStyle style) async =>
      state = state.copyWith(mapStyle: style);

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

/// Blue Hole goes to the active profile (diver-1) and to diver-2.
const _twoProfiles = ImportPayload(
  entities: {
    ui.ImportEntityType.sites: [
      {
        'name': 'Blue Hole',
        'uddfId': 'Blue Hole',
        DiverTarget.itemKey: 'diver:diver-1',
      },
      {
        'name': 'Blue Hole',
        'uddfId': 'Blue Hole',
        DiverTarget.itemKey: 'diver:diver-2',
      },
    ],
  },
);

Future<UniversalAdapter> _adapter(
  WidgetTester tester, {
  required ImportPayload payload,
  List<DiveSite> activeSites = const [],
  required MockSiteRepository siteRepo,
}) async {
  final diveRepo = MockDiveRepository();
  when(
    diveRepo.getAllDives(diverId: anyNamed('diverId')),
  ).thenAnswer((_) async => []);
  late UniversalAdapter adapter;
  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        universalImportNotifierProvider.overrideWith((ref) {
          final notifier = UniversalImportNotifier(ref);
          notifier.state = notifier.state.copyWith(payload: payload);
          return notifier;
        }),
        settingsProvider.overrideWith((ref) => _TestSettingsNotifier()),
        currentDiverProvider.overrideWith(
          (ref) async => _diver('diver-1', 'Test Diver'),
        ),
        allDiversProvider.overrideWith(
          (ref) async => [
            _diver('diver-1', 'Test Diver'),
            _diver('diver-2', 'Other'),
          ],
        ),
        diveRepositoryProvider.overrideWithValue(diveRepo),
        siteRepositoryProvider.overrideWithValue(siteRepo),
        tripRepositoryProvider.overrideWithValue(MockTripRepository()),
        equipmentRepositoryProvider.overrideWithValue(
          MockEquipmentRepository(),
        ),
        buddyRepositoryProvider.overrideWithValue(MockBuddyRepository()),
        diveCenterRepositoryProvider.overrideWithValue(
          MockDiveCenterRepository(),
        ),
        certificationRepositoryProvider.overrideWithValue(
          MockCertificationRepository(),
        ),
        tagRepositoryProvider.overrideWithValue(MockTagRepository()),
        diveTypeRepositoryProvider.overrideWithValue(MockDiveTypeRepository()),
        // The active profile still reads through these providers.
        allTripsProvider.overrideWith((ref) async => []),
        sitesProvider.overrideWith((ref) async => activeSites),
        allEquipmentProvider.overrideWith((ref) async => []),
        allBuddiesProvider.overrideWith((ref) async => []),
        allDiveCentersProvider.overrideWith((ref) async => []),
        allCertificationsProvider.overrideWith((ref) async => []),
        tagsProvider.overrideWith((ref) async => []),
        diveTypesProvider.overrideWith((ref) async => []),
      ],
      child: MaterialApp(
        home: Consumer(
          builder: (context, ref, _) {
            adapter = UniversalAdapter(ref: ref);
            return const SizedBox.shrink();
          },
        ),
      ),
    ),
  );
  await tester.pumpAndSettle();
  return adapter;
}

void main() {
  group('checkDuplicates per profile (#1893)', () {
    testWidgets('a site the active profile has is a duplicate only there', (
      tester,
    ) async {
      final siteRepo = MockSiteRepository();
      when(
        siteRepo.getAllSites(diverId: 'diver-2'),
      ).thenAnswer((_) async => []);
      final adapter = await _adapter(
        tester,
        payload: _twoProfiles,
        siteRepo: siteRepo,
        activeSites: const [DiveSite(id: 's1', name: 'Blue Hole')],
      );

      final bundle = await adapter.checkDuplicates(await adapter.buildBundle());
      expect(bundle.groups[ImportEntityType.sites]!.duplicateIndices, {0});
    });

    testWidgets('another profile is checked against its own records', (
      tester,
    ) async {
      final siteRepo = MockSiteRepository();
      when(
        siteRepo.getAllSites(diverId: 'diver-2'),
      ).thenAnswer((_) async => const [DiveSite(id: 's2', name: 'Blue Hole')]);
      final adapter = await _adapter(
        tester,
        payload: _twoProfiles,
        siteRepo: siteRepo,
      );

      final bundle = await adapter.checkDuplicates(await adapter.buildBundle());
      expect(bundle.groups[ImportEntityType.sites]!.duplicateIndices, {1});
      verify(siteRepo.getAllSites(diverId: 'diver-2')).called(1);
      verifyNever(siteRepo.getAllSites(diverId: null));
    });
  });

  group('a profile the import never reached (#1893 review)', () {
    const match = DiveMatchResult(
      diveId: 'existing',
      score: 0.9,
      timeDifferenceMs: 0,
    );

    test('keeps no photo target through its duplicates', () {
      final reached = UniversalAdapter.reachedDiveReview(
        actions: const {1: DuplicateAction.skip, 2: DuplicateAction.skip},
        matches: const {1: match, 2: match},
        unreached: const {2},
      );
      final targets = UniversalAdapter.photoTargetDiveIds(
        diveIdByIndex: const {0: 'new-0'},
        matchResults: reached.matches,
        duplicateActions: reached.actions,
      );
      // Dive 1's profile ran, so its skipped duplicate still sends photos to
      // the dive it matched; dive 2's profile never ran, so it sends none.
      expect(targets, {0: 'new-0', 1: 'existing'});
    });
  });

  group('performImport per profile (#1893)', () {
    /// One dive and one Blue Hole for the active profile (diver-1), the same
    /// for a profile the import creates for Bo, plus optional extra dives.
    ImportPayload payload({List<Map<String, dynamic>> extraDives = const []}) =>
        ImportPayload(
          entities: {
            ui.ImportEntityType.dives: [
              {
                'dateTime': DateTime(2026, 3, 15, 10),
                'maxDepth': 20.0,
                'runtime': const Duration(minutes: 30),
                'site': {'uddfId': 'Blue Hole'},
                DiverTarget.itemKey: 'diver:diver-1',
              },
              {
                'dateTime': DateTime(2026, 3, 16, 10),
                'maxDepth': 18.0,
                'runtime': const Duration(minutes: 40),
                'site': {'uddfId': 'Blue Hole'},
                DiverTarget.itemKey: 'new:macdive:bo',
              },
              ...extraDives,
            ],
            ui.ImportEntityType.sites: [
              {
                'name': 'Blue Hole',
                'uddfId': 'Blue Hole',
                DiverTarget.itemKey: 'diver:diver-1',
              },
              {
                'name': 'Blue Hole',
                'uddfId': 'Blue Hole',
                DiverTarget.itemKey: 'new:macdive:bo',
              },
            ],
          },
          sourceDivers: const [
            SourceDiver(
              key: 'macdive:bo',
              name: 'Bo Ray',
              diveCount: 1,
              email: 'bo@example.com',
              danNumber: 'DAN-9',
            ),
          ],
        );

    Future<UniversalAdapter> realAdapter(
      WidgetTester tester,
      ImportPayload payload,
    ) async {
      final tankPresets = MockTankPresetRepository();
      when(tankPresets.getPresetById(any)).thenAnswer((_) async => null);
      late UniversalAdapter adapter;
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            universalImportNotifierProvider.overrideWith((ref) {
              final notifier = UniversalImportNotifier(ref);
              notifier.state = notifier.state.copyWith(payload: payload);
              return notifier;
            }),
            settingsProvider.overrideWith((ref) => _TestSettingsNotifier()),
            currentDiverProvider.overrideWith(
              (ref) async => _diver('diver-1', 'Test Diver'),
            ),
            tankPresetRepositoryProvider.overrideWithValue(tankPresets),
          ],
          child: MaterialApp(
            home: Consumer(
              builder: (context, ref, _) {
                adapter = UniversalAdapter(ref: ref);
                return const SizedBox.shrink();
              },
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      return adapter;
    }

    setUp(() async {
      await setUpTestDatabase();
    });
    tearDown(tearDownTestDatabase);

    testWidgets('writes each slice to its own profile, creating Bo', (
      tester,
    ) async {
      await tester.runAsync(
        () => DiverRepository().createDiver(_diver('diver-1', 'Test Diver')),
      );
      final adapter = await realAdapter(tester, payload());

      final result = (await tester.runAsync(() async {
        final bundle = await adapter.buildBundle();
        return adapter.performImport(bundle, {
          ImportEntityType.dives: {0, 1},
          ImportEntityType.sites: {0, 1},
        }, {});
      }))!;

      expect(result.errorMessage, isNull);
      expect(result.diverOutcomes.map((o) => o.name), ['Test Diver', 'Bo Ray']);
      expect(result.diverOutcomes.map((o) => o.isNew), [false, true]);

      final check = (await tester.runAsync(() async {
        final divers = await DiverRepository().getAllDivers();
        final bo = divers.singleWhere((d) => d.name == 'Bo Ray');
        return (
          bo: bo,
          mine: await DiveRepository().getAllDives(diverId: 'diver-1'),
          bos: await DiveRepository().getAllDives(diverId: bo.id),
          mySites: await SiteRepository().getAllSites(diverId: 'diver-1'),
          boSites: await SiteRepository().getAllSites(diverId: bo.id),
        );
      }))!;
      expect(check.bo.email, 'bo@example.com');
      expect(check.bo.insurance.provider, 'DAN');
      expect(check.bo.insurance.policyNumber, 'DAN-9');
      expect(check.mine, hasLength(1));
      expect(check.bos, hasLength(1));
      expect(check.mySites.map((s) => s.name), contains('Blue Hole'));
      expect(check.boSites.map((s) => s.name), ['Blue Hole']);
      // Only the active profile's dives, which "View Dives" can open.
      expect(result.importedDiveIds, [check.mine.single.id]);
    });

    testWidgets('a profile whose items are all deselected is not created', (
      tester,
    ) async {
      await tester.runAsync(
        () => DiverRepository().createDiver(_diver('diver-1', 'Test Diver')),
      );
      final adapter = await realAdapter(tester, payload());

      final result = (await tester.runAsync(() async {
        final bundle = await adapter.buildBundle();
        return adapter.performImport(bundle, {
          ImportEntityType.dives: {0},
          ImportEntityType.sites: {0},
        }, {});
      }))!;

      expect(result.diverOutcomes.map((o) => o.name), ['Test Diver']);
      final divers = (await tester.runAsync(DiverRepository().getAllDivers))!;
      expect(divers.map((d) => d.name), isNot(contains('Bo Ray')));
    });

    testWidgets('a failing later slice keeps what the earlier one imported', (
      tester,
    ) async {
      await tester.runAsync(
        () => DiverRepository().createDiver(_diver('diver-1', 'Test Diver')),
      );
      // A new-profile target with no source diver behind it cannot be created.
      final adapter = await realAdapter(
        tester,
        payload(
          extraDives: [
            {
              'dateTime': DateTime(2026, 3, 17, 10),
              'maxDepth': 10.0,
              'runtime': const Duration(minutes: 20),
              DiverTarget.itemKey: 'new:macdive:ghost',
            },
          ],
        ),
      );

      final result = (await tester.runAsync(() async {
        final bundle = await adapter.buildBundle();
        return adapter.performImport(bundle, {
          ImportEntityType.dives: {0, 2},
          ImportEntityType.sites: {0},
        }, {});
      }))!;

      expect(result.errorMessage, contains('macdive:ghost'));
      expect(result.diverOutcomes.map((o) => o.name), ['Test Diver']);
      final mine = (await tester.runAsync(
        () => DiveRepository().getAllDives(diverId: 'diver-1'),
      ))!;
      expect(mine, hasLength(1));
    });
  });
}
