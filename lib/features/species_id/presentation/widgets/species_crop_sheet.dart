import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import 'package:submersion/core/constants/feature_flags.dart';
import 'package:submersion/core/providers/provider.dart';
import 'package:submersion/features/marine_life/presentation/providers/species_providers.dart';
import 'package:submersion/features/marine_life/presentation/species_display.dart';
import 'package:submersion/features/media/domain/entities/media_item.dart';
import 'package:submersion/features/media/domain/entities/species_tag_chip.dart';
import 'package:submersion/features/species_id/domain/entities/media_identification.dart';
import 'package:submersion/features/species_id/domain/services/species_crops.dart';
import 'package:submersion/features/species_id/presentation/providers/species_id_providers.dart';
import 'package:submersion/features/species_id/presentation/widgets/suggested_species_section.dart';
import 'package:submersion/l10n/l10n_extension.dart';

/// Opens what [chip]'s species looks like on [item], a locked photo or
/// video (issue #5024): its crops in a sheet, or the species page when
/// there is none to show (a tag added by hand, or labels off).
Future<void> openSpeciesCrops(
  BuildContext context,
  WidgetRef ref, {
  required MediaItem item,
  required SpeciesTagChip chip,
}) async {
  final speciesPage = '/species/${chip.speciesId}';
  if (!marineLifeLabelsShown) {
    context.push(speciesPage);
    return;
  }
  // Read once, at the tap: the photo is locked, so its tags hold still.
  final identifications = await ref
      .read(mediaIdentificationRepositoryProvider)
      .forMedia(item.id);
  if (!context.mounted) return;
  final crops = cropsOfSpecies(identifications, chip.speciesId);
  if (crops.isEmpty) {
    context.push(speciesPage);
    return;
  }
  await showModalBottomSheet<void>(
    context: context,
    useSafeArea: true,
    isScrollControlled: true,
    builder: (_) => SpeciesCropSheet(item: item, chip: chip, crops: crops),
  );
}

/// What one species looks like on a photo or video: its crops, large,
/// with the way to its species page (issue #5024).
class SpeciesCropSheet extends ConsumerStatefulWidget {
  const SpeciesCropSheet({
    super.key,
    required this.item,
    required this.chip,
    required this.crops,
  });

  final MediaItem item;
  final SpeciesTagChip chip;

  /// Never empty, in the order [cropsOfSpecies] gives.
  final List<MediaIdentification> crops;

  @override
  ConsumerState<SpeciesCropSheet> createState() => _SpeciesCropSheetState();
}

class _SpeciesCropSheetState extends ConsumerState<SpeciesCropSheet> {
  /// The crop shown large.
  int _selected = 0;

  static const double _largeHeight = 320;
  static const double _thumbSize = 56;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final theme = Theme.of(context);
    final chip = widget.chip;
    final crops = widget.crops;
    final mediaId = widget.item.id;
    final scientific = ref
        .watch(speciesProvider(chip.speciesId))
        .value
        ?.scientificName;
    return SingleChildScrollView(
      key: const ValueKey('species_crop_sheet'),
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            localizedSpeciesName(l10n, chip.speciesId, chip.storedName),
            style: theme.textTheme.titleLarge,
          ),
          if (scientific != null && scientific.isNotEmpty)
            Text(
              scientific,
              style: theme.textTheme.bodyMedium?.copyWith(
                fontStyle: FontStyle.italic,
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
          const SizedBox(height: 16),
          ClipRRect(
            key: const ValueKey('species_crop_large'),
            borderRadius: BorderRadius.circular(12),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxHeight: _largeHeight),
              child: IdentificationCrop(
                // A new crop, not the last one's picture held over.
                key: ValueKey(crops[_selected].id),
                mediaId: mediaId,
                identificationId: crops[_selected].id,
                fit: BoxFit.contain,
                showReason: true,
              ),
            ),
          ),
          if (crops.length > 1) ...[
            const SizedBox(height: 12),
            Text(
              widget.item.isVideo
                  ? l10n.media_species_cropCountVideo(crops.length)
                  : l10n.media_species_cropCountPhoto(crops.length),
              style: theme.textTheme.bodySmall,
            ),
            const SizedBox(height: 8),
            SizedBox(
              height: _thumbSize + 8,
              child: ListView.separated(
                key: const ValueKey('species_crop_thumbs'),
                scrollDirection: Axis.horizontal,
                padding: const EdgeInsets.all(4),
                itemCount: crops.length,
                separatorBuilder: (_, _) => const SizedBox(width: 8),
                itemBuilder: (context, index) =>
                    _thumb(context, index, mediaId),
              ),
            ),
          ],
          const SizedBox(height: 16),
          OutlinedButton.icon(
            key: const ValueKey('species_crop_species_page'),
            icon: const Icon(Icons.chevron_right),
            iconAlignment: IconAlignment.end,
            label: Text(l10n.media_species_openSpeciesPage),
            onPressed: () {
              // The page goes over the viewer, not over this sheet, so Back
              // returns to the photo.
              final router = GoRouter.of(context);
              Navigator.of(context).pop();
              router.push('/species/${chip.speciesId}');
            },
          ),
        ],
      ),
    );
  }

  Widget _thumb(BuildContext context, int index, String mediaId) {
    final selected = index == _selected;
    final id = widget.crops[index].id;
    final scheme = Theme.of(context).colorScheme;
    return Semantics(
      button: true,
      selected: selected,
      label: context.l10n.media_species_cropThumb(
        index + 1,
        widget.crops.length,
      ),
      excludeSemantics: true,
      child: GestureDetector(
        key: ValueKey('species_crop_thumb_$id'),
        onTap: () => setState(() => _selected = index),
        child: Container(
          width: _thumbSize,
          height: _thumbSize,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(8),
            border: Border.all(
              color: selected ? scheme.primary : Colors.transparent,
              width: 2,
            ),
          ),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(6),
            child: IdentificationCrop(mediaId: mediaId, identificationId: id),
          ),
        ),
      ),
    );
  }
}
