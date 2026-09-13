import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/legacy.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mockito/mockito.dart';

import 'package:submersion/core/constants/map_style.dart';
import 'package:submersion/features/buddies/presentation/providers/buddy_providers.dart';
import 'package:submersion/features/certifications/presentation/providers/certification_providers.dart';
import 'package:submersion/features/dive_centers/presentation/providers/dive_center_providers.dart';
import 'package:submersion/features/dive_log/presentation/providers/dive_providers.dart';
import 'package:submersion/features/dive_sites/domain/entities/dive_site.dart';
import 'package:submersion/features/dive_sites/presentation/providers/site_providers.dart';
import 'package:submersion/features/dive_types/presentation/providers/dive_type_providers.dart';
import 'package:submersion/features/divers/domain/entities/diver.dart';
import 'package:submersion/features/divers/presentation/providers/diver_providers.dart';
import 'package:submersion/features/equipment/presentation/providers/equipment_providers.dart';
import 'package:submersion/features/import_wizard/data/adapters/universal_adapter.dart';
import 'package:submersion/features/import_wizard/domain/models/import_bundle.dart';
import 'package:submersion/features/settings/presentation/providers/settings_providers.dart';
import 'package:submersion/features/tags/presentation/providers/tag_providers.dart';
import 'package:submersion/features/trips/presentation/providers/trip_providers.dart';
import 'package:submersion/features/universal_import/data/models/diver_target.dart';
import 'package:submersion/features/universal_import/data/models/import_enums.dart'
    as ui;
import 'package:submersion/features/universal_import/data/models/import_payload.dart';
import 'package:submersion/features/universal_import/presentation/providers/universal_import_providers.dart';

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
}
