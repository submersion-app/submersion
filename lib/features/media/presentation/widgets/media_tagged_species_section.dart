import 'package:flutter/material.dart';

import 'package:submersion/core/providers/provider.dart';
import 'package:submersion/features/marine_life/presentation/providers/species_providers.dart';
import 'package:submersion/features/marine_life/presentation/species_display.dart';
import 'package:submersion/features/media/domain/entities/media_item.dart';
import 'package:submersion/features/media/domain/entities/photo_record.dart';
import 'package:submersion/features/media/domain/entities/species_tag_chip.dart';
import 'package:submersion/features/media/presentation/editing/photo_sitting_shown.dart';
import 'package:submersion/features/media/presentation/widgets/media_species_sheet.dart';
import 'package:submersion/l10n/l10n_extension.dart';
import 'package:submersion/shared/widgets/dashed_outline_painter.dart';
import 'package:submersion/shared/widgets/record_editing/edit_session.dart';

/// The species sheet's "Tagged on this photo" section: the photo's tags
/// that are not among its dive's sightings, each with a remove control.
///
/// Before it, such a tag (and every tag on a photo with no dive) could not
/// be removed in the viewer at all; suggestions make that easy to hit
/// (issue #4668). Renders nothing when there are none. A removal is held in
/// the photo's sitting until the viewer's Save (issue #4527).
class MediaTaggedSpeciesSection extends ConsumerWidget {
  const MediaTaggedSpeciesSection({
    super.key,
    required this.item,
    required this.sitting,
  });

  final MediaItem item;
  final EditSession<PhotoRecord> sitting;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = context.l10n;
    final diveId = item.diveId;
    final sighted = diveId == null
        ? const <String>{}
        : {
            for (final s
                in ref.watch(diveSightingsProvider(diveId)).value ?? const [])
              s.speciesId,
          };
    final shown = speciesChipsShown(ref, item.id, sitting);
    // The app's unconfirmed tags first, sighted or not: this is where the
    // diver confirms them (issue #4727).
    final others = [
      for (final chip in shown)
        if (chip.unconfirmed) chip,
      for (final chip in shown)
        if (!chip.unconfirmed && !sighted.contains(chip.speciesId)) chip,
    ];
    if (others.isEmpty) return const SizedBox.shrink();
    final ended = sitting.isDisposed;

    return Padding(
      padding: const EdgeInsets.only(top: 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            l10n.media_species_taggedOnPhoto,
            style: Theme.of(context).textTheme.titleSmall,
          ),
          const SizedBox(height: 8),
          Wrap(
            spacing: 8,
            runSpacing: 4,
            children: [
              for (final chip in others)
                if (chip.unconfirmed)
                  _UnconfirmedTag(chip: chip, sitting: sitting, ended: ended)
                else
                  Chip(
                    label: Text(
                      localizedSpeciesName(
                        l10n,
                        chip.speciesId,
                        chip.storedName,
                      ),
                    ),
                    deleteIcon: Icon(
                      Icons.close,
                      size: 18,
                      key: ValueKey('media_tagged_remove_${chip.speciesId}'),
                    ),
                    deleteButtonTooltipMessage: l10n.media_species_removeTag(
                      localizedSpeciesName(
                        l10n,
                        chip.speciesId,
                        chip.storedName,
                      ),
                    ),
                    onDeleted: ended
                        ? null
                        : () => holdSpeciesUntagged(sitting, chip),
                  ),
            ],
          ),
        ],
      ),
    );
  }
}

/// A tag the app applied, with Confirm and remove, both held in the sitting.
class _UnconfirmedTag extends StatelessWidget {
  const _UnconfirmedTag({
    required this.chip,
    required this.sitting,
    required this.ended,
  });

  final SpeciesTagChip chip;
  final EditSession<PhotoRecord> sitting;
  final bool ended;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final name = localizedSpeciesName(l10n, chip.speciesId, chip.storedName);
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        CustomPaint(
          foregroundPainter: DashedOutlinePainter(
            color: Theme.of(context).colorScheme.outline,
            radius: 8,
          ),
          child: Chip(
            avatar: const Icon(Icons.auto_awesome_outlined, size: 16),
            // On the label, not over the chip: its remove action stays a
            // node of its own for a screen reader.
            label: Text(
              name,
              semanticsLabel: l10n.media_species_unconfirmedLabel(name),
            ),
            side: BorderSide.none,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(8),
            ),
            // The dashes trace the chip itself, not a padded tap area; the
            // row's Confirm button keeps the line its full height.
            materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
            deleteIcon: Icon(
              Icons.close,
              size: 18,
              key: ValueKey('media_tagged_remove_${chip.speciesId}'),
            ),
            deleteButtonTooltipMessage: l10n.media_species_removeTag(name),
            onDeleted: ended ? null : () => holdSpeciesUntagged(sitting, chip),
          ),
        ),
        const SizedBox(width: 4),
        TextButton(
          key: ValueKey('media_tagged_confirm_${chip.speciesId}'),
          onPressed: ended ? null : () => holdSpeciesConfirmed(sitting, chip),
          child: Text(
            l10n.media_species_confirm,
            semanticsLabel: l10n.media_species_confirmTag(name),
          ),
        ),
      ],
    );
  }
}
