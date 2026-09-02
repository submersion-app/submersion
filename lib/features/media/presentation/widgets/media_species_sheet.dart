import 'package:flutter/material.dart';
import 'package:submersion/core/providers/provider.dart';

import 'package:submersion/core/constants/enums.dart';
import 'package:submersion/features/dive_log/presentation/widgets/pickers/species_picker_sheet.dart';
import 'package:submersion/features/marine_life/presentation/providers/species_providers.dart';
import 'package:submersion/features/marine_life/presentation/species_display.dart';
import 'package:submersion/features/marine_life/presentation/utils/species_category_icon.dart';
import 'package:submersion/features/media/domain/entities/media_item.dart';
import 'package:submersion/features/media/presentation/providers/species_media_providers.dart';
import 'package:submersion/l10n/l10n_extension.dart';

/// Opens the species sheet for [item], the same modal shape as the info
/// sheet: every transient panel in the app is a bottom sheet at every width.
Future<void> showMediaSpeciesSheet(BuildContext context, MediaItem item) =>
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      builder: (_) => DraggableScrollableSheet(
        initialChildSize: 0.5,
        minChildSize: 0.3,
        maxChildSize: 0.9,
        expand: false,
        builder: (_, controller) =>
            MediaSpeciesSheet(item: item, scrollController: controller),
      ),
    );

/// Tag a photo with species. The dive's sightings are one tap away as
/// chips; anything else goes through the species picker, which also logs
/// the sighting on the dive (a photo is evidence).
class MediaSpeciesSheet extends ConsumerWidget {
  final MediaItem item;
  final ScrollController? scrollController;

  const MediaSpeciesSheet({
    super.key,
    required this.item,
    this.scrollController,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = context.l10n;
    final diveId = item.diveId;
    final tagged = {
      for (final chip
          in ref.watch(mediaTagChipsProvider(item.id)).value ?? const [])
        chip.speciesId,
    };
    final sightings = diveId == null
        ? null
        : ref.watch(diveSightingsProvider(diveId)).value ?? const [];

    return ListView(
      controller: scrollController,
      padding: const EdgeInsets.all(16),
      children: [
        Text(
          l10n.media_species_sheetTitle,
          style: Theme.of(context).textTheme.titleLarge,
        ),
        const SizedBox(height: 16),
        if (sightings == null)
          Text(l10n.media_species_noDiveHint)
        else ...[
          Text(
            l10n.media_species_sightedOnDive,
            style: Theme.of(context).textTheme.titleSmall,
          ),
          const SizedBox(height: 8),
          Wrap(
            spacing: 8,
            runSpacing: 4,
            children: [
              for (final sighting in sightings)
                FilterChip(
                  avatar: ExcludeSemantics(
                    child: Icon(
                      iconForSpeciesCategory(
                        sighting.speciesCategory ?? SpeciesCategory.other,
                      ),
                      size: 16,
                    ),
                  ),
                  label: Text(
                    localizedSpeciesName(
                      l10n,
                      sighting.speciesId,
                      sighting.speciesName,
                    ),
                  ),
                  selected: tagged.contains(sighting.speciesId),
                  onSelected: (selected) => _toggle(
                    ref,
                    speciesId: sighting.speciesId,
                    selected: selected,
                  ),
                ),
            ],
          ),
        ],
        const SizedBox(height: 16),
        OutlinedButton.icon(
          key: const ValueKey('media_species_other'),
          icon: const Icon(Icons.search),
          label: Text(l10n.media_species_otherSpecies),
          onPressed: () => _pickOther(context, ref),
        ),
      ],
    );
  }

  Future<void> _toggle(
    WidgetRef ref, {
    required String speciesId,
    required bool selected,
  }) async {
    final service = ref.read(speciesTaggingServiceProvider);
    if (selected) {
      await service.tagPhoto(mediaId: item.id, speciesId: speciesId);
    } else {
      await service.untagPhoto(mediaId: item.id, speciesId: speciesId);
    }
  }

  Future<void> _pickOther(BuildContext context, WidgetRef ref) async {
    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      builder: (sheetContext) => DraggableScrollableSheet(
        initialChildSize: 0.7,
        minChildSize: 0.5,
        maxChildSize: 0.95,
        expand: false,
        builder: (_, controller) => SpeciesPickerSheet(
          scrollController: controller,
          onSpeciesSelected: (species, count, notes) async {
            Navigator.of(sheetContext).pop();
            try {
              await ref
                  .read(speciesTaggingServiceProvider)
                  .tagPhoto(mediaId: item.id, speciesId: species.id);
            } catch (_) {
              // The picker is gone by now; tell the diver the tag did not
              // stick instead of failing silently.
              if (!context.mounted) return;
              ScaffoldMessenger.maybeOf(context)?.showSnackBar(
                SnackBar(content: Text(context.l10n.common_error_tryAgain)),
              );
            }
          },
        ),
      ),
    );
  }
}
