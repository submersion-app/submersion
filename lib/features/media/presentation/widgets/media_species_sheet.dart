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
import 'package:submersion/features/media/presentation/widgets/media_tagged_species_section.dart';
import 'package:submersion/features/species_id/presentation/widgets/suggested_species_section.dart';
import 'package:submersion/features/species_id/presentation/widgets/species_download_prompt.dart';
import 'package:submersion/l10n/l10n_extension.dart';
import 'package:submersion/shared/widgets/record_editing/edit_session.dart';

/// Opens the species sheet for [item], the same modal shape as the info
/// sheet: every transient panel in the app is a bottom sheet at every width.
///
/// The sheet changes nothing itself: what is tagged and untagged is held in
/// [sitting] until it is saved (issue #4527).
Future<void> showMediaSpeciesSheet(
  BuildContext context,
  MediaItem item, {
  required EditSession<PhotoRecord> sitting,
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
/// the sighting on the dive (a photo is evidence). What is tagged and
/// untagged is held in the photo's sitting until the viewer's Save.
class MediaSpeciesSheet extends ConsumerWidget {
  final MediaItem item;
  final ScrollController? scrollController;

  /// The photo's sitting, which holds the tags chosen.
  final EditSession<PhotoRecord> sitting;

  const MediaSpeciesSheet({
    super.key,
    required this.item,
    this.scrollController,
    required this.sitting,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    if (sitting.isDisposed) return _content(context, ref);
    return ListenableBuilder(
      listenable: sitting,
      builder: (context, _) => _content(context, ref),
    );
  }

  Widget _content(BuildContext context, WidgetRef ref) {
    final l10n = context.l10n;
    final diveId = item.diveId;
    // A sitting that has ended takes nothing: a change then would be made
    // outside the photo's lock.
    final ended = sitting.isDisposed;
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
          item.isVideo
              ? l10n.media_species_sheetTitleVideo
              : l10n.media_species_sheetTitle,
          style: Theme.of(context).textTheme.titleLarge,
        ),
        const SizedBox(height: 16),
        // With no model, the offer to download one (issue #4773).
        const SpeciesDownloadPrompt(),
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
                      : (selected) => _holdToggle(
                          sitting,
                          // Nothing in the viewer reads isBuiltIn; Save writes the
                          // species id alone.
                          SpeciesTagChip(
                            speciesId: sighting.speciesId,
                            storedName: sighting.speciesName,
                            category:
                                sighting.speciesCategory ??
                                SpeciesCategory.other,
                            isBuiltIn: false,
                          ),
                          tagged: selected,
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
          onPressed: ended
              ? null
              : () => pickOtherSpecies(context, ref, item, sitting),
        ),
      ],
    );
  }
}

/// The species picker for [item]: the species picked is held in [sitting]
/// until the viewer's Save (issue #4527). [onPicked] runs first, with the
/// species, before it is held: a fish named from a video's frame is
/// recorded against that fish there (issue #4675).
Future<void> pickOtherSpecies(
  BuildContext context,
  WidgetRef ref,
  MediaItem item,
  EditSession<PhotoRecord> sitting, {
  Future<void> Function(Species species)? onPicked,
}) async {
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
          await onPicked?.call(species);
          holdPickedSpecies(sitting, species);
        },
      ),
    ),
  );
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

/// Holds the app's tag [chip] as confirmed in [session] (issue #4727).
/// Does nothing once the sitting has ended or while it is being saved.
void holdSpeciesConfirmed(
  EditSession<PhotoRecord> session,
  SpeciesTagChip chip,
) {
  if (session.isDisposed || session.isFrozen) return;
  session.set(
    photoSpeciesField,
    session.valueOf(photoSpeciesField).confirming(chip.speciesId),
  );
}

/// Holds [chip] as untagged in [session] (issue #4668). Does nothing once
/// the sitting has ended or while it is being saved.
void holdSpeciesUntagged(
  EditSession<PhotoRecord> session,
  SpeciesTagChip chip,
) => _holdToggle(session, chip, tagged: false);
