import 'package:flutter/material.dart';

import 'package:submersion/core/providers/provider.dart';
import 'package:submersion/features/marine_life/presentation/providers/species_providers.dart';
import 'package:submersion/features/marine_life/presentation/species_display.dart';
import 'package:submersion/features/media/domain/entities/media_item.dart';
import 'package:submersion/features/media/domain/entities/photo_record.dart';
import 'package:submersion/features/media/presentation/editing/photo_sitting_shown.dart';
import 'package:submersion/features/media/presentation/widgets/media_species_sheet.dart';
import 'package:submersion/l10n/l10n_extension.dart';
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
    final others = [
      for (final chip in speciesChipsShown(ref, item.id, sitting))
        if (!sighted.contains(chip.speciesId)) chip,
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
                Chip(
                  label: Text(
                    localizedSpeciesName(l10n, chip.speciesId, chip.storedName),
                  ),
                  deleteIcon: Icon(
                    Icons.close,
                    size: 18,
                    key: ValueKey('media_tagged_remove_${chip.speciesId}'),
                  ),
                  deleteButtonTooltipMessage: l10n.media_species_removeTag(
                    localizedSpeciesName(l10n, chip.speciesId, chip.storedName),
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
