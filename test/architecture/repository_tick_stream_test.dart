import 'package:drift/drift.dart' show Value;
import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/core/data/repositories/connected_accounts_repository.dart';
import 'package:submersion/core/database/database.dart';
import 'package:submersion/features/cylinder_configs/data/repositories/cylinder_config_repository.dart';
import 'package:submersion/features/dive_log/data/repositories/dive_computer_repository_impl.dart';
import 'package:submersion/features/dive_log/data/repositories/dive_repository_impl.dart';
import 'package:submersion/features/dive_log/data/repositories/dive_custom_field_repository.dart';
import 'package:submersion/features/dive_log/data/repositories/view_config_repository.dart';
import 'package:submersion/features/equipment/data/repositories/service_kind_repository.dart';
import 'package:submersion/features/equipment/data/repositories/service_record_repository.dart';
import 'package:submersion/features/equipment/data/repositories/service_schedule_repository.dart';
import 'package:submersion/features/maps/data/repositories/offline_map_repository.dart';
import 'package:submersion/features/media/data/repositories/manifest_subscription_repository.dart';
import 'package:submersion/features/media/data/repositories/media_library_repository.dart';
import 'package:submersion/features/media/data/repositories/media_repository.dart';
import 'package:submersion/features/media_store/data/media_stores_repository.dart';
import 'package:submersion/features/settings/data/repositories/app_settings_repository.dart';
import 'package:submersion/features/statistics/data/repositories/statistics_repository.dart';
import 'package:submersion/features/trips/data/repositories/itinerary_day_repository.dart';
import 'package:submersion/features/trips/data/repositories/liveaboard_details_repository.dart';
import 'package:submersion/features/universal_import/data/repositories/csv_preset_repository.dart';
import 'package:submersion/features/weight_planner/data/repositories/weight_history_repository.dart';

import '../helpers/test_database.dart';

/// Guards the change-tick streams provider reactivity depends on (issue #974).
///
/// A tick is only useful if it fires for every table its callers actually read.
/// A stream that names the wrong table is silently inert: the provider
/// subscribes, nothing ever emits, and the staleness the tick was added to fix
/// returns with no test failing. These write to a watched table and assert the
/// stream emits, so a mis-targeted tick cannot pass.
///
/// Note a delete on an empty table does NOT notify -- Drift's update
/// notification is driven by rows actually written -- so every case here
/// inserts.
///
/// The cases that earn their place are the non-obvious ones, where the tick
/// deliberately watches a table other than the repository's headline one:
/// statistics over `dive_tanks`, schedules over `diver_settings`, custom
/// fields over `dives`, subscriptions over the per-device state table. Those
/// are exactly the couplings a future edit is most likely to drop.
void main() {
  late AppDatabase db;

  /// Epoch millis, matching how this schema stores every timestamp.
  final now = DateTime.utc(2026, 3, 28).millisecondsSinceEpoch;

  setUp(() async {
    db = await setUpTestDatabase();
  });

  tearDown(() async {
    await tearDownTestDatabase();
  });

  /// Inserts the parent rows the child-table cases below reference.
  ///
  /// Foreign keys are enforced in these tests, so a child insert without its
  /// parent fails on the constraint rather than on the tick under test.
  Future<void> seedParents() async {
    await db
        .into(db.divers)
        .insert(
          DiversCompanion.insert(
            id: 'diver-1',
            name: 'Test Diver',
            createdAt: now,
            updatedAt: now,
          ),
        );
    await db
        .into(db.equipment)
        .insert(
          EquipmentCompanion.insert(
            id: 'e1',
            name: 'Reg',
            type: 'regulator',
            createdAt: now,
            updatedAt: now,
          ),
        );
    await db
        .into(db.cylinderConfigs)
        .insert(
          CylinderConfigsCompanion.insert(
            id: 'c1',
            name: 'Sidemount',
            createdAt: now,
            updatedAt: now,
          ),
        );
    await db
        .into(db.trips)
        .insert(
          TripsCompanion.insert(
            id: 't1',
            name: 'Red Sea 2026',
            startDate: now,
            endDate: now,
            createdAt: now,
            updatedAt: now,
          ),
        );
    await db
        .into(db.mediaSubscriptions)
        .insert(
          MediaSubscriptionsCompanion.insert(
            id: 's1',
            manifestUrl: 'https://example.test/manifest.json',
            format: 'json',
            createdAt: now,
            updatedAt: now,
          ),
        );
  }

  /// Subscribes to [tick], runs [write], and reports whether the stream fired.
  ///
  /// Polls rather than sleeping a fixed span so the debounced ticks (300 ms)
  /// and the un-debounced majority share one helper without every case paying
  /// the worst-case wait.
  Future<bool> fires(Stream<void> tick, Future<void> Function() write) async {
    var fired = false;
    final sub = tick.listen((_) => fired = true);
    addTearDown(sub.cancel);

    await write();
    for (var i = 0; i < 150 && !fired; i++) {
      await Future<void>.delayed(const Duration(milliseconds: 10));
    }
    return fired;
  }

  /// Subscribes to [tick] and reports whether it emitted with NO write at all.
  ///
  /// The other half of the contract, and the half nothing checked before
  /// #1175. Every consumer of these streams feeds them to
  /// `Ref.invalidateSelfWhen`, which rebuilds the provider on each tick. A
  /// stream that emits on subscribe therefore invalidates the provider that
  /// just subscribed; the rebuild subscribes again and emits again, and the
  /// provider spins for as long as anything watches it -- running its query
  /// once per event-loop turn on the main-isolate database.
  ///
  /// This is exactly what a Drift QUERY stream does: `watchSingle()` and
  /// friends deliver the current row set on listen. A tick must be built on
  /// `tableUpdates`, which fires only on a real write.
  Future<bool> firesWithoutAWrite(Stream<void> tick) async {
    var fired = false;
    final sub = tick.listen((_) => fired = true);
    addTearDown(sub.cancel);

    // Generous relative to the 300 ms debounce the slowest tick applies, so a
    // late emission is not mistaken for silence.
    for (var i = 0; i < 60 && !fired; i++) {
      await Future<void>.delayed(const Duration(milliseconds: 10));
    }
    return fired;
  }

  group('silence before a write', () {
    // Regression guard for #1175: MediaLibraryRepository.watchMediaChanges was
    // a watched COUNT query, so subscribing to it emitted immediately. Fed to
    // invalidateSelfWhen by missingCountProvider and
    // sourceCountsProvider, that turned opening the Media section into an
    // unbounded rebuild loop, one COUNT(*) over `media` per event-loop turn.
    //
    // Covers every tick this file already exercises for firing, so the two
    // halves of the contract are checked over the same set.
    final ticks = <String, Stream<void> Function()>{
      'MediaLibraryRepository.watchMediaChanges':
          MediaLibraryRepository().watchMediaChanges,
      'MediaRepository.watchMediaChanges': MediaRepository().watchMediaChanges,
      'StatisticsRepository.watchStatisticsChanges':
          StatisticsRepository().watchStatisticsChanges,
      'ServiceRecordRepository.watchServiceRecordsChanges':
          ServiceRecordRepository().watchServiceRecordsChanges,
      'ServiceKindRepository.watchServiceKindsChanges':
          ServiceKindRepository().watchServiceKindsChanges,
      'ServiceScheduleRepository.watchSchedulesChanges':
          ServiceScheduleRepository().watchSchedulesChanges,
      'CylinderConfigRepository.watchConfigsChanges':
          CylinderConfigRepository().watchConfigsChanges,
      'DiveComputerRepository.watchComputersChanges':
          DiveComputerRepository().watchComputersChanges,
      'OfflineMapRepository.watchRegionsChanges':
          OfflineMapRepository().watchRegionsChanges,
      'AppSettingsRepository.watchSettingsChanges':
          AppSettingsRepository().watchSettingsChanges,
      'ManifestSubscriptionRepository.watchSubscriptionsChanges':
          ManifestSubscriptionRepository().watchSubscriptionsChanges,
      'WeightHistoryRepository.watchGearLeadChanges':
          WeightHistoryRepository().watchGearLeadChanges,
      'CsvPresetRepository.watchPresetsChanges':
          CsvPresetRepository().watchPresetsChanges,
      'DiveRepository.watchAnalysisInputChanges':
          DiveRepository().watchAnalysisInputChanges,
    };

    for (final entry in ticks.entries) {
      test('${entry.key} stays silent until something is written', () async {
        expect(
          await firesWithoutAWrite(entry.value()),
          isFalse,
          reason:
              '${entry.key} emitted on subscribe. Every caller feeds this to '
              'Ref.invalidateSelfWhen, so an emit-on-listen tick makes the '
              'provider rebuild, resubscribe and tick again forever. Build the '
              'tick on tableUpdates(), not on a watched query.',
        );
      });
    }
  });

  group('statistics', () {
    test('watchStatisticsChanges fires on a dives write', () async {
      expect(
        await fires(
          StatisticsRepository().watchStatisticsChanges(),
          () => db
              .into(db.dives)
              .insert(
                DivesCompanion.insert(
                  id: 'd1',
                  diveDateTime: now,
                  createdAt: now,
                  updatedAt: now,
                ),
              ),
        ),
        isTrue,
      );
    });

    test('watchStatisticsChanges fires on a dive_tanks write', () async {
      // The case watchDivesChanges would have missed. dive_tanks carries all
      // of the SAC math, and a tank-only sync changeset never touches the
      // dives row -- so subscribing to the dives tick alone would have left
      // every SAC chart stale.
      await db
          .into(db.dives)
          .insert(
            DivesCompanion.insert(
              id: 'd1',
              diveDateTime: now,
              createdAt: now,
              updatedAt: now,
            ),
          );
      expect(
        await fires(
          StatisticsRepository().watchStatisticsChanges(),
          () => db
              .into(db.diveTanks)
              .insert(DiveTanksCompanion.insert(id: 't1', diveId: 'd1')),
        ),
        isTrue,
      );
    });

    test('watchStatisticsChanges fires on a dive_sites write', () async {
      expect(
        await fires(
          StatisticsRepository().watchStatisticsChanges(),
          () => db
              .into(db.diveSites)
              .insert(
                DiveSitesCompanion.insert(
                  id: 's1',
                  name: 'Blue Hole',
                  createdAt: now,
                  updatedAt: now,
                ),
              ),
        ),
        isTrue,
      );
    });
  });

  group('equipment', () {
    test('watchServiceRecordsChanges fires', () async {
      await seedParents();
      expect(
        await fires(
          ServiceRecordRepository().watchServiceRecordsChanges(),
          () => db
              .into(db.serviceRecords)
              .insert(
                ServiceRecordsCompanion.insert(
                  id: 'r1',
                  equipmentId: 'e1',
                  serviceCategory: 'annual',
                  serviceDate: now,
                  createdAt: now,
                  updatedAt: now,
                ),
              ),
        ),
        isTrue,
      );
    });

    test('watchServiceKindsChanges fires', () async {
      expect(
        await fires(
          ServiceKindRepository().watchServiceKindsChanges(),
          () => db
              .into(db.serviceKinds)
              .insert(
                ServiceKindsCompanion.insert(
                  id: 'k1',
                  name: 'O2 clean',
                  createdAt: now,
                  updatedAt: now,
                ),
              ),
        ),
        isTrue,
      );
    });

    test(
      'watchGearLeadChanges fires on an equipment_attributes write',
      () async {
        await seedParents();
        // Not the headline table: since #1103 a weight observation's carriedKg
        // also comes from weights-type gear, whose mass lives in
        // equipment_attributes. saveAttributes writes that table ALONE, so a
        // tick watching only `equipment` would be inert for an attribute-only
        // write and leave the calibration refitting against stale ballast.
        expect(
          await fires(
            WeightHistoryRepository().watchGearLeadChanges(),
            () => db
                .into(db.equipmentAttributes)
                .insert(
                  EquipmentAttributesCompanion.insert(
                    id: 'attr_e1_dry_weight_kg',
                    equipmentId: 'e1',
                    attrKey: 'dry_weight_kg',
                    valueNum: const Value(3.63),
                    createdAt: now,
                    updatedAt: now,
                  ),
                ),
          ),
          isTrue,
        );
      },
    );

    test('watchSchedulesChanges fires on a diver_settings write', () async {
      await seedParents();
      // Not the headline table: getDueSoonWindowDays reads serviceReminderDays
      // out of diver_settings, so changing the reminder window moves the
      // due-soon threshold without any service_schedules row being written.
      expect(
        await fires(
          ServiceScheduleRepository().watchSchedulesChanges(),
          () => db
              .into(db.diverSettings)
              .insert(
                DiverSettingsCompanion.insert(
                  id: 'ds1',
                  diverId: 'diver-1',
                  createdAt: now,
                  updatedAt: now,
                ),
              ),
        ),
        isTrue,
      );
    });
  });

  group('cylinder configs', () {
    test('watchConfigsChanges fires on an items write', () async {
      await seedParents();
      // Watches the item table too: a config is meaningless without its items
      // and a sync can apply either side independently.
      expect(
        await fires(
          CylinderConfigRepository().watchConfigsChanges(),
          () => db
              .into(db.cylinderConfigItems)
              .insert(
                CylinderConfigItemsCompanion.insert(
                  id: 'i1',
                  configId: 'c1',
                  tankRole: 'backGas',
                  createdAt: now,
                  updatedAt: now,
                ),
              ),
        ),
        isTrue,
      );
    });
  });

  group('dive log', () {
    test('watchComputersChanges fires', () async {
      expect(
        await fires(
          DiveComputerRepository().watchComputersChanges(),
          () => db
              .into(db.diveComputers)
              .insert(
                DiveComputersCompanion.insert(
                  id: 'c1',
                  name: 'Perdix 2',
                  createdAt: now,
                  updatedAt: now,
                ),
              ),
        ),
        isTrue,
      );
    });

    test('watchCustomFieldsChanges fires on a dives write', () async {
      // Watches dives as well as dive_custom_fields: getDistinctKeysForDiver
      // joins the two, so a cascade delete changes the suggestion set without
      // the custom-field table being written directly.
      expect(
        await fires(
          DiveCustomFieldRepository(db).watchCustomFieldsChanges(),
          () => db
              .into(db.dives)
              .insert(
                DivesCompanion.insert(
                  id: 'd1',
                  diveDateTime: now,
                  createdAt: now,
                  updatedAt: now,
                ),
              ),
        ),
        isTrue,
      );
    });

    test('watchPresetsChanges fires for field presets', () async {
      await seedParents();
      expect(
        await fires(
          ViewConfigRepository(db).watchPresetsChanges(),
          () => db
              .into(db.fieldPresets)
              .insert(
                FieldPresetsCompanion.insert(
                  id: 'p1',
                  diverId: 'diver-1',
                  viewMode: 'table',
                  name: 'Wide',
                  configJson: '[]',
                  createdAt: now,
                ),
              ),
        ),
        isTrue,
      );
    });
  });

  group('trips', () {
    test('watchLiveaboardChanges fires', () async {
      await seedParents();
      expect(
        await fires(
          LiveaboardDetailsRepository().watchLiveaboardChanges(),
          () => db
              .into(db.liveaboardDetailRecords)
              .insert(
                LiveaboardDetailRecordsCompanion.insert(
                  id: 'l1',
                  tripId: 't1',
                  vesselName: 'MY Blue Horizon',
                  createdAt: now,
                  updatedAt: now,
                ),
              ),
        ),
        isTrue,
      );
    });

    test('watchItineraryChanges fires', () async {
      await seedParents();
      expect(
        await fires(
          ItineraryDayRepository().watchItineraryChanges(),
          () => db
              .into(db.tripItineraryDays)
              .insert(
                TripItineraryDaysCompanion.insert(
                  id: 'i1',
                  tripId: 't1',
                  dayNumber: 1,
                  date: now,
                  createdAt: now,
                  updatedAt: now,
                ),
              ),
        ),
        isTrue,
      );
    });
  });

  group('maps', () {
    test('watchRegionsChanges fires', () async {
      expect(
        await fires(
          OfflineMapRepository().watchRegionsChanges(),
          () => db
              .into(db.cachedRegions)
              .insert(
                CachedRegionsCompanion.insert(
                  id: 'r1',
                  name: 'Red Sea',
                  minLat: 27,
                  maxLat: 28,
                  minLng: 33,
                  maxLng: 34,
                  minZoom: 8,
                  maxZoom: 12,
                  tileCount: 0,
                  sizeBytes: 0,
                  createdAt: now,
                  lastAccessedAt: now,
                ),
              ),
        ),
        isTrue,
      );
    });
  });

  group('settings', () {
    test('watchSettingsChanges fires', () async {
      expect(
        await fires(
          AppSettingsRepository().watchSettingsChanges(),
          () => db
              .into(db.settings)
              .insert(SettingsCompanion.insert(key: 'k', updatedAt: now)),
        ),
        isTrue,
      );
    });

    test(
      'watchSettingsChanges is inert rather than throwing with no db',
      () async {
        // Regression guard. Every read in AppSettingsRepository catches its own
        // errors and falls back to a default, so shareByDefaultProvider resolved
        // fine before the database was up. A tick that threw took that
        // robustness away, which is the null-database window of a restore and
        // not merely a test condition.
        await tearDownTestDatabase();
        addTearDown(() async {
          db = await setUpTestDatabase();
        });

        expect(AppSettingsRepository().watchSettingsChanges, returnsNormally);
        expect(
          await AppSettingsRepository().watchSettingsChanges().isEmpty,
          isTrue,
        );
      },
    );
  });

  group('media', () {
    test('watchSubscriptionsChanges fires on a state-table write', () async {
      await seedParents();
      // Watches the per-device state table as well as the subscription table:
      // every read left-outer-joins it, and a poll cycle writes only that side
      // while changing the last-polled and error fields the UI shows.
      expect(
        await fires(
          ManifestSubscriptionRepository().watchSubscriptionsChanges(),
          () => db
              .into(db.mediaSubscriptionState)
              .insert(
                MediaSubscriptionStateCompanion.insert(subscriptionId: 's1'),
              ),
        ),
        isTrue,
      );
    });

    // Every read behind this tick (getMediaById, getMediaForDive, the library
    // page) LEFT JOINs media_enrichment, so the enrichment table is part of
    // the answer, not a detail of some other feature. Watching only `media`
    // made the depth/elapsed chips, the mini profile and the dive computer
    // stay absent after a backfill computed them: the row was written, the
    // provider never re-read it, and the overlays only appeared if the viewer
    // was closed and reopened. Newly linked media hit this every time, since
    // linking is exactly when the enrichment does not exist yet.
    test('watchMediaChanges fires on an enrichment-only write', () async {
      await seedParents();
      await db
          .into(db.dives)
          .insert(
            DivesCompanion.insert(
              id: 'd1',
              diveDateTime: now,
              createdAt: now,
              updatedAt: now,
            ),
          );
      await db
          .into(db.media)
          .insert(
            MediaCompanion.insert(
              id: 'm1',
              diveId: const Value('d1'),
              filePath: '/photos/m1.jpg',
              fileType: const Value('photo'),
              sourceType: const Value('localFile'),
              createdAt: now,
              updatedAt: now,
            ),
          );

      expect(
        await fires(
          MediaRepository().watchMediaChanges(),
          () => db
              .into(db.mediaEnrichment)
              .insert(
                MediaEnrichmentCompanion.insert(
                  id: 'e1',
                  mediaId: 'm1',
                  diveId: 'd1',
                  createdAt: now,
                ),
              ),
        ),
        isTrue,
        reason:
            'a media read joins media_enrichment, so an enrichment write '
            'changes what the consumers of this tick would return',
      );
    });

    test('watchStoresChanges fires', () async {
      expect(
        await fires(
          MediaStoresRepository(database: db).watchStoresChanges(),
          () => db
              .into(db.mediaStores)
              .insert(
                MediaStoresCompanion.insert(
                  id: 'store-1',
                  providerType: 's3',
                  displayHint: 'bucket @ host',
                  createdAt: now,
                  updatedAt: now,
                ),
              ),
        ),
        isTrue,
      );
    });
  });

  group('accounts and presets', () {
    test('watchAccountsChanges fires', () async {
      expect(
        await fires(
          ConnectedAccountsRepository(database: db).watchAccountsChanges(),
          () => db
              .into(db.connectedAccounts)
              .insert(
                ConnectedAccountsCompanion.insert(
                  id: 'a1',
                  kind: 'adobeLightroom',
                  label: 'Lightroom',
                  createdAt: now,
                  updatedAt: now,
                ),
              ),
        ),
        isTrue,
      );
    });

    test('watchPresetsChanges fires for CSV presets', () async {
      expect(
        await fires(
          CsvPresetRepository().watchPresetsChanges(),
          () => db
              .into(db.csvPresets)
              .insert(
                CsvPresetsCompanion.insert(
                  id: 'p1',
                  name: 'Subsurface',
                  presetJson: '{}',
                  createdAt: now,
                  updatedAt: now,
                ),
              ),
        ),
        isTrue,
      );
    });
  });

  group('analysis inputs', () {
    Future<void> seedDive(String id) => db
        .into(db.dives)
        .insert(
          DivesCompanion.insert(
            id: id,
            diveDateTime: now,
            createdAt: now,
            updatedAt: now,
          ),
        );

    test(
      'watchAnalysisInputChanges fires on a dive_profile_events write',
      () async {
        // The coupling watchDiveDetailChanges never had: dive_profile_events is
        // read by diveComputerEventsProvider and merged into every analysis,
        // but the broad detail tick does not include the table at all.
        await seedDive('d1');
        expect(
          await fires(
            DiveRepository().watchAnalysisInputChanges(),
            () => db
                .into(db.diveProfileEvents)
                .insert(
                  DiveProfileEventsCompanion.insert(
                    id: 'ev1',
                    diveId: 'd1',
                    timestamp: 120,
                    eventType: 'gasSwitch',
                    createdAt: now,
                  ),
                ),
          ),
          isTrue,
        );
      },
    );

    test('watchAnalysisInputChanges stays silent on a media write', () async {
      // The other half of the contract, and the reason this tick exists.
      // media IS in watchDiveDetailChanges, so the analysis chain used to be
      // discarded by every media write (orphan reconcile, enrichment
      // backfill) -- re-running the Buhlmann cascade after merely viewing a
      // photo. The analysis reads nothing from media; its tick must not
      // fire for it.
      await seedDive('d1');
      expect(
        await fires(
          DiveRepository().watchAnalysisInputChanges(),
          () => db
              .into(db.media)
              .insert(
                MediaCompanion.insert(
                  id: 'm1',
                  filePath: '/tmp/m1.jpg',
                  createdAt: now,
                  updatedAt: now,
                ),
              ),
        ),
        isFalse,
      );
    });
  });
}
