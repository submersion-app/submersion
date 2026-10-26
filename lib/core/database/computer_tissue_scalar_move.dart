import 'dart:convert';

import 'package:drift/drift.dart';
import 'package:submersion/features/dive_log/domain/entities/computer_tissue_legacy_scalars.dart';

/// Moves the dive-level values out of every stored computer tissue snapshot
/// (v318, #2555), and returns how many dives it rewrote.
///
/// Snapshots written from v256 on also held the deco model, the CNS at dive
/// start and end, and the OTU. Each has a column of its own, so a dive could
/// hold two values for one fact with nothing keeping them in step, and for
/// Suunto and Shearwater Cloud dives the columns were never filled at all.
/// Each value goes to the dive's column (`deco_algorithm`, `cns_start`,
/// `cns_end`, `otu`) and the primary data source's (`deco_algorithm`, `cns`,
/// `otu`) where that column is empty, a `cns_start` still at its default of
/// 0 counting as empty; a value already there wins. The snapshot is then
/// stored without the four, or cleared when nothing else was in it.
///
/// [fillSources] false leaves the source rows out, for a database without
/// the sources table.
///
/// Only snapshots naming one of the keys are read, so it is cheap enough to
/// run again after every inbound sync apply, which is how a dive from a peer
/// below v318 gets the same move. The sync stamp (`updated_at`, `hlc`) does
/// not move: every device runs this same rewrite, so they agree without a
/// sync round. A snapshot that does not parse as a
/// JSON object is stepped over and left as it is.
///
/// Raw SQL throughout, as the other ladder helpers, so it keeps compiling
/// against any later shape of the generated classes.
Future<int> moveComputerTissueScalars(
  DatabaseConnectionUser db, {
  bool fillSources = true,
}) async {
  final candidates = await db.customSelect('''
    SELECT id, computer_tissue_json, cns_start FROM dives
    WHERE computer_tissue_json LIKE '%"algorithm"%'
       OR computer_tissue_json LIKE '%"cns_percent"%'
       OR computer_tissue_json LIKE '%"otu"%'
  ''').get();
  var rewritten = 0;
  for (final row in candidates) {
    final Object? decoded;
    try {
      decoded = jsonDecode(row.read<String>('computer_tissue_json'));
    } on FormatException {
      continue;
    }
    if (decoded is! Map<String, dynamic>) continue;

    final id = row.read<String>('id');
    final scalars = LegacyTissueScalars.of(decoded);
    final stripped = LegacyTissueScalars.strip(decoded);
    final unsetCnsStart = row.read<double>('cns_start') == 0;
    await db.customUpdate(
      'UPDATE dives SET computer_tissue_json = ?, '
      'cns_start = CASE WHEN ? THEN COALESCE(?, cns_start) ELSE cns_start END, '
      'cns_end = COALESCE(cns_end, ?), otu = COALESCE(otu, ?), '
      'deco_algorithm = COALESCE(deco_algorithm, ?) '
      'WHERE id = ?',
      variables: [
        Variable<String>(stripped.isEmpty ? null : jsonEncode(stripped)),
        Variable<bool>(unsetCnsStart),
        Variable<double>(scalars.cnsStart),
        Variable<double>(scalars.cnsEnd),
        Variable<double>(scalars.otu),
        Variable<String>(scalars.algorithm),
        Variable<String>(id),
      ],
      updateKind: UpdateKind.update,
    );
    if (!fillSources) {
      rewritten++;
      continue;
    }
    await db.customUpdate(
      'UPDATE dive_data_sources SET cns = COALESCE(cns, ?), '
      'otu = COALESCE(otu, ?), '
      'deco_algorithm = COALESCE(deco_algorithm, ?) '
      'WHERE dive_id = ? AND is_primary = 1',
      variables: [
        Variable<double>(scalars.cnsEnd),
        Variable<double>(scalars.otu),
        Variable<String>(scalars.algorithm),
        Variable<String>(id),
      ],
      updateKind: UpdateKind.update,
    );
    rewritten++;
  }
  return rewritten;
}
