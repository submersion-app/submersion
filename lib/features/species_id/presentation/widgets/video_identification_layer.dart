import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:video_player/video_player.dart';

import 'package:submersion/core/constants/feature_flags.dart';
import 'package:submersion/core/providers/provider.dart';
import 'package:submersion/features/marine_life/domain/entities/species.dart';
import 'package:submersion/features/marine_life/presentation/providers/species_providers.dart';
import 'package:submersion/features/media/domain/entities/media_item.dart';
import 'package:submersion/features/media/domain/entities/photo_record.dart';
import 'package:submersion/features/media/presentation/editing/photo_sitting_shown.dart';
import 'package:submersion/features/media/presentation/helpers/face_box_geometry.dart';
import 'package:submersion/features/media/presentation/providers/species_media_providers.dart';
import 'package:submersion/features/media/presentation/widgets/video_playhead_builder.dart';
import 'package:submersion/features/species_id/domain/entities/label_mode.dart';
import 'package:submersion/features/species_id/domain/services/identification_rules.dart';
import 'package:submersion/features/species_id/domain/services/track_labels.dart';
import 'package:submersion/features/species_id/presentation/providers/label_providers.dart';
import 'package:submersion/features/species_id/presentation/providers/species_id_providers.dart';
import 'package:submersion/features/species_id/presentation/widgets/identification_labels.dart';
import 'package:submersion/features/species_id/presentation/widgets/suggested_species_section.dart';
import 'package:submersion/shared/widgets/record_editing/edit_session.dart';

/// Name pills and dots over a video, in step with [playback] (issue
/// #4675).
///
/// Playing, a fish gets a pill when the app could suggest a name or the
/// diver tagged it (issue #4709). Paused, others that look like something
/// get a plain dot as well. The labels mode (issue #4825) can add a dot on
/// every other animal found, or draw nothing. Pills and
/// dots take taps only while paused and [editable]; everywhere else taps
/// fall through to the player. No pill reaches into the [bottomInset] the
/// viewer's controls cover (issue #4762).
class VideoIdentificationLayer extends ConsumerWidget {
  const VideoIdentificationLayer({
    super.key,
    required this.playback,
    required this.item,
    this.sitting,
    required this.editable,
    this.bottomInset = 0,
  });

  final ValueListenable<VideoPlayerValue> playback;
  final MediaItem item;

  /// The video's sitting: its held tags show in the labels before Save.
  final EditSession<PhotoRecord>? sitting;

  /// Whether the viewer allows edits (not a locked video).
  final bool editable;

  /// How far up from this layer's bottom edge the viewer's controls reach:
  /// the scrub bar and the panel under it. Pills stay above it.
  final double bottomInset;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    if (!marineLifeLabelsShown) return const SizedBox.shrink();
    final mode = ref.watch(labelModeNotifierProvider);
    if (mode == LabelMode.off) return const SizedBox.shrink();
    final session = sitting;
    if (session == null || session.isDisposed) {
      return _labels(context, ref, mode);
    }
    return ListenableBuilder(
      listenable: session,
      builder: (context, _) => _labels(context, ref, mode),
    );
  }

  Widget _labels(BuildContext context, WidgetRef ref, LabelMode mode) {
    final tracks = ref.watch(videoTracksProvider(item.id)).value ?? const [];
    if (tracks.isEmpty) return const SizedBox.shrink();
    // What Save would make of the tags shown, worked out in memory; the
    // stored decisions until the tags have loaded, which would otherwise
    // read as none and take every tagged fish's pill away.
    final tagsKnown =
        sittingIsOver(sitting, item.id) ||
        ref.watch(mediaTagChipsProvider(item.id)).hasValue;
    final shown = tagsKnown
        ? decisionsAsShown(
            tracks,
            shownTaggedSpecies(ref, item.id, sitting),
            now: DateTime.now().toUtc(),
          )
        : tracks;
    // The app's tags the diver has not confirmed keep the app's outlined
    // pill (issue #4727).
    final unconfirmed = {
      for (final chip in speciesChipsShown(ref, item.id, sitting))
        if (chip.unconfirmed) chip.speciesId,
    };
    final byId = {for (final t in shown) t.id: t};
    final species = {
      for (final s in ref.watch(allSpeciesProvider).value ?? const <Species>[])
        s.id: s,
    };
    // Labels follow the playhead frame by frame, not the player's position
    // reports a few times a second (issue #4759).
    return VideoPlayheadBuilder(
      playback: playback,
      builder: (context, value, playhead) {
        if (value.size.isEmpty) return const SizedBox.shrink();
        final labels = labelsAt(
          shown,
          playhead.inMilliseconds,
          playing: value.isPlaying,
          mode: mode,
          unconfirmedSpeciesIds: unconfirmed,
        );
        if (labels.isEmpty) return const SizedBox.shrink();
        // A name picked here is held in the video's sitting until Save
        // (issue #4527): the labels take taps only while it is open.
        final session = sitting;
        final holdIn =
            editable &&
                !value.isPlaying &&
                session != null &&
                !session.isDisposed
            ? session
            : null;
        return LayoutBuilder(
          builder: (context, box) {
            final video = containedImageRect(value.size, box.biggest);
            final floor = bottomInset > 0
                ? box.biggest.height - bottomInset
                : null;
            return IdentificationLabels(
              labels: labels,
              byId: byId,
              species: species,
              item: item,
              picture: video,
              floor: floor,
              holdIn: holdIn,
            );
          },
        );
      },
    );
  }
}
