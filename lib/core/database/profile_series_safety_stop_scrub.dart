import 'package:drift/drift.dart';
import 'package:submersion/features/dive_log/domain/codecs/profile_series_codec.dart';

/// Drops the ceilings that safety stop samples carry from every stored
/// profile series (v255, #2550), and returns how many series it rewrote.
///
/// Imports before #2550 stored a safety stop's depth as the sample ceiling,
/// so a computer that reports that depth (the Deep Six Excursion) drew a
/// deco stop band on a no-deco dive. Each affected blob is decoded,
/// rewritten without those ceilings and re-encoded, and its
/// `has_positive_ceiling` recomputed from the result, so the scalars still
/// match the blob (the sync receiver rejects a row whose scalars do not).
/// Deco and deep stop ceilings, and series that record no deco type, are
/// not touched.
///
/// Only series with both a deco type and a positive ceiling can hold one, so
/// the scan reads no other blob. The sync stamp (`updated_at`, `hlc`) does
/// not move: every device runs this same rewrite, so they agree without a
/// sync round, and moving it would make every device send every affected
/// series to every other. A blob that does not decode (corrupt, or written
/// by a newer codec) is stepped over and left as it is.
///
/// Raw SQL throughout, as the other ladder helpers, so it keeps compiling
/// against any later shape of the generated classes.
Future<int> scrubSafetyStopCeilings(DatabaseConnectionUser db) async {
  const codec = ProfileSeriesCodec();
  final candidates = await db
      .customSelect(
        'SELECT id, samples FROM dive_profile_series '
        'WHERE has_deco_type = 1 AND has_positive_ceiling = 1',
      )
      .get();
  var rewritten = 0;
  for (final row in candidates) {
    final id = row.read<String>('id');
    try {
      final samples = codec.decode(row.read<Uint8List>('samples'));
      final scrubbed = [
        for (final sample in samples) sample.withoutSafetyStopCeiling(),
      ];
      var changed = false;
      for (var i = 0; i < samples.length; i++) {
        if (!identical(scrubbed[i], samples[i])) {
          changed = true;
          break;
        }
      }
      if (!changed) continue;
      final encoded = codec.encode(scrubbed);
      await db.customUpdate(
        'UPDATE dive_profile_series '
        'SET samples = ?, codec_version = ?, has_positive_ceiling = ? '
        'WHERE id = ?',
        variables: [
          Variable<Uint8List>(encoded.bytes),
          Variable<int>(encoded.codecVersion),
          Variable<int>(encoded.summary.hasPositiveCeiling ? 1 : 0),
          Variable<String>(id),
        ],
        updateKind: UpdateKind.update,
      );
      rewritten++;
    } catch (_) {
      // One unreadable series must not cost the rest their fix; it keeps
      // its stored ceilings, which every reader already ignores on a
      // safety stop sample.
      continue;
    }
  }
  return rewritten;
}
