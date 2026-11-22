import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

import 'package:submersion/core/constants/feature_flags.dart';
import 'package:submersion/core/providers/provider.dart';
import 'package:submersion/features/marine_life/domain/entities/species.dart';
import 'package:submersion/features/marine_life/presentation/providers/species_providers.dart';
import 'package:submersion/features/media/domain/entities/media_item.dart';
import 'package:submersion/features/media/domain/entities/photo_record.dart';
import 'package:submersion/features/media/presentation/editing/photo_sitting_shown.dart';
import 'package:submersion/features/media/presentation/helpers/face_box_geometry.dart';
import 'package:submersion/features/media/presentation/providers/species_media_providers.dart';
import 'package:submersion/features/species_id/domain/entities/label_mode.dart';
import 'package:submersion/features/species_id/domain/services/identification_rules.dart';
import 'package:submersion/features/species_id/domain/services/track_labels.dart';
import 'package:submersion/features/species_id/presentation/providers/label_providers.dart';
import 'package:submersion/features/species_id/presentation/widgets/identification_labels.dart';
import 'package:submersion/features/species_id/presentation/widgets/suggested_species_section.dart';
import 'package:submersion/shared/widgets/record_editing/edit_session.dart';

/// How far a photo is zoomed in (1 shows it whole) and moved, as PhotoView
/// has it: moved by [position], then zoomed about the middle.
typedef PhotoZoom = ({double scale, Offset position});

/// Name pills and dots over a photo (issue #4825), as a paused video has
/// them: the same painter, the same rules, by the labels mode.
///
/// It sits inside the photo's zoom, so it moves with the photo; [zoom] is
/// how far the photo is zoomed in, and the labels are drawn that much
/// smaller, so they keep their size on screen. A label takes a tap only
/// while the photo is [editable] and its [sitting] open, and then through
/// the viewer's own tap layer ([identificationLabelTap]), which lies over
/// the photo. No pill reaches into the [bottomInset] the viewer's controls
/// cover, so it can be tapped.
class PhotoIdentificationLayer extends ConsumerWidget {
  const PhotoIdentificationLayer({
    super.key,
    required this.item,
    required this.imageSize,
    required this.zoom,
    this.sitting,
    required this.editable,
    this.bottomInset = 0,
  });

  final MediaItem item;

  /// The decoded photo's size; null until it is known, when nothing is
  /// drawn.
  final Size? imageSize;

  /// How far the photo is zoomed in and moved.
  final ValueListenable<PhotoZoom> zoom;

  /// The photo's sitting: its held tags show in the labels before Save.
  final EditSession<PhotoRecord>? sitting;

  /// Whether the viewer allows edits (not a locked photo).
  final bool editable;

  /// How far up from the bottom of the view the viewer's controls reach.
  final double bottomInset;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final size = imageSize;
    if (!marineLifeLabelsShown || size == null || size.isEmpty) {
      return const SizedBox.shrink();
    }
    final mode = ref.watch(labelModeNotifierProvider);
    if (mode == LabelMode.off) return const SizedBox.shrink();
    final session = sitting;
    if (session == null || session.isDisposed) {
      return _labels(context, ref, mode, size);
    }
    return ListenableBuilder(
      listenable: session,
      builder: (context, _) => _labels(context, ref, mode, size),
    );
  }

  Widget _labels(
    BuildContext context,
    WidgetRef ref,
    LabelMode mode,
    Size size,
  ) {
    final found = ref.watch(photoDetectionsProvider(item.id)).value ?? const [];
    if (found.isEmpty) return const SizedBox.shrink();
    // What Save would make of the tags shown; the stored decisions until
    // the tags have loaded.
    final tagsKnown =
        sittingIsOver(sitting, item.id) ||
        ref.watch(mediaTagChipsProvider(item.id)).hasValue;
    final shown = tagsKnown
        ? decisionsAsShown(
            found,
            shownTaggedSpecies(ref, item.id, sitting),
            now: DateTime.now().toUtc(),
          )
        : found;
    final labels = photoLabels(
      shown,
      mode: mode,
      unconfirmedSpeciesIds: {
        for (final chip in speciesChipsShown(ref, item.id, sitting))
          if (chip.unconfirmed) chip.speciesId,
      },
    );
    if (labels.isEmpty) return const SizedBox.shrink();
    final byId = {for (final i in shown) i.id: i};
    final species = {
      for (final s in ref.watch(allSpeciesProvider).value ?? const <Species>[])
        s.id: s,
    };
    final session = sitting;
    final holdIn = editable && session != null && !session.isDisposed
        ? session
        : null;
    return ValueListenableBuilder<PhotoZoom>(
      valueListenable: zoom,
      builder: (context, zoomed, _) => LayoutBuilder(
        builder: (context, box) {
          final z = zoomed.scale > 0 ? zoomed.scale : 1.0;
          // The controls' edge on screen, in the zoomed layout's terms: a
          // point q there lands on screen at middle + move + q - middle * z.
          final middle = box.maxHeight / 2;
          final floor = bottomInset > 0
              ? middle * z +
                    (box.maxHeight - bottomInset) -
                    middle -
                    zoomed.position.dy
              : null;
          // Laid out as if the photo were drawn z times as large, then
          // shrunk back into place: positions land where the zoom puts
          // them, and every part keeps its own size on screen.
          final large = box.biggest * z;
          return OverflowBox(
            alignment: Alignment.topLeft,
            minWidth: large.width,
            maxWidth: large.width,
            minHeight: large.height,
            maxHeight: large.height,
            child: Transform.scale(
              scale: 1 / z,
              alignment: Alignment.topLeft,
              child: IdentificationLabels(
                labels: labels,
                byId: byId,
                species: species,
                item: item,
                picture: containedImageRect(size, large),
                floor: floor,
                holdIn: holdIn,
                keyPrefix: 'photo_label',
                tapsByMarker: true,
              ),
            ),
          );
        },
      ),
    );
  }
}
