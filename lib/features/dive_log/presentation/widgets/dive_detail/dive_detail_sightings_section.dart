import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:submersion/core/constants/dive_detail_sections.dart';
import 'package:submersion/core/providers/provider.dart';
import 'package:submersion/core/utils/unit_formatter.dart';
import 'package:submersion/features/dive_log/domain/entities/dive.dart';
import 'package:submersion/features/dive_log/presentation/providers/active_source_provider.dart';
import 'package:submersion/features/dive_log/presentation/providers/species_profile_providers.dart';
import 'package:submersion/features/dive_log/presentation/widgets/dive_detail/editing/dive_sightings_sitting.dart';
import 'package:submersion/features/dive_log/presentation/widgets/dive_detail/dive_detail_sightings_list.dart';
import 'package:submersion/features/dive_log/presentation/widgets/sighting_depth_label.dart';
import 'package:submersion/features/marine_life/domain/entities/species.dart';
import 'package:submersion/features/marine_life/presentation/providers/species_providers.dart';
import 'package:submersion/features/media/presentation/helpers/elapsed_time_format.dart';
import 'package:submersion/features/media/presentation/pages/dive_species_photo_viewer_page.dart';
import 'package:submersion/features/media/presentation/providers/species_media_providers.dart';
import 'package:submersion/features/settings/presentation/providers/settings_providers.dart';
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
    // Where on the dive each species was seen (issue #5092).
    final positions = watchSpeciesPositions(ref, dive);
    final profile = watchChartProfile(ref, dive);
    final profileShown =
        profile.isNotEmpty &&
        ref.watch(
          settingsProvider.select(
            (s) => s.diveDetailSections.shows(
              DiveDetailSectionId.profile,
              gauge: dive.isGauge,
            ),
          ),
        );
    final selected = ref.watch(selectedProfileSpeciesProvider(dive.id));
    final units = ref.watch(unitFormatterProvider);
    _dropStaleSelection(context, ref, stored.value, selected);

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
                    // Two columns when wide, and a long list collapsed
                    // (issue #5067). Keyed by dive: each dive opens collapsed.
                    DiveSightingsList(
                      key: ValueKey(dive.id),
                      sightings: sightings,
                      photoCounts: photoCounts,
                      onOpen: (sighting) =>
                          context.push('/species/${sighting.speciesId}'),
                      whereSeen: (sighting) => (
                        depthLabel: switch (positions[sighting.speciesId]) {
                          final p? when !p.isEmpty => sightingDepthLabel(
                            p,
                            units,
                            context.l10n,
                          ),
                          _ => null,
                        },
                        depthSelected: selected == sighting.speciesId,
                        onToggleDepth: profileShown
                            ? () => toggleProfileSpecies(
                                ref,
                                dive.id,
                                sighting.speciesId,
                              )
                            : null,
                        seenAtLabel:
                            profile.isEmpty && sighting.seenAtSeconds != null
                            ? context.l10n.diveLog_detail_sightingSeenAt(
                                formatElapsedMmSs(sighting.seenAtSeconds!),
                              )
                            : null,
                      ),
                      onOpenPhotos: (sighting) => Navigator.of(context).push(
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

  /// Clears the dive's highlighted species once its sighting is gone, so a
  /// species added back later does not come back highlighted. After the
  /// frame: a provider is never written during build.
  void _dropStaleSelection(
    BuildContext context,
    WidgetRef ref,
    List<Sighting>? stored,
    String? selected,
  ) {
    if (selected == null || stored == null) return;
    if (stored.any((s) => s.speciesId == selected)) return;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      // The card may be gone by then: a ref of an unmounted widget throws.
      if (!context.mounted) return;
      final notifier = ref.read(
        selectedProfileSpeciesProvider(dive.id).notifier,
      );
      if (notifier.state == selected) notifier.state = null;
    });
  }
}
