import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:submersion/core/providers/provider.dart';

import 'package:submersion/core/utils/unit_formatter.dart';
import 'package:submersion/features/marine_life/domain/entities/species_sighting_record.dart';
import 'package:submersion/features/marine_life/presentation/providers/seen_species_providers.dart';
import 'package:submersion/features/settings/presentation/providers/settings_providers.dart';
import 'package:submersion/l10n/l10n_extension.dart';

/// The dives on which one species was seen, newest first, for the species
/// detail page.
///
/// Shows the [collapsedCount] most recent records behind a "Show all"
/// toggle. Renders nothing when there are no records: the statistics section
/// above it already says there are no sightings yet, and two empty states on
/// one page is noise.
class SpeciesSightingsSection extends ConsumerStatefulWidget {
  final String speciesId;

  /// Records shown before the diver taps "Show all".
  static const int collapsedCount = 10;

  const SpeciesSightingsSection({super.key, required this.speciesId});

  @override
  ConsumerState<SpeciesSightingsSection> createState() =>
      _SpeciesSightingsSectionState();
}

class _SpeciesSightingsSectionState
    extends ConsumerState<SpeciesSightingsSection> {
  bool _expanded = false;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final recordsAsync = ref.watch(speciesSightingsProvider(widget.speciesId));
    final units = UnitFormatter(ref.watch(settingsProvider));

    return recordsAsync.when(
      loading: () => const SizedBox.shrink(),
      error: (error, _) => Padding(
        padding: const EdgeInsets.only(top: 24),
        child: Text(
          l10n.marineLife_speciesDetail_sightingsError(error.toString()),
          style: TextStyle(color: Theme.of(context).colorScheme.error),
        ),
      ),
      data: (records) {
        if (records.isEmpty) return const SizedBox.shrink();

        final collapsible =
            records.length > SpeciesSightingsSection.collapsedCount;
        final visible = collapsible && !_expanded
            ? records.take(SpeciesSightingsSection.collapsedCount).toList()
            : records;

        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const SizedBox(height: 24),
            Text(
              l10n.marineLife_speciesDetail_sightingsTitle(records.length),
              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                color: Theme.of(context).colorScheme.primary,
              ),
            ),
            const SizedBox(height: 12),
            Card(
              child: Column(
                children: [
                  for (final record in visible)
                    _SightingTile(record: record, units: units),
                ],
              ),
            ),
            if (collapsible)
              Align(
                alignment: AlignmentDirectional.centerEnd,
                child: TextButton(
                  key: const ValueKey('sightings_toggle'),
                  onPressed: () => setState(() => _expanded = !_expanded),
                  child: Text(
                    _expanded
                        ? l10n.marineLife_speciesDetail_showFewer
                        : l10n.marineLife_speciesDetail_showAll(records.length),
                  ),
                ),
              ),
          ],
        );
      },
    );
  }
}

class _SightingTile extends StatelessWidget {
  final SpeciesSightingRecord record;
  final UnitFormatter units;

  const _SightingTile({required this.record, required this.units});

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final number = record.diveNumber;
    final depth = record.maxDepthMeters;
    final details = [
      units.formatDate(record.diveDateTime),
      if (record.count > 1)
        l10n.marineLife_speciesDetail_countTimes(record.count),
      if (record.notes.isNotEmpty) record.notes,
    ].join(' · ');

    return ListTile(
      leading: CircleAvatar(
        child: number != null
            ? FittedBox(
                child: Padding(
                  padding: const EdgeInsets.all(6),
                  child: Text('#$number'),
                ),
              )
            : const Icon(Icons.scuba_diving),
      ),
      title: Text(record.siteName ?? l10n.marineLife_speciesDetail_unknownSite),
      subtitle: Text(details, maxLines: 1, overflow: TextOverflow.ellipsis),
      trailing: depth != null ? Text(units.formatDepth(depth)) : null,
      onTap: () => context.push('/dives/${record.diveId}'),
    );
  }
}
