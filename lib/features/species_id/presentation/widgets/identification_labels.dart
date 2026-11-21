import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:go_router/go_router.dart';

import 'package:submersion/core/providers/provider.dart';
import 'package:submersion/features/marine_life/domain/entities/species.dart';
import 'package:submersion/features/marine_life/presentation/species_display.dart';
import 'package:submersion/features/media/domain/entities/media_item.dart';
import 'package:submersion/features/media/domain/entities/photo_record.dart';
import 'package:submersion/features/media/presentation/widgets/media_species_sheet.dart';
import 'package:submersion/features/species_id/domain/entities/media_identification.dart';
import 'package:submersion/features/species_id/domain/services/identification_rules.dart';
import 'package:submersion/features/species_id/domain/services/track_labels.dart';
import 'package:submersion/features/species_id/presentation/providers/species_id_providers.dart';
import 'package:submersion/features/species_id/presentation/widgets/suggested_species_section.dart';
import 'package:submersion/features/species_id/presentation/widgets/track_label_view.dart';
import 'package:submersion/l10n/l10n_extension.dart';
import 'package:submersion/shared/widgets/record_editing/edit_session.dart';

/// What a tap on a label does, where the label cannot take the tap itself
/// ([IdentificationLabels.tapsByMarker]); [identificationLabelTap] finds
/// it.
class LabelTap {
  const LabelTap(this.onTap);

  final VoidCallback onTap;
}

/// Runs the label under [globalPosition] in the view [viewId], if there is
/// one that takes taps. Returns whether one was run.
///
/// For a photo (issue #4825): the viewer's own tap layer lies over the
/// photo and takes every tap, so it asks here first. Looking the label up
/// by a hit test finds it wherever the photo is zoomed or moved to. The
/// view is passed in, not looked up: a tap can land once the layer that
/// took it has left the tree.
bool identificationLabelTap(int viewId, Offset globalPosition) {
  final result = HitTestResult();
  WidgetsBinding.instance.hitTestInView(result, globalPosition, viewId);
  for (final entry in result.path) {
    final target = entry.target;
    if (target is RenderMetaData) {
      final tap = target.metaData;
      if (tap is LabelTap) {
        tap.onTap();
        return true;
      }
    }
  }
  return false;
}

/// Name pills and dots for [labels], over the [picture] they belong to: a
/// video's frame or a photo (issues #4675, #4825). Shared by both, so they
/// look and behave the same.
///
/// A pill or dot takes taps only when [holdIn] is given: the sitting a
/// name picked on it is held in until Save (issue #4527). A suggestion's
/// pill opens its crop view, a tagged one its species page, and a dot the
/// species picker, naming that animal. Without it they are see-through to
/// whatever is under them. No pill reaches below [floor] (issue #4762).
class IdentificationLabels extends ConsumerWidget {
  const IdentificationLabels({
    super.key,
    required this.labels,
    required this.byId,
    required this.species,
    required this.item,
    required this.picture,
    this.floor,
    this.holdIn,
    this.keyPrefix = 'video_label',
    this.tapsByMarker = false,
  });

  final List<TrackLabel> labels;

  /// The animals the labels are for, by identification id.
  final Map<String, MediaIdentification> byId;

  /// The catalogue's species by id, for a tagged animal's name.
  final Map<String, Species> species;
  final MediaItem item;

  /// The rect the picture is drawn in, in this widget's own space.
  final Rect picture;

  /// Where the viewer's controls begin, when they cover the picture.
  final double? floor;

  /// The open sitting, when labels take taps.
  final EditSession<PhotoRecord>? holdIn;

  /// Names the parts' keys: `<prefix>_dot_<id>` and `<prefix>_pill_<id>`.
  final String keyPrefix;

  /// Marks each tappable part with a [LabelTap] instead of taking the tap
  /// itself, for a picture under a layer that takes every tap
  /// ([identificationLabelTap]).
  final bool tapsByMarker;

  @override
  Widget build(BuildContext context, WidgetRef ref) => Stack(
    children: [
      for (final label in labels)
        ..._parts(context, ref, label, byId[label.identificationId]!),
    ],
  );

  List<Widget> _parts(
    BuildContext context,
    WidgetRef ref,
    TrackLabel label,
    MediaIdentification found,
  ) {
    final l10n = context.l10n;
    final b = label.box;
    final onScreen = Rect.fromLTWH(
      picture.left + b.x * picture.width,
      picture.top + b.y * picture.height,
      b.width * picture.width,
      b.height * picture.height,
    );
    final at = TrackLabelGeometry.of(onScreen, picture, floor: floor);
    final dotTarget = touchTarget(at.dot);
    final session = holdIn;

    if (label.kind == TrackLabelKind.dot) {
      return [
        Positioned.fromRect(
          rect: dotTarget,
          child: _target(
            key: ValueKey('${keyPrefix}_dot_${label.identificationId}'),
            label: session != null
                ? l10n.media_species_unnamedFish
                : l10n.media_species_unnamedFishLocked,
            onTap: session == null
                ? null
                : () => pickOtherSpecies(
                    context,
                    ref,
                    item,
                    session,
                    onPicked: (picked) => ref
                        .read(mediaIdentificationServiceProvider)
                        .claim(item.id, found.id, picked.id),
                  ),
            child: const Center(child: TrackDot()),
          ),
        ),
      ];
    }

    final name = label.kind == TrackLabelKind.accepted
        ? _taggedName(context, label.speciesId, found)
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
          delegate: _PillLayout(centre: at.pillCentre, picture: picture),
          child: _target(
            key: ValueKey('${keyPrefix}_pill_${label.identificationId}'),
            label: name,
            onTap: session == null
                ? null
                : () => _openPill(context, label, found, session),
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
  /// what is under it.
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
    if (tapsByMarker) {
      return Semantics(
        key: key,
        button: true,
        label: label,
        onTap: onTap,
        child: MetaData(
          metaData: LabelTap(onTap),
          behavior: HitTestBehavior.opaque,
          child: child,
        ),
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
    TrackLabel label,
    MediaIdentification found,
    EditSession<PhotoRecord> session,
  ) {
    if (label.kind == TrackLabelKind.accepted) {
      final id = label.speciesId;
      if (id != null) context.push('/species/$id');
      return;
    }
    final top = found.top;
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
          cropIdentificationId: found.id,
          identificationIds: [found.id],
          alternatives: found.candidates.take(suggestionAlternatives).toList(),
        ),
        sitting: session,
        trackId: found.id,
      ),
    );
  }

  /// The tagged species' name as the app shows it; the app's own name for
  /// the animal when the species is not loaded yet.
  String _taggedName(
    BuildContext context,
    String? speciesId,
    MediaIdentification found,
  ) {
    final l10n = context.l10n;
    final tagged = speciesId == null ? null : species[speciesId];
    if (tagged != null) {
      return localizedSpeciesName(l10n, tagged.id, tagged.commonName);
    }
    final top = found.top;
    return top == null ? '' : candidateDisplayName(l10n, top.candidate);
  }
}

/// Puts a pill centred on [centre], moved in only as far as needed to stay
/// inside [picture], at most as wide as the picture.
class _PillLayout extends SingleChildLayoutDelegate {
  const _PillLayout({required this.centre, required this.picture});

  final Offset centre;
  final Rect picture;

  @override
  BoxConstraints getConstraintsForChild(BoxConstraints constraints) =>
      BoxConstraints.loose(Size(picture.width, constraints.maxHeight));

  @override
  Offset getPositionForChild(Size size, Size childSize) {
    final left = math.min(
      math.max(centre.dx - childSize.width / 2, picture.left),
      math.max(picture.left, picture.right - childSize.width),
    );
    return Offset(left, centre.dy - childSize.height / 2);
  }

  @override
  bool shouldRelayout(_PillLayout oldDelegate) =>
      centre != oldDelegate.centre || picture != oldDelegate.picture;
}
