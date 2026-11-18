import 'dart:math' as math;

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:video_player/video_player.dart';

import 'package:submersion/core/constants/feature_flags.dart';
import 'package:submersion/core/providers/provider.dart';
import 'package:submersion/features/marine_life/domain/entities/species.dart';
import 'package:submersion/features/marine_life/presentation/providers/species_providers.dart';
import 'package:submersion/features/marine_life/presentation/species_display.dart';
import 'package:submersion/features/media/domain/entities/media_item.dart';
import 'package:submersion/features/media/domain/entities/photo_record.dart';
import 'package:submersion/features/media/presentation/editing/photo_sitting_shown.dart';
import 'package:submersion/features/media/presentation/helpers/face_box_geometry.dart';
import 'package:submersion/features/media/presentation/providers/species_media_providers.dart';
import 'package:submersion/features/media/presentation/widgets/media_species_sheet.dart';
import 'package:submersion/features/species_id/domain/entities/media_identification.dart';
import 'package:submersion/features/species_id/domain/services/identification_rules.dart';
import 'package:submersion/features/species_id/domain/services/track_labels.dart';
import 'package:submersion/features/species_id/presentation/providers/species_id_providers.dart';
import 'package:submersion/features/species_id/presentation/widgets/suggested_species_section.dart';
import 'package:submersion/features/species_id/presentation/widgets/track_label_view.dart';
import 'package:submersion/l10n/l10n_extension.dart';
import 'package:submersion/shared/widgets/record_editing/edit_session.dart';

/// Name pills and dots over a video, in step with [playback] (issue
/// #4675).
///
/// Playing, a fish gets a pill only when the app is confident of its name
/// or the diver tagged it. Paused, every fish the app could name gets a
/// pill, and others that look like something get a plain dot. Pills and
/// dots take taps only while paused and [editable]; everywhere else taps
/// fall through to the player.
class VideoIdentificationLayer extends ConsumerWidget {
  const VideoIdentificationLayer({
    super.key,
    required this.playback,
    required this.item,
    this.sitting,
    required this.editable,
  });

  final ValueListenable<VideoPlayerValue> playback;
  final MediaItem item;

  /// The video's sitting: its held tags show in the labels before Save.
  final EditSession<PhotoRecord>? sitting;

  /// Whether the viewer allows edits (not a locked video).
  final bool editable;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    if (!marineLifeIdEnabled) return const SizedBox.shrink();
    final session = sitting;
    if (session == null || session.isDisposed) return _labels(context, ref);
    return ListenableBuilder(
      listenable: session,
      builder: (context, _) => _labels(context, ref),
    );
  }

  Widget _labels(BuildContext context, WidgetRef ref) {
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
    final byId = {for (final t in shown) t.id: t};
    final species = {
      for (final s in ref.watch(allSpeciesProvider).value ?? const <Species>[])
        s.id: s,
    };
    return ValueListenableBuilder<VideoPlayerValue>(
      valueListenable: playback,
      builder: (context, value, _) {
        if (value.size.isEmpty) return const SizedBox.shrink();
        final labels = labelsAt(
          shown,
          value.position.inMilliseconds,
          playing: value.isPlaying,
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
            return Stack(
              children: [
                for (final label in labels)
                  ..._parts(
                    context,
                    ref,
                    label,
                    byId[label.identificationId]!,
                    species,
                    video,
                    holdIn: holdIn,
                  ),
              ],
            );
          },
        );
      },
    );
  }

  List<Widget> _parts(
    BuildContext context,
    WidgetRef ref,
    TrackLabel label,
    MediaIdentification track,
    Map<String, Species> species,
    Rect video, {
    required EditSession<PhotoRecord>? holdIn,
  }) {
    final l10n = context.l10n;
    final b = label.box;
    final onScreen = Rect.fromLTWH(
      video.left + b.x * video.width,
      video.top + b.y * video.height,
      b.width * video.width,
      b.height * video.height,
    );
    final at = TrackLabelGeometry.of(onScreen, video);
    final dotTarget = touchTarget(at.dot);

    if (label.kind == TrackLabelKind.dot) {
      return [
        Positioned.fromRect(
          rect: dotTarget,
          child: _target(
            key: ValueKey('video_label_dot_${label.identificationId}'),
            label: holdIn != null
                ? l10n.media_species_unnamedFish
                : l10n.media_species_unnamedFishLocked,
            onTap: holdIn == null
                ? null
                : () => pickOtherSpecies(
                    context,
                    ref,
                    item,
                    holdIn,
                    onPicked: (picked) => ref
                        .read(mediaIdentificationServiceProvider)
                        .claim(item.id, track.id, picked.id),
                  ),
            child: const Center(child: TrackDot()),
          ),
        ),
      ];
    }

    final name = label.kind == TrackLabelKind.accepted
        ? _taggedName(context, label.speciesId, species, track)
        : candidateDisplayName(l10n, label.candidate!.candidate);
    final pillEdge =
        at.pillCentre.dy +
        (at.pillBelow ? -1 : 1) * TrackLabelGeometry.pillHeight / 2;
    return [
      Positioned(
        left: at.dot.dx - 0.75,
        top: math.min(at.dot.dy, pillEdge),
        height: (at.dot.dy - pillEdge).abs(),
        child: const IgnorePointer(child: TrackLine()),
      ),
      Positioned.fromRect(
        rect: Rect.fromCenter(
          center: at.dot,
          width: TrackDot.size,
          height: TrackDot.size,
        ),
        child: const IgnorePointer(child: TrackDot()),
      ),
      Positioned.fill(
        child: CustomSingleChildLayout(
          delegate: _PillLayout(centre: at.pillCentre, video: video),
          child: _target(
            key: ValueKey('video_label_pill_${label.identificationId}'),
            label: name,
            onTap: holdIn == null
                ? null
                : () => _openPill(context, ref, label, track, holdIn),
            child: Padding(
              padding: EdgeInsets.symmetric(
                vertical:
                    (dotTarget.height - TrackLabelGeometry.pillHeight) / 2,
              ),
              child: TrackPill(name: name, kind: label.kind),
            ),
          ),
        ),
      ),
    ];
  }

  /// A labelled part: a button while it takes taps, else see-through to
  /// the player under it.
  Widget _target({
    required Key key,
    required String label,
    required VoidCallback? onTap,
    required Widget child,
  }) {
    if (onTap == null) {
      return IgnorePointer(
        key: key,
        child: Semantics(label: label, child: child),
      );
    }
    return Semantics(
      key: key,
      button: true,
      label: label,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: onTap,
        child: child,
      ),
    );
  }

  void _openPill(
    BuildContext context,
    WidgetRef ref,
    TrackLabel label,
    MediaIdentification track,
    EditSession<PhotoRecord> holdIn,
  ) {
    if (label.kind == TrackLabelKind.accepted) {
      final id = label.speciesId;
      if (id != null) context.push('/species/$id');
      return;
    }
    final top = track.top;
    if (top == null) return;
    showModalBottomSheet<void>(
      context: context,
      useSafeArea: true,
      isScrollControlled: true,
      builder: (_) => SuggestionCropView(
        item: item,
        suggestion: SpeciesSuggestion(
          top: top,
          score: top.score,
          count: 1,
          cropIdentificationId: track.id,
          identificationIds: [track.id],
          alternatives: track.candidates.take(suggestionAlternatives).toList(),
        ),
        sitting: holdIn,
        trackId: track.id,
      ),
    );
  }

  /// The tagged species' name as the app shows it; the app's own name for
  /// the fish when the species is not loaded yet.
  static String _taggedName(
    BuildContext context,
    String? speciesId,
    Map<String, Species> species,
    MediaIdentification track,
  ) {
    final l10n = context.l10n;
    final found = speciesId == null ? null : species[speciesId];
    if (found != null) {
      return localizedSpeciesName(l10n, found.id, found.commonName);
    }
    final top = track.top;
    return top == null ? '' : candidateDisplayName(l10n, top.candidate);
  }
}

/// Puts a pill centred on [centre], moved in only as far as needed to stay
/// inside [video], at most as wide as the video.
class _PillLayout extends SingleChildLayoutDelegate {
  const _PillLayout({required this.centre, required this.video});

  final Offset centre;
  final Rect video;

  @override
  BoxConstraints getConstraintsForChild(BoxConstraints constraints) =>
      BoxConstraints.loose(Size(video.width, constraints.maxHeight));

  @override
  Offset getPositionForChild(Size size, Size childSize) {
    final left = math.min(
      math.max(centre.dx - childSize.width / 2, video.left),
      math.max(video.left, video.right - childSize.width),
    );
    return Offset(left, centre.dy - childSize.height / 2);
  }

  @override
  bool shouldRelayout(_PillLayout oldDelegate) =>
      centre != oldDelegate.centre || video != oldDelegate.video;
}
