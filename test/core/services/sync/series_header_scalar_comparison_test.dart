import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/core/database/database.dart';
import 'package:submersion/core/services/sync/sync_data_serializer.dart';
import 'package:submersion/features/dive_log/data/repositories/profile_series_repository.dart';
import 'package:submersion/features/dive_log/domain/codecs/profile_sample.dart';
import 'package:submersion/features/dive_log/domain/codecs/profile_series_codec.dart';

import '../../../helpers/test_database.dart';

/// The soundness check that compares a peer's header scalars against the
/// summary its blob decodes to compares doubles by bit pattern, not with
/// `!=`: `!=` calls -0.0 equal to 0.0, which let a header that genuinely
/// disagrees with its blob through the very check that exists to catch one.
///
/// A non-finite depth scalar is refused ahead of that comparison, because
/// SQLite stores a non-finite double as NULL and the depth columns are NOT
/// NULL: admitting one would fail the batch insert that carries every other
/// series record in the payload, not just itself.
void main() {
  late AppDatabase db;
  const now = 1750000000000;

  setUp(() async {
    db = await setUpTestDatabase();
    await db
        .into(db.dives)
        .insert(
          DivesCompanion.insert(
            id: 'dive-1',
            diveDateTime: now,
            createdAt: now,
            updatedAt: now,
          ),
        );
  });
  tearDown(tearDownTestDatabase);

  /// The wire record a peer sends for [encoded]. The named overrides stand
  /// in for a header that disagrees with the blob it ships with.
  Map<String, dynamic> record(
    String id,
    EncodedProfileSeries encoded, {
    double? maxDepth,
    double? lastDepth,
  }) => {
    'id': id,
    'diveId': 'dive-1',
    'isPrimary': true,
    'sampleCount': encoded.summary.sampleCount,
    'startTimestamp': encoded.summary.startTimestamp,
    'endTimestamp': encoded.summary.endTimestamp,
    'maxDepth': maxDepth ?? encoded.summary.maxDepth,
    'firstDepth': encoded.summary.firstDepth,
    'lastDepth': lastDepth ?? encoded.summary.lastDepth,
    'hasDecoType': encoded.summary.hasDecoType,
    'hasDecoStop': encoded.summary.hasDecoStop,
    'hasPositiveCeiling': encoded.summary.hasPositiveCeiling,
    'codecVersion': encoded.codecVersion,
    'samples': base64Encode(encoded.bytes),
    'createdAt': now,
    'updatedAt': now,
  };

  Future<void> upsert(
    String id,
    EncodedProfileSeries encoded, {
    double? maxDepth,
    double? lastDepth,
  }) => SyncDataSerializer().upsertRecord(
    'diveProfileSeries',
    record(id, encoded, maxDepth: maxDepth, lastDepth: lastDepth),
  );

  test('a NaN depth scalar is skipped without failing its batch', () async {
    // ProfileSeriesSummary.of seeds maxDepth from the first sample with a
    // `>` comparison that never overwrites a NaN seed, so this header
    // agrees with its blob exactly; it is still unstorable, because the
    // depth columns are NOT NULL and SQLite writes a non-finite double as
    // NULL. The record next to it in the same batch must still land.
    final nan = const ProfileSeriesCodec().encode(const [
      ProfileSample(timestamp: 0, depth: double.nan),
      ProfileSample(timestamp: 60, depth: 9.0),
    ]);
    expect(nan.summary.maxDepth, isNaN);
    expect(nan.summary.firstDepth, isNaN);
    final sound = const ProfileSeriesCodec().encode(const [
      ProfileSample(timestamp: 0, depth: 3.0),
      ProfileSample(timestamp: 60, depth: 12.0),
    ]);

    await SyncDataSerializer().upsertRecords('diveProfileSeries', [
      record('nan-depths', nan),
      record('sound', sound),
    ]);

    expect(
      (await ProfileSeriesRepository().getRowsForDives([
        'dive-1',
      ])).map((r) => r.id),
      ['sound'],
      reason: 'the unstorable row must cost only itself',
    );
  });

  test('a NaN depth inside the profile is fine: only the header matters', () {
    // The scalars are the first, last and greatest depth, so a NaN in the
    // middle of a dive never reaches one of them and the row stores.
    final summary = const ProfileSeriesCodec().encode(const [
      ProfileSample(timestamp: 0, depth: 3.0),
      ProfileSample(timestamp: 30, depth: double.nan),
      ProfileSample(timestamp: 60, depth: 12.0),
    ]).summary;
    expect(summary.maxDepth, 12.0);
    expect(summary.firstDepth, 3.0);
    expect(summary.lastDepth, 12.0);
  });

  test('a header claiming 0.0 for a blob holding -0.0 is refused', () async {
    final encoded = const ProfileSeriesCodec().encode(const [
      ProfileSample(timestamp: 0, depth: 5.0),
      ProfileSample(timestamp: 60, depth: -0.0),
    ]);
    expect(encoded.summary.lastDepth, -0.0);

    await upsert('negative-zero', encoded, lastDepth: 0.0);

    expect(
      await ProfileSeriesRepository().getRowsForDives(['dive-1']),
      isEmpty,
      reason: 'a header that disagrees with its blob is what the check is for',
    );
  });

  test('a header that agrees with its blob at -0.0 is stored', () async {
    final encoded = const ProfileSeriesCodec().encode(const [
      ProfileSample(timestamp: 0, depth: 5.0),
      ProfileSample(timestamp: 60, depth: -0.0),
    ]);

    await upsert('negative-zero-ok', encoded);

    expect(
      (await ProfileSeriesRepository().getRowsForDives([
        'dive-1',
      ])).map((r) => r.id),
      ['negative-zero-ok'],
    );
  });

  test('an ordinary header mismatch is still refused', () async {
    final encoded = const ProfileSeriesCodec().encode(const [
      ProfileSample(timestamp: 0, depth: 5.0),
      ProfileSample(timestamp: 60, depth: 9.0),
    ]);

    await upsert('tampered', encoded, maxDepth: 99.0);

    expect(
      await ProfileSeriesRepository().getRowsForDives(['dive-1']),
      isEmpty,
    );
  });
}
