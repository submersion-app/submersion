import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:submersion/core/providers/provider.dart';

import 'package:submersion/features/marine_life/presentation/species_display.dart';
import 'package:submersion/features/marine_life/presentation/utils/species_category_icon.dart';
import 'package:submersion/features/media/domain/entities/photo_record.dart';
import 'package:submersion/features/media/presentation/editing/photo_sitting_shown.dart';
import 'package:submersion/l10n/l10n_extension.dart';
import 'package:submersion/shared/widgets/record_editing/edit_session.dart';

/// The species tagged on a photo, as a wrapping row of chips over the
/// viewer's dark overlay. Tapping a chip opens the species. Renders nothing
/// when the photo has no tags.
class MediaSpeciesChipsRow extends ConsumerWidget {
  final String mediaId;

  /// The photo's sitting, whose held tags are shown instead of the stored
  /// ones (issue #4527).
  final EditSession<PhotoRecord>? sitting;

  const MediaSpeciesChipsRow({super.key, required this.mediaId, this.sitting});

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
    if (chips.isEmpty) return const SizedBox.shrink();

    return Semantics(
      label: l10n.media_species_chipsLabel,
      child: Padding(
        padding: const EdgeInsets.only(bottom: 8),
        child: Wrap(
          spacing: 8,
          runSpacing: 4,
          children: [
            for (final chip in chips)
              ActionChip(
                avatar: ExcludeSemantics(
                  child: Icon(iconForSpeciesCategory(chip.category), size: 16),
                ),
                label: Text(
                  localizedSpeciesName(l10n, chip.speciesId, chip.storedName),
                ),
                onPressed: () => context.push('/species/${chip.speciesId}'),
                materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                visualDensity: VisualDensity.compact,
              ),
          ],
        ),
      ),
    );
  }
}
