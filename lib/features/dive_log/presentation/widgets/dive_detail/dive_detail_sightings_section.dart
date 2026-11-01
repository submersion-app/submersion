import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:submersion/core/providers/provider.dart';
import 'package:submersion/features/dive_log/domain/entities/dive.dart';
import 'package:submersion/features/dive_log/presentation/widgets/dive_sighting_row.dart';
import 'package:submersion/features/marine_life/presentation/providers/species_providers.dart';
import 'package:submersion/features/media/presentation/pages/dive_species_photo_viewer_page.dart';
import 'package:submersion/features/media/presentation/providers/species_media_providers.dart';
import 'package:submersion/l10n/l10n_extension.dart';

/// The Marine life card.
///
/// Whether there is anything to show is only known once the sightings load,
/// so it places [topGap] above itself rather than leaving that to the list.
class DiveSightingsSection extends ConsumerWidget {
  const DiveSightingsSection({
    super.key,
    required this.dive,
    required this.topGap,
  });

  final Dive dive;
  final double topGap;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final sightingsAsync = ref.watch(diveSightingsProvider(dive.id));
    // Loads beside the sightings: a row shows its chip once the count is in.
    final photoCounts =
        ref.watch(diveSpeciesPhotoCountsProvider(dive.id)).value ??
        const <String, int>{};

    return sightingsAsync.when(
      data: (sightings) {
        if (sightings.isEmpty) {
          return const SizedBox.shrink(); // Don't show section if no sightings
        }

        return Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            SizedBox(height: topGap),
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          context.l10n.diveLog_detail_section_marineLife,
                          style: Theme.of(context).textTheme.titleMedium,
                        ),
                        Text(
                          context.l10n.diveLog_detail_speciesCount(
                            sightings.length,
                          ),
                          style: Theme.of(context).textTheme.bodySmall
                              ?.copyWith(
                                color: Theme.of(
                                  context,
                                ).colorScheme.onSurfaceVariant,
                              ),
                        ),
                      ],
                    ),
                    const Divider(),
                    for (final sighting in sightings)
                      DiveSightingRow(
                        sighting: sighting,
                        photoCount: photoCounts[sighting.speciesId] ?? 0,
                        onOpen: () =>
                            context.push('/species/${sighting.speciesId}'),
                        onOpenPhotos: () => Navigator.of(context).push(
                          MaterialPageRoute(
                            fullscreenDialog: true,
                            builder: (_) => DiveSpeciesPhotoViewerPage(
                              diveId: dive.id,
                              speciesId: sighting.speciesId,
                            ),
                          ),
                        ),
                      ),
                  ],
                ),
              ),
            ),
          ],
        );
      },
      loading: () => const SizedBox.shrink(),
      error: (_, _) => const SizedBox.shrink(),
    );
  }
}
