import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:submersion/core/constants/feature_flags.dart';
import 'package:submersion/core/providers/provider.dart';

import 'package:submersion/features/marine_life/presentation/species_display.dart';
import 'package:submersion/features/marine_life/presentation/utils/species_category_icon.dart';
import 'package:submersion/features/media/domain/entities/media_item.dart';
import 'package:submersion/features/media/domain/entities/photo_record.dart';
import 'package:submersion/features/media/presentation/editing/photo_sitting_shown.dart';
import 'package:submersion/features/species_id/domain/entities/media_identification.dart';
import 'package:submersion/features/species_id/presentation/providers/recorded_nearby_providers.dart';
import 'package:submersion/features/species_id/presentation/widgets/recorded_nearby_pin.dart';
import 'package:submersion/features/species_id/presentation/widgets/suggested_species_section.dart';
import 'package:submersion/features/media/domain/entities/species_tag_chip.dart';
import 'package:submersion/features/media/presentation/widgets/viewer_tag_chips.dart';
import 'package:submersion/l10n/l10n_extension.dart';
import 'package:submersion/shared/widgets/dashed_outline_painter.dart';
import 'package:submersion/shared/widgets/one_line_overflow_row.dart';
import 'package:submersion/shared/widgets/record_editing/edit_session.dart';

/// The species tagged on a photo, as one line of chips over the viewer's
/// dark overlay, followed by the species the app suggests (issue #4668).
/// Tapping a tag opens the species. Renders nothing when there is neither.
///
/// The line never wraps (issue #4825): what does not fit is counted in a
/// "+N" chip, which calls [onMoreTap], so the panel under a video's scrub
/// bar never grows with the number of species. The chips are the viewer's
/// compact, translucent ones (issue #4921).
class MediaSpeciesChipsRow extends ConsumerWidget {
  final String mediaId;

  /// The photo's sitting, whose held tags are shown instead of the stored
  /// ones (issue #4527).
  final EditSession<PhotoRecord>? sitting;

  /// Opens the species sheet from a suggestion, or from a tag the app
  /// applied that awaits the diver's confirm (issue #4727); null leaves both
  /// shown but inert, as on a locked photo.
  final VoidCallback? onSuggestionTap;

  /// Opens the whole list, from the "+N" chip; null leaves it inert.
  final VoidCallback? onMoreTap;

  /// The photo itself, whose dive or position picks the "Recorded nearby"
  /// list that marks a suggestion (issue #4668); null marks none.
  final MediaItem? item;

  const MediaSpeciesChipsRow({
    super.key,
    required this.mediaId,
    this.sitting,
    this.onSuggestionTap,
    this.onMoreTap,
    this.item,
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
    final item = this.item;
    final chips = speciesChipWidgets(
      context,
      ref,
      mediaId,
      sitting,
      onSuggestionTap: onSuggestionTap,
      nearbyRequest: item == null ? null : nearbyRequestForMedia(item),
      overlay: true,
    );
    if (chips.isEmpty) return const SizedBox.shrink();
    final row = Semantics(
      label: l10n.media_species_chipsLabel,
      child: Padding(
        padding: const EdgeInsets.only(bottom: 8),
        child: OneLineOverflowRow(
          overflowBuilder: (context, hidden) => Semantics(
            key: const ValueKey('media_species_more'),
            container: true,
            label: l10n.media_species_moreChips(hidden),
            // A button only when it opens something.
            button: onMoreTap != null,
            excludeSemantics: true,
            onTap: onMoreTap,
            // Never faded when inert, as a suggestion is not.
            child: _chip(
              overlay: true,
              label: Text('+$hidden'),
              onPressed: onMoreTap,
              density: ViewerTagChips.density,
            ),
          ),
          children: chips,
        ),
      ),
    );
    return ViewerTagChips.theme(context, child: row);
  }
}

/// The chips for [mediaId]'s species, in the order the viewer shows them:
/// the diver's tags, the app's tags not yet confirmed, then the app's
/// suggestions. A tag opens its species page; the others call
/// [onSuggestionTap], and are inert without it. [openUnconfirmed] has the
/// app's tags open their species page instead, as the diver's do. A
/// suggestion on the "Recorded nearby" list read for [nearbyRequest] ends
/// with a pin. [overlay] draws them as the viewer's compact chips over the
/// picture, under a [ViewerTagChips.theme] (issue #4921).
List<Widget> speciesChipWidgets(
  BuildContext context,
  WidgetRef ref,
  String mediaId,
  EditSession<PhotoRecord>? sitting, {
  VoidCallback? onSuggestionTap,
  bool openUnconfirmed = false,
  NearbyListRequest? nearbyRequest,
  bool overlay = false,
}) {
  final l10n = context.l10n;
  final chips = speciesChipsShown(ref, mediaId, sitting);
  final suggestions = marineLifeLabelsShown
      ? suggestionsShown(ref, mediaId, sitting)
      : const <SpeciesSuggestion>[];
  final outline = overlay
      ? ViewerTagChips.outline
      : Theme.of(context).colorScheme.outline;
  final density = overlay ? ViewerTagChips.density : VisualDensity.compact;
  final iconSize = overlay ? ViewerTagChips.iconSize : 16.0;
  return [
    for (final chip in chips)
      if (!chip.unconfirmed)
        ActionChip(
          avatar: ExcludeSemantics(
            child: Icon(iconForSpeciesCategory(chip.category), size: iconSize),
          ),
          label: Text(
            localizedSpeciesName(l10n, chip.speciesId, chip.storedName),
          ),
          onPressed: () => context.push('/species/${chip.speciesId}'),
          materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
          visualDensity: density,
        ),
    // Tags the app applied, not yet confirmed (issue #4727).
    for (final chip in chips)
      if (chip.unconfirmed)
        _UnconfirmedChip(
          chip: chip,
          onTap: openUnconfirmed
              ? () => context.push('/species/${chip.speciesId}')
              : onSuggestionTap,
          overlay: overlay,
        ),
    for (final s in suggestions)
      _chip(
        overlay: overlay,
        key: ValueKey('media_suggested_chip_${s.top.candidate.gbifKey}'),
        avatar: ExcludeSemantics(child: Icon(Icons.add, size: iconSize)),
        label: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              l10n.media_species_suggestedChip(
                candidateDisplayName(l10n, s.top.candidate),
                (s.score * 100).round(),
              ),
            ),
            if (nearbyRequest != null)
              RecordedNearbyPin(
                request: nearbyRequest,
                gbifKey: s.top.candidate.gbifKey,
                catalogId: s.top.candidate.catalogId,
                size: iconSize,
              ),
          ],
        ),
        // Unfilled on a sheet; over the picture the viewer's fill.
        backgroundColor: overlay ? null : Colors.transparent,
        side: BorderSide(color: outline),
        onPressed: onSuggestionTap,
        density: density,
      ),
  ];
}

/// A chip that answers [onPressed]; over the picture with none, a plain
/// [Chip] instead. A disabled [ActionChip] fades its label and icon to
/// 38%, lost over a bright picture, and on a locked photo, as the viewer
/// opens, every suggestion is inert (issue #4921). Off the picture an
/// inert chip stays a disabled [ActionChip], as before.
Widget _chip({
  Key? key,
  required bool overlay,
  Widget? avatar,
  required Widget label,
  required VoidCallback? onPressed,
  required VisualDensity density,
  BorderSide? side,
  Color? backgroundColor,
  OutlinedBorder? shape,
}) {
  if (overlay && onPressed == null) {
    return Chip(
      key: key,
      avatar: avatar,
      label: label,
      side: side,
      backgroundColor: backgroundColor,
      shape: shape,
      materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
      visualDensity: density,
    );
  }
  return ActionChip(
    key: key,
    avatar: avatar,
    label: label,
    side: side,
    backgroundColor: backgroundColor,
    shape: shape,
    onPressed: onPressed,
    materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
    visualDensity: density,
  );
}

/// A species tag the app applied and the diver has not confirmed: drawn
/// like a tag, with a dashed outline and a small mark, so it never passes
/// for the diver's own (issue #4727). Tapping opens the species sheet,
/// where it can be confirmed; inert on a locked photo.
class _UnconfirmedChip extends StatelessWidget {
  const _UnconfirmedChip({
    required this.chip,
    required this.onTap,
    required this.overlay,
  });

  final SpeciesTagChip chip;
  final VoidCallback? onTap;

  /// Drawn as the viewer's compact chip over the picture (issue #4921).
  final bool overlay;

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
          color: overlay
              ? ViewerTagChips.outline
              : Theme.of(context).colorScheme.outline,
          radius: _radius,
        ),
        child: _chip(
          overlay: overlay,
          avatar: Icon(
            Icons.auto_awesome_outlined,
            size: overlay ? ViewerTagChips.iconSize : 16,
          ),
          label: Text(name),
          side: BorderSide.none,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(_radius),
          ),
          onPressed: onTap,
          density: overlay ? ViewerTagChips.density : VisualDensity.compact,
        ),
      ),
    );
  }
}
