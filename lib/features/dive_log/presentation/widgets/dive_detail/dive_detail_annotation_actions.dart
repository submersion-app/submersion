import 'package:flutter/material.dart';

import 'package:submersion/core/providers/provider.dart';
import 'package:submersion/core/utils/minutes_seconds.dart';
import 'package:submersion/core/utils/unit_formatter.dart';
import 'package:submersion/features/dive_log/data/repositories/annotation_repository.dart';
import 'package:submersion/features/dive_log/domain/entities/dive.dart';
import 'package:submersion/features/dive_log/domain/entities/profile_event.dart';
import 'package:submersion/features/dive_log/domain/services/annotation_links.dart';
import 'package:submersion/features/dive_log/presentation/providers/annotation_placement_provider.dart';
import 'package:submersion/features/dive_log/presentation/providers/annotation_providers.dart';
import 'package:submersion/features/dive_log/presentation/widgets/annotation_marker_popup.dart';
import 'package:submersion/features/dive_log/presentation/widgets/edit_sections/annotation_time_sheet.dart';
import 'package:submersion/l10n/l10n_extension.dart';

/// What the dive detail page (and the fullscreen profile) do with the
/// chart's annotation callbacks (#4109): placement, the marker popup, Move,
/// Remove, the typed time and the right-click menu. Chart-side writes go
/// through the repository at once; the page refreshes from its dive watch.
class DiveDetailAnnotationActions {
  const DiveDetailAnnotationActions({
    required this.ref,
    required this.context,
    required this.dive,
    this.onOpenInNotes,
  });

  final WidgetRef ref;
  final BuildContext context;
  final Dive dive;

  /// Read when a sheet or popup opens, never watched: the section that
  /// builds this must not rebuild its chart on an unrelated settings write.
  UnitFormatter get units => ref.read(unitFormatterProvider);

  /// Scrolls the page to the Notes card and highlights the passage. Null
  /// where no Notes card is at hand, which leaves the action out of the popup.
  final ValueChanged<String>? onOpenInNotes;

  String get diveId => dive.id;

  AnnotationPlacementNotifier get _placement =>
      ref.read(annotationPlacementProvider(diveId).notifier);

  AnnotationRepository get _repository =>
      ref.read(annotationRepositoryProvider);

  /// The latest second an annotation may fall on: the profile's last sample,
  /// else the runtime, else a day (see [annotationTimeCap]).
  int get maxSeconds {
    final profile = dive.profile;
    if (profile.isNotEmpty) return profile.last.timestamp;
    return annotationTimeCap(dive.effectiveRuntime?.inSeconds);
  }

  /// The pin button: enters (or leaves) placement mode; a dive with no
  /// profile to point at goes straight to the sheet, by typed time.
  Future<void> onPinPressed() async {
    if (dive.profile.isEmpty) {
      _placement.cancel();
      await addAt(0, null);
      return;
    }
    _placement.toggleNew();
  }

  /// A placement on the chart: moves the annotation being moved, or opens
  /// the sheet for a new one. Placement mode ends either way.
  Future<void> place(int seconds, double? depthMeters) async {
    final moving = ref.read(annotationPlacementProvider(diveId))?.movingId;
    if (moving != null) {
      await _repository.moveAnnotation(
        id: moving,
        timestamp: seconds,
        depth: depthMeters,
      );
      if (context.mounted) _placement.cancel();
      return;
    }
    await addAt(seconds, depthMeters);
  }

  /// Opens the sheet prefilled with [seconds] and writes the annotation on
  /// Add; Cancel adds nothing. Leaves placement mode either way. The widget
  /// behind [ref] can be rebuilt away while the sheet is open, and the words
  /// still count, so the repository is read first. Placement is read after:
  /// it disposes itself when nothing watches it, which also ends the mode.
  Future<void> addAt(int seconds, double? depthMeters) async {
    final repository = _repository;
    final result = await showAnnotationTimeSheet(
      context,
      words: null,
      profile: dive.profile,
      maxSeconds: maxSeconds,
      initialSeconds: seconds,
      initialDepthMeters: depthMeters,
      units: units,
    );
    if (context.mounted) _placement.cancel();
    if (result == null) return;
    await repository.addAnnotation(
      diveId: diveId,
      timestamp: result.seconds,
      depth: result.depthMeters,
      words: result.words,
    );
  }

  /// A tap on an annotation's dot: the popup, anchored to it.
  Future<void> onMarkerTap(ProfileEvent annotation, Offset globalCenter) {
    final openInNotes = onOpenInNotes;
    return showAnnotationMarkerPopup(
      context,
      annotation: annotation,
      globalPosition: globalCenter,
      units: units,
      onOpenInNotes: openInNotes == null
          ? null
          : () => openInNotes(annotation.id),
      onMove: () => _placement.startMove(annotation.id),
      onEditTime: () => editTime(annotation),
      onRemove: () => _remove(annotation),
    );
  }

  /// The time sheet for an existing annotation; the marker follows on Save.
  Future<void> editTime(ProfileEvent annotation) async {
    final repository = _repository;
    final result = await showAnnotationTimeSheet(
      context,
      words: annotation.description ?? '',
      profile: dive.profile,
      maxSeconds: maxSeconds,
      initialSeconds: annotation.timestamp,
      initialDepthMeters: annotation.depth,
      editing: true,
      units: units,
    );
    if (result == null) return;
    await repository.moveAnnotation(
      id: annotation.id,
      timestamp: result.seconds,
      depth: result.depthMeters,
    );
  }

  Future<void> _remove(ProfileEvent annotation) async {
    await _repository.removeAnnotation(diveId: diveId, id: annotation.id);
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
