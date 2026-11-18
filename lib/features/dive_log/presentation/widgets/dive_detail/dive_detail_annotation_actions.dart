import 'package:flutter/material.dart';

import 'package:submersion/core/constants/dive_detail_sections.dart';
import 'package:submersion/core/providers/provider.dart';
import 'package:submersion/core/utils/minutes_seconds.dart';
import 'package:submersion/core/utils/unit_formatter.dart';
import 'package:submersion/features/dive_log/domain/entities/dive.dart';
import 'package:submersion/features/dive_log/domain/entities/profile_event.dart';
import 'package:submersion/features/dive_log/domain/services/annotation_links.dart';
import 'package:submersion/features/dive_log/presentation/providers/annotation_focus_provider.dart';
import 'package:submersion/features/dive_log/presentation/providers/annotation_placement_provider.dart';
import 'package:submersion/features/dive_log/presentation/providers/profile_legend_provider.dart';
import 'package:submersion/features/dive_log/presentation/widgets/annotation_marker_popup.dart';
import 'package:submersion/features/dive_log/presentation/widgets/dive_detail/annotation_edits.dart';
import 'package:submersion/features/dive_log/presentation/widgets/edit_sections/annotation_time_sheet.dart';
import 'package:submersion/features/settings/presentation/providers/settings_providers.dart';
import 'package:submersion/l10n/l10n_extension.dart';

/// What the dive detail page (and the fullscreen profile) do with the
/// chart's annotation callbacks (#4109): placement, the marker popup, Move,
/// Remove, the typed time and the right-click menu. Chart-side writes go
/// through [edits], into a sitting on the dive held until Save; without
/// one, or [readOnly], nowhere (issue #4527).
class DiveDetailAnnotationActions {
  const DiveDetailAnnotationActions({
    required this.ref,
    required this.context,
    required this.dive,
    this.onOpenInNotes,
    this.shownProfile = const [],
    this.edits,
    bool readOnly = false,
  }) : readOnly = readOnly || edits == null;

  /// Where the writes go: the open Profile card's sitting. Null writes
  /// nothing, as on a locked dive.
  final AnnotationEdits? edits;

  /// Writes nothing: no pin, no placement, no right-click menu, and a
  /// popup that only opens the Notes. A locked dive, a closed Profile card
  /// during a sitting, or a sitting that does not hold the annotations yet.
  /// Always so without [edits].
  final bool readOnly;

  final WidgetRef ref;
  final BuildContext context;
  final Dive dive;

  /// Read when a sheet or popup opens, never watched: the section that
  /// builds this must not rebuild its chart on an unrelated settings write.
  UnitFormatter get units => ref.read(unitFormatterProvider);

  /// Scrolls the page to the Notes card and highlights the passage. Null
  /// where no Notes card is at hand, which leaves the action out of the popup.
  final ValueChanged<String>? onOpenInNotes;

  /// The profile the chart is drawing, which is another computer's when one
  /// is selected. Empty leaves the dive's own.
  final List<DiveProfilePoint> shownProfile;

  /// These actions for the profile a chart is drawing.
  DiveDetailAnnotationActions onProfile(List<DiveProfilePoint> profile) =>
      DiveDetailAnnotationActions(
        ref: ref,
        context: context,
        dive: dive,
        onOpenInNotes: onOpenInNotes,
        shownProfile: profile,
        edits: edits,
        readOnly: readOnly,
      );

  String get diveId => dive.id;

  List<DiveProfilePoint> get _profile =>
      shownProfile.isNotEmpty ? shownProfile : dive.profile;

  AnnotationPlacementNotifier get _placement =>
      ref.read(annotationPlacementProvider(diveId).notifier);

  /// Where a write goes, read when the action starts. Asked only once
  /// [readOnly] is false, which it never is without [edits].
  AnnotationEdits get _edits => edits!;

  /// The latest second an annotation may fall on: the profile's last sample,
  /// else the runtime, else a day (see [annotationTimeCap]).
  int get maxSeconds {
    final profile = _profile;
    final fallback = profile.isNotEmpty
        ? profile.last.timestamp
        : annotationTimeCap(dive.effectiveRuntime?.inSeconds);
    return edits?.maxSeconds(fallback) ?? fallback;
  }

  /// The pin button: enters (or leaves) placement mode; a dive with no
  /// profile to point at goes straight to the sheet, by typed time.
  Future<void> onPinPressed() async {
    if (readOnly) return;
    if (_profile.isEmpty) {
      _placement.cancel();
      await addAt(0, null);
      return;
    }
    _placement.toggleNew();
  }

  /// A placement on the chart: moves the annotation being moved, or opens
  /// the sheet for a new one. Placement mode ends either way.
  Future<void> place(int seconds, double? depthMeters) async {
    if (readOnly) return;
    final moving = ref.read(annotationPlacementProvider(diveId))?.movingId;
    if (moving != null) {
      await _edits.move(moving, seconds: seconds, depth: depthMeters);
      if (context.mounted) _placement.cancel();
      return;
    }
    await addAt(seconds, depthMeters);
  }

  /// Opens the sheet prefilled with [seconds] and writes the annotation on
  /// Add; Cancel adds nothing. Leaves placement mode either way, and turns
  /// the legend's Annotations toggle on, so the new marker appears. The
  /// widget behind [ref] can be rebuilt away while the sheet is open, and the
  /// words still count, so the repository is read first. Placement is read
  /// after: it disposes itself when nothing watches it, which also ends the
  /// mode.
  Future<void> addAt(int seconds, double? depthMeters) async {
    if (readOnly) return;
    final edits = _edits;
    final result = await showAnnotationTimeSheet(
      context,
      words: null,
      profile: _profile,
      maxSeconds: maxSeconds,
      initialSeconds: seconds,
      initialDepthMeters: depthMeters,
      units: units,
    );
    if (context.mounted) {
      _placement.cancel();
      if (result != null && !ref.read(profileLegendProvider).showAnnotations) {
        ref.read(profileLegendProvider.notifier).toggleAnnotations();
      }
    }
    if (result == null) return;
    await edits.add(
      seconds: result.seconds,
      depth: result.depthMeters,
      words: result.words,
    );
  }

  /// A tap on an annotation's dot, or a focus request served: the popup,
  /// anchored to it. Open in Notes needs a Notes card to go to, which the
  /// diver can have switched off.
  Future<void> onMarkerTap(ProfileEvent annotation, Offset globalCenter) {
    final focus = ref.read(annotationFocusProvider(diveId).notifier);
    if (focus.state != null) focus.state = null;
    final notesShown = ref
        .read(settingsProvider)
        .diveDetailSections
        .shows(DiveDetailSectionId.notes, gauge: dive.isGauge);
    final openInNotes = notesShown ? onOpenInNotes : null;
    return showAnnotationMarkerPopup(
      context,
      annotation: annotation,
      globalPosition: globalCenter,
      units: units,
      onOpenInNotes: openInNotes == null
          ? null
          : () => openInNotes(annotation.id),
      onMove: readOnly ? null : () => _placement.startMove(annotation.id),
      onEditTime: readOnly ? null : () => editTime(annotation),
      onRemove: readOnly ? null : () => _remove(annotation),
    );
  }

  /// The time sheet for an existing annotation; the marker follows on Save.
  Future<void> editTime(ProfileEvent annotation) async {
    if (readOnly) return;
    final edits = _edits;
    final result = await showAnnotationTimeSheet(
      context,
      words: annotation.description ?? '',
      profile: _profile,
      maxSeconds: maxSeconds,
      initialSeconds: annotation.timestamp,
      initialDepthMeters: annotation.depth,
      editing: true,
      units: units,
    );
    if (result == null) return;
    await edits.move(
      annotation.id,
      seconds: result.seconds,
      depth: result.depthMeters,
    );
  }

  Future<void> _remove(ProfileEvent annotation) async {
    await _edits.remove(annotation.id);
    if (!context.mounted) return;
    ScaffoldMessenger.maybeOf(context)?.showSnackBar(
      SnackBar(content: Text(context.l10n.diveLog_annotation_removed)),
    );
  }

  /// A right-click on the plot: one menu item that opens the sheet for that
  /// second, skipping the pin button.
  Future<void> onSecondaryTap(
    int seconds,
    double? depthMeters,
    Offset globalPosition,
  ) async {
    if (readOnly) return;
    final choice = await showMenu<bool>(
      context: context,
      position: annotationMenuPosition(context, globalPosition),
      items: [
        PopupMenuItem<bool>(
          value: true,
          child: Text(
            context.l10n.diveLog_annotation_contextMenu_annotateAt(
              formatMinutesSeconds(seconds),
            ),
          ),
        ),
      ],
    );
    if (choice != true || !context.mounted) return;
    await addAt(seconds, depthMeters);
  }
}
