import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/core/database/database.dart';
import 'package:submersion/core/services/sync/sync_data_serializer.dart';
import 'package:submersion/features/dive_log/data/repositories/profile_series_repository.dart';
import 'package:submersion/features/dive_log/domain/codecs/profile_field_table.dart';
import 'package:submersion/features/dive_log/domain/codecs/profile_sample.dart';
import 'package:submersion/features/dive_log/domain/codecs/profile_series_codec.dart';
import 'package:submersion/features/dive_log/domain/codecs/profile_series_codec_exception.dart';
import 'package:drift/drift.dart' hide isNull, isNotNull;

import '../../../helpers/test_database.dart';

/// A codec version this build does not know is not corruption. Adding one
/// is not a breaking wire change by the compatibility floor's own rules, so
/// no floor holds the newer peer back and its rows arrive here. Discarding
/// them at the sync door loses them for good: nothing re-requests a record
/// the sender believes it delivered.
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

  /// A blob written by a hypothetical v2 codec: same field table, version
  /// byte 2, which this build has no table for.
  Uint8List futureBlob() =>
      const ProfileSeriesCodec(fieldTables: {2: kProfileFieldTableV1}).encode(
        const [
          ProfileSample(timestamp: 0, depth: 1.0),
          ProfileSample(timestamp: 60, depth: 9.0),
        ],
        version: 2,
      ).bytes;

  test('the codec names a forward version as such', () {
    try {
      const ProfileSeriesCodec().decode(futureBlob());
      fail('expected a refusal');
    } on UnknownSeriesVersionException catch (e) {
      expect(e.blobVersion, 2);
      expect(e.isForwardVersion, isTrue);
    }
  });

  test('a series from a newer codec is stored, not dropped', () async {
    final bytes = futureBlob();
    await SyncDataSerializer().upsertRecord('diveProfileSeries', {
      'id': 'from-the-future',
      'diveId': 'dive-1',
      'isPrimary': true,
      'sampleCount': 2,
      'startTimestamp': 0,
      'endTimestamp': 60,
      'maxDepth': 9.0,
      'firstDepth': 1.0,
      'lastDepth': 9.0,
      'hasDecoType': false,
      'hasDecoStop': false,
      'hasPositiveCeiling': false,
      'codecVersion': 2,
      'samples': base64Encode(bytes),
      'createdAt': now,
      'updatedAt': now,
    });

    final rows = await ProfileSeriesRepository().getRowsForDives(['dive-1']);
    expect(
      rows.map((r) => r.id),
      ['from-the-future'],
      reason: 'a newer peer\'s samples must survive until this device updates',
    );
    // Local reads still skip what they cannot decode, rather than throwing.
    expect(await ProfileSeriesRepository().getSeriesForDive('dive-1'), isEmpty);
  });

  test('a blob with an unknown version BELOW ours is still refused', () async {
    // Version 0 is not a future codec, it is a malformed or tampered blob.
    final bytes = Uint8List.fromList(futureBlob());
    await SyncDataSerializer().upsertRecord('diveProfileSeries', {
      'id': 'corrupt',
      'diveId': 'dive-1',
      'isPrimary': true,
      'sampleCount': 2,
      'startTimestamp': 0,
      'endTimestamp': 60,
      'maxDepth': 9.0,
      'firstDepth': 1.0,
      'lastDepth': 9.0,
      'hasDecoType': false,
      'hasDecoStop': false,
      'hasPositiveCeiling': false,
      'codecVersion': 1,
      'samples': base64Encode(
        const ProfileSeriesCodec(
          fieldTables: {0: kProfileFieldTableV1},
        ).encode(const [
          ProfileSample(timestamp: 0, depth: 1.0),
          ProfileSample(timestamp: 60, depth: 9.0),
        ], version: 0).bytes,
      ),
      'createdAt': now,
      'updatedAt': now,
    });
    expect(bytes, isNotEmpty);

    expect(
      await ProfileSeriesRepository().getRowsForDives(['dive-1']),
      isEmpty,
    );
  });
}
