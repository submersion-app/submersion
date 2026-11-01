import 'package:drift/drift.dart';
import 'package:submersion/core/database/database.dart';
import 'package:submersion/features/dive_log/data/repositories/profile_series_repository.dart';
import 'package:submersion/features/dive_log/domain/codecs/profile_sample.dart';

/// Seeds the rows a career terrain reads straight into the test database:
/// sites, divers, dive rows and packed profile series. No repository write
/// path, so a test's statement log holds only the read under test.
class CareerTerrainFixture {
  CareerTerrainFixture(this.db);

  final AppDatabase db;

  /// Epoch millis, matching how this schema stores every timestamp.
  final int now = DateTime.utc(2026, 1, 1).millisecondsSinceEpoch;

  Future<void> addSite(String id) => db
      .into(db.diveSites)
      .insert(
        DiveSitesCompanion(
          id: Value(id),
          name: Value('Site $id'),
          createdAt: Value(now),
          updatedAt: Value(now),
        ),
      );

  Future<void> addDiver(String id) => db
      .into(db.divers)
      .insert(
        DiversCompanion.insert(
          id: id,
          name: 'Diver $id',
          createdAt: now,
          updatedAt: now,
        ),
      );

  Future<void> addComputer(String id) => db
      .into(db.diveComputers)
      .insert(
        DiveComputersCompanion(
          id: Value(id),
          name: Value('Computer $id'),
          createdAt: Value(now),
          updatedAt: Value(now),
        ),
      );

  /// A dive row starting at [start]. [withEntryTime] false leaves
  /// `entry_time` null so the start falls back to `dive_date_time`, the
  /// legacy shape the terrain's date filter must still honour.
  Future<void> addDive(
    String id,
    DateTime start, {
    String? siteId,
    String? diverId,
    int? diveNumber,
    bool withEntryTime = true,
  }) => db
      .into(db.dives)
      .insert(
        DivesCompanion(
          id: Value(id),
          siteId: Value(siteId),
          diverId: Value(diverId),
          diveNumber: Value(diveNumber),
          diveDateTime: Value(start.millisecondsSinceEpoch),
          entryTime: Value(withEntryTime ? start.millisecondsSinceEpoch : null),
          exitTime: Value(
            start.add(const Duration(minutes: 30)).millisecondsSinceEpoch,
          ),
          createdAt: Value(now),
          updatedAt: Value(now),
        ),
      );

  Future<void> addDataSource(
    String id, {
    required String diveId,
    String? computerId,
    required bool isPrimary,
    DateTime? createdAt,
  }) => db
      .into(db.diveDataSources)
      .insert(
        DiveDataSourcesCompanion(
          id: Value(id),
          diveId: Value(diveId),
          computerId: Value(computerId),
          isPrimary: Value(isPrimary),
          importedAt: Value(createdAt ?? DateTime.utc(2026, 1, 1)),
          createdAt: Value(createdAt ?? DateTime.utc(2026, 1, 1)),
        ),
      );

  /// One packed series for [diveId]: a 20 minute V-shaped dive to [maxDepth]
  /// unless [samples] are given.
  Future<String> addProfile(
    String diveId, {
    List<ProfileSample>? samples,
    double maxDepth = 18,
    String? computerId,
    String? sourceId,
    bool isPrimary = true,
  }) => ProfileSeriesRepository().insertSeries(
    diveId: diveId,
    computerId: computerId,
    sourceId: sourceId,
    isPrimary: isPrimary,
    samples:
        samples ??
        [
          const ProfileSample(timestamp: 0, depth: 0),
          ProfileSample(timestamp: 600, depth: maxDepth),
          const ProfileSample(timestamp: 1200, depth: 0),
        ],
  );
}

/// [count] samples one second apart: a descent to [maxDepth] at a third of
/// the way, a plateau, and an ascent; more than one decimation window's worth.
List<ProfileSample> denseProfile({int count = 600, double maxDepth = 30}) {
  final descentEnd = count ~/ 3;
  final ascentStart = (count * 2) ~/ 3;
  return [
    for (var i = 0; i < count; i++)
      ProfileSample(
        timestamp: i,
        depth: i < descentEnd
            ? maxDepth * i / descentEnd
            : i < ascentStart
            ? maxDepth
            : maxDepth * (count - 1 - i) / (count - 1 - ascentStart),
      ),
  ];
}
