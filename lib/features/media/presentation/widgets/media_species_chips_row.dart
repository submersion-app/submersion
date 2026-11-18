import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import 'package:submersion/core/constants/feature_flags.dart';
import 'package:submersion/core/providers/provider.dart';

import 'package:submersion/features/marine_life/presentation/species_display.dart';
import 'package:submersion/features/marine_life/presentation/utils/species_category_icon.dart';
import 'package:submersion/features/media/domain/entities/photo_record.dart';
import 'package:submersion/features/media/presentation/editing/photo_sitting_shown.dart';
import 'package:submersion/features/species_id/presentation/providers/species_id_providers.dart';
import 'package:submersion/features/species_id/presentation/widgets/suggested_species_section.dart';
import 'package:submersion/features/media/domain/entities/species_tag_chip.dart';
import 'package:submersion/l10n/l10n_extension.dart';
import 'package:submersion/shared/widgets/dashed_outline_painter.dart';
import 'package:submersion/shared/widgets/record_editing/edit_session.dart';

/// The species tagged on a photo, as a wrapping row of chips over the
/// viewer's dark overlay, followed by the species the app suggests (issue
/// #4668). Tapping a tag opens the species. Renders nothing when there is
/// neither.
class MediaSpeciesChipsRow extends ConsumerWidget {
  final String mediaId;

  /// The photo's sitting, whose held tags are shown instead of the stored
  /// ones (issue #4527).
  final EditSession<PhotoRecord>? sitting;

  /// Opens the species sheet from a suggestion, or from a tag the app
  /// applied that awaits the diver's confirm (issue #4727); null leaves both
  /// shown but inert, as on a locked photo.
  final VoidCallback? onSuggestionTap;

  const MediaSpeciesChipsRow({
    super.key,
    required this.mediaId,
    this.sitting,
    this.onSuggestionTap,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final session = sitting;
    if (session == null) return _chips(context, ref);
    return ListenableBuilder(
      listenable: session,
      builder: (context, _) => _chips(context, ref),
    );
  }

  Widget _chips(BuildContext context, WidgetRef ref) {
    final l10n = context.l10n;
    final chips = speciesChipsShown(ref, mediaId, sitting);
    final suggestions = marineLifeIdEnabled
        ? suggestionsShown(ref, mediaId, sitting)
        : const [];
    final progress = marineLifeIdEnabled
        ? ref.watch(mediaIdentificationProgressProvider(mediaId)).value
        : null;
    if (chips.isEmpty && suggestions.isEmpty && progress == null) {
      return const SizedBox.shrink();
    }
    final outline = Theme.of(context).colorScheme.outline;

    return Semantics(
      label: l10n.media_species_chipsLabel,
      child: Padding(
        padding: const EdgeInsets.only(bottom: 8),
        child: Wrap(
          spacing: 8,
          runSpacing: 4,
          children: [
            for (final chip in chips)
              if (!chip.unconfirmed)
                ActionChip(
                  avatar: ExcludeSemantics(
                    child: Icon(
                      iconForSpeciesCategory(chip.category),
                      size: 16,
                    ),
                  ),
                  label: Text(
                    localizedSpeciesName(l10n, chip.speciesId, chip.storedName),
                  ),
                  onPressed: () => context.push('/species/${chip.speciesId}'),
                  materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                  visualDensity: VisualDensity.compact,
                ),
            // Tags the app applied, not yet confirmed (issue #4727).
            for (final chip in chips)
              if (chip.unconfirmed)
                _UnconfirmedChip(chip: chip, onTap: onSuggestionTap),
            for (final s in suggestions)
              ActionChip(
                key: ValueKey(
                  'media_suggested_chip_${s.top.candidate.gbifKey}',
                ),
                avatar: const ExcludeSemantics(
                  child: Icon(Icons.add, size: 16),
                ),
                label: Text(
                  l10n.media_species_suggestedChip(
                    candidateDisplayName(l10n, s.top.candidate),
                    (s.score * 100).round(),
                  ),
                ),
                backgroundColor: Colors.transparent,
                side: BorderSide(color: outline),
                onPressed: onSuggestionTap,
                materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                visualDensity: VisualDensity.compact,
              ),
            // A video being scanned (issue #4675).
            if (progress != null) _ScanProgressChip(progress: progress),
          ],
        ),
      ),
    );
  }
}

/// A species tag the app applied and the diver has not confirmed: drawn
/// like a tag, with a dashed outline and a small mark, so it never passes
/// for the diver's own (issue #4727). Tapping opens the species sheet,
/// where it can be confirmed; inert on a locked photo.
class _UnconfirmedChip extends StatelessWidget {
  const _UnconfirmedChip({required this.chip, required this.onTap});

  final SpeciesTagChip chip;
  final VoidCallback? onTap;

  static const double _radius = 8;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final name = localizedSpeciesName(l10n, chip.speciesId, chip.storedName);
    return Semantics(
      key: ValueKey('media_unconfirmed_chip_${chip.speciesId}'),
      label: l10n.media_species_unconfirmedLabel(name),
      button: onTap != null,
      excludeSemantics: true,
      onTap: onTap,
      child: CustomPaint(
        foregroundPainter: DashedOutlinePainter(
          color: Theme.of(context).colorScheme.outline,
          radius: _radius,
        ),
        child: ActionChip(
          avatar: const Icon(Icons.auto_awesome_outlined, size: 16),
          label: Text(name),
          side: BorderSide.none,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(_radius),
          ),
          onPressed: onTap,
          materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
          visualDensity: VisualDensity.compact,
        ),
      ),
    );
  }
}

/// How far a video's scan has got: a small ring and a percentage.
class _ScanProgressChip extends StatelessWidget {
  const _ScanProgressChip({required this.progress});

  final double progress;

  @override
  Widget build(BuildContext context) {
    final percent = NumberFormat.percentPattern(
      Localizations.localeOf(context).toString(),
    ).format(progress);
    return Semantics(
      container: true,
      label: context.l10n.media_species_scanProgress(percent),
      excludeSemantics: true,
      child: Chip(
        avatar: SizedBox.square(
          dimension: 14,
          child: CircularProgressIndicator(strokeWidth: 2, value: progress),
        ),
        label: Text(percent),
        backgroundColor: Colors.transparent,
        side: BorderSide(color: Theme.of(context).colorScheme.outline),
        materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
        visualDensity: VisualDensity.compact,
      ),
    );
  }
}
