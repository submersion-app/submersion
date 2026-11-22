import 'dart:async';

import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import 'package:submersion/core/providers/provider.dart';
import 'package:submersion/features/marine_life/presentation/providers/species_providers.dart';
import 'package:submersion/features/marine_life/presentation/species_display.dart';
import 'package:submersion/features/media/domain/entities/media_item.dart';
import 'package:submersion/features/media/domain/entities/photo_record.dart';
import 'package:submersion/features/media/presentation/editing/photo_sitting_shown.dart';
import 'package:submersion/features/media/presentation/widgets/media_species_sheet.dart';
import 'package:submersion/features/species_id/domain/entities/media_identification.dart';
import 'package:submersion/features/species_id/domain/entities/pack_candidate.dart';
import 'package:submersion/features/species_id/domain/services/identification_rules.dart';
import 'package:submersion/features/species_id/presentation/providers/recorded_nearby_providers.dart';
import 'package:submersion/features/species_id/data/services/identification_crop_store.dart';
import 'package:submersion/features/species_id/presentation/providers/species_id_providers.dart';
import 'package:submersion/features/species_id/presentation/widgets/recorded_nearby_line.dart';
import 'package:submersion/l10n/arb/app_localizations.dart';
import 'package:submersion/l10n/l10n_extension.dart';
import 'package:submersion/shared/widgets/record_editing/edit_session.dart';

/// A candidate's name as shown: the catalogue's translation when it is a
/// catalogue species, else its English common name.
String candidateDisplayName(AppLocalizations l10n, PackCandidate candidate) {
  final catalogId = candidate.catalogId;
  return catalogId == null
      ? candidate.commonName
      : localizedSpeciesName(l10n, catalogId, candidate.commonName);
}

/// The suggestions for [mediaId] that are not already shown as tags.
///
/// A shown tag matches a suggestion by catalogue id or by scientific name,
/// as stored tags do: a species added in a sitting may be one of the
/// diver's own, which only its scientific name ties to the suggestion.
List<SpeciesSuggestion> suggestionsShown(
  WidgetRef ref,
  String mediaId,
  EditSession<PhotoRecord>? sitting,
) {
  final suggestions = ref.watch(mediaSuggestionsProvider(mediaId)).value;
  if (suggestions == null || suggestions.isEmpty) return const [];
  final shown = shownTaggedSpecies(ref, mediaId, sitting);
  if (shown.isEmpty) return suggestions;
  return [
    for (final s in suggestions)
      if (!shown.any((t) => candidateMatches(s.top.candidate, t))) s,
  ];
}

/// The species tagged on [mediaId] as the viewer shows them: held in
/// [sitting] when there is one, else stored, each with its scientific
/// name, as the rules compare them with candidates.
List<TaggedSpecies> shownTaggedSpecies(
  WidgetRef ref,
  String mediaId,
  EditSession<PhotoRecord>? sitting,
) {
  final chips = speciesChipsShown(ref, mediaId, sitting);
  if (chips.isEmpty) return const [];
  final scientificNames = {
    for (final species in ref.watch(allSpeciesProvider).value ?? const [])
      species.id: species.scientificName,
  };
  return [
    for (final chip in chips)
      TaggedSpecies(
        speciesId: chip.speciesId,
        scientificName: scientificNames[chip.speciesId],
      ),
  ];
}

/// Holds each of [candidates]' species in turn as tagged in [sitting]; the
/// identifications are reconciled once the viewer's Save writes the tags.
/// With [claimTrackId], each species is first recorded against that animal
/// in a video (issue #4675), so its label follows the fish the diver tapped.
///
/// Everything it needs is read before the first lookup: the sheet or crop
/// view it was called from may be gone before the lookups finish.
Future<void> addSuggestedSpecies(
  BuildContext context,
  WidgetRef ref,
  MediaItem item,
  List<PackCandidate> candidates,
  EditSession<PhotoRecord> sitting, {
  String? claimTrackId,
}) async {
  final acceptor = ref.read(suggestionAcceptorProvider);
  final identification = ref.read(mediaIdentificationServiceProvider);
  final messenger = ScaffoldMessenger.maybeOf(context);
  final failed = context.l10n.common_error_tryAgain;
  try {
    for (final candidate in candidates) {
      final species = await acceptor.resolve(candidate);
      if (claimTrackId != null) {
        await identification.claim(item.id, claimTrackId, species.id);
      }
      holdPickedSpecies(sitting, species);
    }
  } catch (_) {
    messenger?.showSnackBar(SnackBar(content: Text(failed)));
  }
}

/// The species sheet's Suggested section (issue #4668): one row per
/// species the app found, with its crop, to add as a tag or dismiss.
/// Renders nothing when there is nothing to offer and nothing running.
class SuggestedSpeciesSection extends ConsumerWidget {
  const SuggestedSpeciesSection({
    super.key,
    required this.item,
    required this.sitting,
  });

  final MediaItem item;

  /// The photo's sitting: an added suggestion is held in it until Save.
  final EditSession<PhotoRecord> sitting;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = context.l10n;
    final suggestions = suggestionsShown(ref, item.id, sitting);
    final busy =
        ref.watch(mediaIdentificationBusyProvider(item.id)).value ?? false;
    final progress = ref
        .watch(mediaIdentificationProgressProvider(item.id))
        .value;
    if (suggestions.isEmpty && !busy && progress == null) {
      return const SizedBox.shrink();
    }
    final ended = sitting.isDisposed;
    final percent = NumberFormat.percentPattern(
      Localizations.localeOf(context).toString(),
    );

    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            l10n.media_species_suggested,
            style: Theme.of(context).textTheme.titleSmall,
          ),
          const SizedBox(height: 8),
          // A video's scan takes a while, and finds as it goes: its
          // progress stays above what it has found so far (issue #4675).
          if (progress != null)
            Row(
              children: [
                SizedBox.square(
                  dimension: 16,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    value: progress,
                  ),
                ),
                const SizedBox(width: 8),
                Text(l10n.media_species_scanProgress(percent.format(progress))),
              ],
            )
          else if (busy && suggestions.isEmpty)
            Row(
              children: [
                const SizedBox.square(
                  dimension: 16,
                  child: CircularProgressIndicator(strokeWidth: 2),
                ),
                const SizedBox(width: 8),
                Text(l10n.media_species_identifying),
              ],
            ),
          for (final s in suggestions)
            _SuggestionRow(
              key: ValueKey('media_suggested_row_${s.top.candidate.gbifKey}'),
              item: item,
              suggestion: s,
              percent: percent.format(s.score),
              enabled: !ended,
              sitting: sitting,
            ),
          if (suggestions.isNotEmpty)
            Align(
              alignment: AlignmentDirectional.centerEnd,
              child: TextButton(
                key: const ValueKey('media_suggested_addAll'),
                onPressed: ended
                    ? null
                    : () => addSuggestedSpecies(context, ref, item, [
                        for (final s in suggestions) s.top.candidate,
                      ], sitting),
                child: Text(l10n.media_species_addAll),
              ),
            ),
        ],
      ),
    );
  }
}

class _SuggestionRow extends ConsumerWidget {
  const _SuggestionRow({
    super.key,
    required this.item,
    required this.suggestion,
    required this.percent,
    required this.enabled,
    required this.sitting,
  });

  final MediaItem item;
  final SpeciesSuggestion suggestion;
  final String percent;
  final bool enabled;
  final EditSession<PhotoRecord> sitting;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = context.l10n;
    final candidate = suggestion.top.candidate;
    final key = candidate.gbifKey;
    final name = candidateDisplayName(l10n, candidate);
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        children: [
          InkWell(
            key: ValueKey('media_suggested_crop_$key'),
            borderRadius: BorderRadius.circular(8),
            onTap: () => _showCrop(context, ref),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(8),
              child: SizedBox.square(
                dimension: 48,
                child: IdentificationCrop(
                  mediaId: item.id,
                  identificationId: suggestion.cropIdentificationId,
                ),
              ),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  // One fish swimming out of a video and back is two
                  // tracks, so a video shows no count (issue #4675).
                  suggestion.count > 1 && !item.isVideo
                      ? l10n.media_species_suggestedCount(
                          name,
                          suggestion.count,
                        )
                      : name,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
                RecordedNearbyLine(
                  request: nearbyRequestForMedia(item),
                  gbifKeys: {key},
                  catalogId: candidate.catalogId,
                ),
              ],
            ),
          ),
          Text(percent, style: Theme.of(context).textTheme.bodySmall),
          const SizedBox(width: 4),
          TextButton(
            key: ValueKey('media_suggested_add_$key'),
            onPressed: enabled
                ? () => addSuggestedSpecies(context, ref, item, [
                    candidate,
                  ], sitting)
                : null,
            child: Text(l10n.media_species_add),
          ),
          IconButton(
            key: ValueKey('media_suggested_dismiss_$key'),
            tooltip: l10n.media_species_dismiss,
            icon: const Icon(Icons.close),
            onPressed: enabled
                ? () => ref
                      .read(mediaIdentificationServiceProvider)
                      .reject(item.id, suggestion.identificationIds)
                : null,
          ),
        ],
      ),
    );
  }

  Future<void> _showCrop(BuildContext context, WidgetRef ref) =>
      showModalBottomSheet<void>(
        context: context,
        useSafeArea: true,
        isScrollControlled: true,
        builder: (sheetContext) => SuggestionCropView(
          item: item,
          suggestion: suggestion,
          sitting: sitting,
        ),
      );
}

/// A suggestion's crop shown large, with up to three names to add.
///
/// Opened from a fish's pill over a video, with its [trackId] (issue
/// #4675): every name added is recorded against that fish, and the view
/// also offers any other species and dismissing the fish.
class SuggestionCropView extends ConsumerWidget {
  const SuggestionCropView({
    super.key,
    required this.item,
    required this.suggestion,
    required this.sitting,
    this.trackId,
  });

  final MediaItem item;
  final SpeciesSuggestion suggestion;
  final EditSession<PhotoRecord> sitting;
  final String? trackId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = context.l10n;
    final percent = NumberFormat.percentPattern(
      Localizations.localeOf(context).toString(),
    );
    final ended = sitting.isDisposed;
    return ListView(
      shrinkWrap: true,
      padding: const EdgeInsets.all(16),
      children: [
        ClipRRect(
          borderRadius: BorderRadius.circular(12),
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxHeight: 320),
            child: IdentificationCrop(
              mediaId: item.id,
              identificationId: suggestion.cropIdentificationId,
              fit: BoxFit.contain,
              showReason: true,
            ),
          ),
        ),
        const SizedBox(height: 16),
        Text(
          l10n.media_species_possibleMatches,
          style: Theme.of(context).textTheme.titleSmall,
        ),
        for (final alternative in suggestion.alternatives)
          ListTile(
            key: ValueKey(
              'media_suggested_candidate_${alternative.candidate.gbifKey}',
            ),
            contentPadding: EdgeInsets.zero,
            title: Text(candidateDisplayName(l10n, alternative.candidate)),
            subtitle: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(alternative.candidate.scientificName),
                RecordedNearbyLine(
                  request: nearbyRequestForMedia(item),
                  gbifKeys: {alternative.candidate.gbifKey},
                  catalogId: alternative.candidate.catalogId,
                ),
              ],
            ),
            trailing: SizedBox(
              width: 120,
              child: Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  Text(percent.format(alternative.score)),
                  TextButton(
                    onPressed: ended
                        ? null
                        : () {
                            // Started before the pop: it reads what it
                            // needs at once, and outlives this view.
                            unawaited(
                              addSuggestedSpecies(
                                context,
                                ref,
                                item,
                                [alternative.candidate],
                                sitting,
                                claimTrackId: trackId,
                              ),
                            );
                            Navigator.of(context).pop();
                          },
                    child: Text(l10n.media_species_add),
                  ),
                ],
              ),
            ),
          ),
        if (trackId case final track?) ...[
          const SizedBox(height: 8),
          Row(
            children: [
              Expanded(
                child: OutlinedButton.icon(
                  key: const ValueKey('video_label_other'),
                  icon: const Icon(Icons.search),
                  label: Text(l10n.media_species_otherSpecies),
                  onPressed: ended
                      ? null
                      : () => pickOtherSpecies(
                          context,
                          ref,
                          item,
                          sitting,
                          onPicked: (species) async {
                            await ref
                                .read(mediaIdentificationServiceProvider)
                                .claim(item.id, track, species.id);
                            if (context.mounted) Navigator.of(context).pop();
                          },
                        ),
                ),
              ),
              const SizedBox(width: 8),
              TextButton.icon(
                key: const ValueKey('video_label_dismiss'),
                icon: const Icon(Icons.close),
                label: Text(l10n.media_species_dismiss),
                onPressed: ended
                    ? null
                    : () {
                        unawaited(
                          ref.read(mediaIdentificationServiceProvider).reject(
                            item.id,
                            [track],
                          ),
                        );
                        Navigator.of(context).pop();
                      },
              ),
            ],
          ),
        ],
      ],
    );
  }
}

/// An identification's crop, or a placeholder when it is not on this
/// device.
class IdentificationCrop extends ConsumerWidget {
  const IdentificationCrop({
    super.key,
    required this.mediaId,
    required this.identificationId,
    this.fit = BoxFit.cover,
    this.showReason = false,
  });

  final String mediaId;
  final String identificationId;
  final BoxFit fit;

  /// Says why there is no image, not just a placeholder icon.
  final bool showReason;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final crop = ref
        .watch(identificationCropProvider((mediaId, identificationId)))
        .value;
    final placeholder = _Placeholder(showReason: showReason);
    return switch (crop) {
      null => placeholder,
      CropFile(:final file) => Image.file(
        file,
        fit: fit,
        errorBuilder: (_, _, _) => placeholder,
      ),
      CropBytes(:final bytes) => Image.memory(
        bytes,
        fit: fit,
        errorBuilder: (_, _, _) => placeholder,
      ),
    };
  }
}

class _Placeholder extends StatelessWidget {
  const _Placeholder({required this.showReason});

  final bool showReason;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return ColoredBox(
      color: scheme.surfaceContainerHighest,
      child: Center(
        child: Padding(
          padding: const EdgeInsets.all(8),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                Icons.image_not_supported_outlined,
                color: scheme.onSurfaceVariant,
              ),
              if (showReason) ...[
                const SizedBox(height: 8),
                Text(
                  context.l10n.media_species_cropUnavailable,
                  textAlign: TextAlign.center,
                  style: TextStyle(color: scheme.onSurfaceVariant),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}
