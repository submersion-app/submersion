import 'package:flutter/material.dart';
import 'package:submersion/core/providers/provider.dart';

import 'package:submersion/core/constants/enums.dart';
import 'package:submersion/features/dive_log/presentation/widgets/pickers/species_picker_sheet.dart';
import 'package:submersion/features/marine_life/presentation/providers/species_providers.dart';
import 'package:submersion/features/marine_life/presentation/species_display.dart';
import 'package:submersion/features/marine_life/presentation/utils/species_category_icon.dart';
import 'package:submersion/features/marine_life/domain/entities/species.dart';
import 'package:submersion/features/media/domain/entities/media_item.dart';
import 'package:submersion/features/media/domain/entities/photo_record.dart';
import 'package:submersion/features/media/domain/entities/species_tag_chip.dart';
import 'package:submersion/features/media/presentation/editing/photo_edit_fields.dart';
import 'package:submersion/features/media/presentation/editing/photo_sitting_shown.dart';
import 'package:submersion/features/media/presentation/providers/species_media_providers.dart';
import 'package:submersion/features/media/presentation/widgets/media_tagged_species_section.dart';
import 'package:submersion/features/species_id/presentation/widgets/suggested_species_section.dart';
import 'package:submersion/l10n/l10n_extension.dart';
import 'package:submersion/shared/widgets/record_editing/edit_session.dart';

/// Opens the species sheet for [item], the same modal shape as the info
/// sheet: every transient panel in the app is a bottom sheet at every width.
///
/// With a [sitting] the sheet changes nothing: what is tagged and untagged
/// is held in it until it is saved (issue #4527).
Future<void> showMediaSpeciesSheet(
  BuildContext context,
  MediaItem item, {
  EditSession<PhotoRecord>? sitting,
}) => showModalBottomSheet<void>(
  context: context,
  isScrollControlled: true,
  useSafeArea: true,
  builder: (_) => DraggableScrollableSheet(
    initialChildSize: 0.5,
    minChildSize: 0.3,
    maxChildSize: 0.9,
    expand: false,
    builder: (_, controller) => MediaSpeciesSheet(
      item: item,
      scrollController: controller,
      sitting: sitting,
    ),
  ),
);

/// Tag a photo with species. The dive's sightings are one tap away as
/// chips; anything else goes through the species picker, which also logs
/// the sighting on the dive (a photo is evidence).
class MediaSpeciesSheet extends ConsumerWidget {
  final MediaItem item;
  final ScrollController? scrollController;

  /// The photo's sitting; null writes each tag at once, as before.
  final EditSession<PhotoRecord>? sitting;

  const MediaSpeciesSheet({
    super.key,
    required this.item,
    this.scrollController,
    this.sitting,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final session = sitting;
    if (session == null || session.isDisposed) return _content(context, ref);
    return ListenableBuilder(
      listenable: session,
      builder: (context, _) => _content(context, ref),
    );
  }

  Widget _content(BuildContext context, WidgetRef ref) {
    final l10n = context.l10n;
    final diveId = item.diveId;
    // A sitting that has ended takes nothing, and does not fall back to
    // writing at once either: that would change the photo outside its lock.
    final ended = sitting?.isDisposed ?? false;
    final tagged = {
      for (final chip in speciesChipsShown(ref, item.id, sitting))
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
        SuggestedSpeciesSection(item: item, sitting: sitting),
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
                  onSelected: ended
                      ? null
                      : (selected) => _toggle(
                          ref,
                          speciesId: sighting.speciesId,
                          selected: selected,
                          // Nothing in the viewer reads isBuiltIn; Save writes the
                          // species id alone.
                          held: SpeciesTagChip(
                            speciesId: sighting.speciesId,
                            storedName: sighting.speciesName,
                            category:
                                sighting.speciesCategory ??
                                SpeciesCategory.other,
                            isBuiltIn: false,
                          ),
                        ),
                ),
            ],
          ),
        ],
        MediaTaggedSpeciesSection(item: item, sitting: sitting),
        const SizedBox(height: 16),
        OutlinedButton.icon(
          key: const ValueKey('media_species_other'),
          icon: const Icon(Icons.search),
          label: Text(l10n.media_species_otherSpecies),
          onPressed: ended ? null : () => _pickOther(context, ref),
        ),
      ],
    );
  }

  Future<void> _toggle(
    WidgetRef ref, {
    required String speciesId,
    required bool selected,
    required SpeciesTagChip held,
  }) async {
    final session = sitting;
    if (session != null) {
      _holdToggle(session, held, tagged: selected);
      return;
    }
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
      useSafeArea: true,
      builder: (sheetContext) => DraggableScrollableSheet(
        initialChildSize: 0.7,
        minChildSize: 0.5,
        maxChildSize: 0.95,
        expand: false,
        builder: (_, controller) => SpeciesPickerSheet(
          scrollController: controller,
          // A tag needs only the species; a sighting it creates is Seen.
          showAbundance: false,
          onSpeciesSelected: (species, _, _) async {
            Navigator.of(sheetContext).pop();
            final session = sitting;
            if (session != null) {
              holdPickedSpecies(session, species);
              return;
            }
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

/// Holds [chip] tagged or untagged in [session]. Does nothing once the
/// sitting has ended or while it is being saved.
void _holdToggle(
  EditSession<PhotoRecord> session,
  SpeciesTagChip chip, {
  required bool tagged,
}) {
  if (session.isDisposed || session.isFrozen) return;
  session.set(
    photoSpeciesField,
    session
        .valueOf(photoSpeciesField)
        .toggled(chip, tagged: tagged, stored: session.stored.species),
  );
}

/// Holds [species], picked from the species picker, as tagged in [session]
/// (issue #4527). A species the picker created stays created whatever the
/// sitting does: creating a record is outside the lock.
void holdPickedSpecies(EditSession<PhotoRecord> session, Species species) =>
    _holdToggle(
      session,
      SpeciesTagChip(
        speciesId: species.id,
        storedName: species.commonName,
        category: species.category,
        isBuiltIn: species.isBuiltIn,
      ),
      tagged: true,
    );

/// Holds [chip] as untagged in [session] (issue #4668). Does nothing once
/// the sitting has ended or while it is being saved.
void holdSpeciesUntagged(
  EditSession<PhotoRecord> session,
  SpeciesTagChip chip,
) => _holdToggle(session, chip, tagged: false);
