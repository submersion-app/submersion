import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:submersion/core/providers/provider.dart';
import 'package:submersion/features/dive_log/domain/entities/dive.dart';
import 'package:submersion/features/dive_log/presentation/widgets/dive_detail/editing/dive_sightings_sitting.dart';
import 'package:submersion/features/dive_log/presentation/widgets/dive_sighting_row.dart';
import 'package:submersion/features/marine_life/presentation/providers/species_providers.dart';
import 'package:submersion/features/media/presentation/pages/dive_species_photo_viewer_page.dart';
import 'package:submersion/features/media/presentation/providers/species_media_providers.dart';
import 'package:submersion/features/species_id/presentation/widgets/dive_find_species_panel.dart';
import 'package:submersion/features/species_id/presentation/widgets/species_download_prompt.dart';
import 'package:submersion/l10n/l10n_extension.dart';
import 'package:submersion/shared/widgets/record_editing/record_card_header.dart';
import 'package:submersion/shared/widgets/record_editing/record_edit_controller.dart';

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
    final stored = ref.watch(diveSightingsProvider(dive.id));
    // During a sitting that changed them, the sitting's sightings (issue
    // #4527); otherwise the stored ones.
    final session = RecordEditScope.maybeOf<Dive>(context)?.session;
    final held = session != null && diveSightingsList.isChanged(session)
        ? diveSightingsList.current(session)
        : null;
    final sightingsAsync = held == null ? stored : AsyncValue.data(held);
    // Find species and the way to Species to review (issue #4727), on the
    // locked page only: an unlocked card shows its edit state.
    final panel = session == null && diveFindSpeciesWanted(ref, dive);
    // With no model, the offer to download one (issue #4773).
    final prompt = session == null && diveDownloadPromptWanted(ref, dive);
    // Loads beside the sightings: a row shows its chip once the count is in.
    final photoCounts =
        ref.watch(diveSpeciesPhotoCountsProvider(dive.id)).value ??
        const <String, int>{};

    return sightingsAsync.when(
      data: (sightings) {
        if (sightings.isEmpty && !panel && !prompt) {
          return const SizedBox.shrink(); // Nothing to show
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
                    // Its pencil, while the dive is unlocked.
                    RecordCardHeader(
                      title: context.l10n.diveLog_detail_section_marineLife,
                      trailing: sightings.isEmpty
                          ? null
                          : Text(
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
                    if (panel) DiveFindSpeciesPanel(dive: dive),
                    if (prompt) const SpeciesDownloadPrompt(),
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
