import 'package:drift/drift.dart' show Value;
import 'package:flutter_riverpod/misc.dart' show ProviderListenable;
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:submersion/core/database/database.dart'
    show AppDatabase, DiveSitesCompanion;
import 'package:submersion/core/providers/provider.dart';
import 'package:submersion/features/dive_log/data/repositories/dive_repository_impl.dart';
import 'package:submersion/features/dive_log/domain/entities/dive.dart';
import 'package:submersion/features/dive_log/presentation/providers/dive_providers.dart';
import 'package:submersion/features/dive_log/presentation/providers/dive_summary_providers.dart';
import 'package:submersion/features/dive_sites/data/repositories/site_repository_impl.dart';
import 'package:submersion/features/dive_sites/domain/entities/dive_site.dart';
import 'package:submersion/features/divers/data/repositories/diver_repository.dart';
import 'package:submersion/features/divers/domain/entities/diver.dart';
import 'package:submersion/features/divers/presentation/providers/diver_providers.dart';
import 'package:submersion/features/insights/presentation/providers/insights_providers.dart';
import 'package:submersion/features/settings/presentation/providers/settings_providers.dart';

import '../../../../helpers/test_database.dart';

/// The statistics and records queries JOIN `dive_sites` for the site names
/// they return (Most Visited Sites, a record's site), so renaming a site,
/// which writes `dive_sites` and never `dives`, must refresh every provider
/// built on them. A dives-only tick left the old name up until an unrelated
/// dive write.
void main() {
  late SharedPreferences prefs;
  late AppDatabase db;

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    prefs = await SharedPreferences.getInstance();
    db = await setUpTestDatabase();
    final diver = await DiverRepository().createDiver(
      Diver(
        id: '',
        name: 'D',
        isDefault: true,
        createdAt: DateTime(2024),
        updatedAt: DateTime(2024),
      ),
    );
    await prefs.setString(currentDiverIdKey, diver.id);
    final site = await SiteRepository().createSite(
      DiveSite(id: 'site-a', diverId: diver.id, name: 'Old Name'),
    );
    await DiveRepository().createDive(
      Dive(
        id: 'dive-1',
        diverId: diver.id,
        dateTime: DateTime(2026, 1, 10),
        maxDepth: 30,
        site: site,
      ),
    );
  });

  tearDown(() async {
    await tearDownTestDatabase();
  });

  Future<T?> settle<T>(
    ProviderContainer container,
    ProviderListenable<AsyncValue<T>> provider,
    bool Function(T) done,
  ) async {
    for (var i = 0; i < 200; i++) {
      final value = container.read(provider).value;
      if (value != null && done(value)) return value;
      await Future<void>.delayed(const Duration(milliseconds: 10));
    }
    return container.read(provider).value;
  }

  Future<void> renameSite() =>
      (db.update(db.diveSites)..where((t) => t.id.equals('site-a'))).write(
        const DiveSitesCompanion(name: Value('New Name')),
      );

  final statistics = <String, ProviderListenable<AsyncValue<DiveStatistics>>>{
    'diveStatisticsProvider': diveStatisticsProvider,
    'diveListScopedStatisticsProvider': diveListScopedStatisticsProvider,
    'filteredDiveStatisticsProvider': filteredDiveStatisticsProvider,
  };
  final records = <String, ProviderListenable<AsyncValue<DiveRecords>>>{
    'diveRecordsProvider': diveRecordsProvider,
    'diveListScopedRecordsProvider': diveListScopedRecordsProvider,
    'filteredDiveRecordsProvider': filteredDiveRecordsProvider,
  };

  String? topSiteName(DiveStatistics s) =>
      s.topSites.isEmpty ? null : s.topSites.first.siteName;

  for (final MapEntry(key: name, value: provider) in statistics.entries) {
    test('$name refreshes its top site name on a site rename', () async {
      final container = ProviderContainer(
        overrides: [sharedPreferencesProvider.overrideWithValue(prefs)],
      );
      addTearDown(container.dispose);
      final sub = container.listen(provider, (_, _) {});
      addTearDown(sub.close);
      expect(
        topSiteName((await settle(container, provider, (_) => true))!),
        'Old Name',
      );

      await renameSite();

      final after = await settle(
        container,
        provider,
        (s) => topSiteName(s) == 'New Name',
      );
      expect(topSiteName(after!), 'New Name');
    });
  }

  for (final MapEntry(key: name, value: provider) in records.entries) {
    test('$name refreshes its record site name on a site rename', () async {
      final container = ProviderContainer(
        overrides: [sharedPreferencesProvider.overrideWithValue(prefs)],
      );
      addTearDown(container.dispose);
      final sub = container.listen(provider, (_, _) {});
      addTearDown(sub.close);
      expect(
        (await settle(
          container,
          provider,
          (r) => r.deepestDive != null,
        ))?.deepestDive?.siteName,
        'Old Name',
      );

      await renameSite();

      final after = await settle(
        container,
        provider,
        (r) => r.deepestDive?.siteName == 'New Name',
      );
      expect(after?.deepestDive?.siteName, 'New Name');
    });
  }
}
