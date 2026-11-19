import 'package:flutter/material.dart';

import 'package:submersion/core/providers/provider.dart';
import 'package:submersion/features/dive_sites/presentation/providers/site_match_review_notifier.dart';
import 'package:submersion/features/import_wizard/domain/models/diver_import_outcome.dart';
import 'package:submersion/features/import_wizard/presentation/providers/import_trip_providers.dart';
import 'package:submersion/l10n/l10n_extension.dart';

/// The import summary's trips (issue #3022): each trip the new dives were
/// saved in, with how many, most first. Nothing shows when no dive joined a
/// trip.
class ImportTripsTile extends ConsumerWidget {
  const ImportTripsTile({super.key, required this.importedDiveIds});

  final List<String> importedDiveIds;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    if (importedDiveIds.isEmpty) return const SizedBox.shrink();
    final rows =
        ref
            .watch(
              importedDiveTripCountsProvider(ImportedDiveIds(importedDiveIds)),
            )
            .value ??
        const [];
    if (rows.isEmpty) return const SizedBox.shrink();
    final l10n = context.l10n;
    return ListTile(
      key: const Key('import_summary_trips'),
      dense: true,
      contentPadding: EdgeInsets.zero,
      // Beside the heading, not centred on a list that grows with the trips.
      titleAlignment: ListTileTitleAlignment.top,
      leading: const Icon(Icons.flight_outlined),
      title: Text(l10n.universalImport_summary_tripsTitle),
      subtitle: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          for (final row in rows)
            Text(l10n.universalImport_summary_tripCount(row.name, row.count)),
        ],
      ),
    );
  }
}

/// The dives [ImportTripsTile] counts: every dive the import saved as new,
/// in whichever profile ([importedDiveIds] holds only the active profile's,
/// and a download filed under another profile reports its dives through
/// [diverOutcomes] alone), less the planned dives it filled, which kept the
/// trip they had (issue #3022). In first-seen order, each once.
List<String> tripCountDiveIds({
  required List<String> importedDiveIds,
  required List<DiverImportOutcome> diverOutcomes,
  required Iterable<String> filledDiveIds,
}) {
  final filled = filledDiveIds.toSet();
  return {
    ...importedDiveIds,
    for (final outcome in diverOutcomes) ...outcome.diveIds,
  }.where((id) => !filled.contains(id)).toList();
}
