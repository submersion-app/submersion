import 'package:flutter/material.dart';

import 'package:submersion/core/providers/provider.dart';
import 'package:submersion/features/dive_log/presentation/providers/dive_providers.dart';
import 'package:submersion/features/nav_track/domain/entities/nav_track.dart';
import 'package:submersion/features/nav_track/domain/nav_track_matcher.dart';
import 'package:submersion/features/nav_track/presentation/widgets/nav_track_dive_choice_sheet.dart';

/// Asks which dive [route] belongs to, offering the dives nearest its
/// recording and the one it is linked to now ([linkedId]), and answers the
/// dive chosen, or null when the diver chose nothing new.
///
/// "Change dive" (#4023) always shows the dive it is changing from, even
/// one that dropped out of the nearest list once closer dives were logged.
/// The sheet starts on the linked dive, or else the sole dive overlapping
/// the recording in time (#2394), so confirming it is a single tap.
Future<String?> chooseNavTrackDive(
  BuildContext context,
  WidgetRef ref,
  NavTrack route, {
  required String? linkedId,
}) async {
  final dives = await ref.read(divesProvider.future);
  final nearest = NavTrackMatcher.nearestByStart(
    routeStartSeconds: route.startTime ~/ 1000,
    dives: dives,
  );
  final linkedOutsideNearest =
      linkedId == null || nearest.any((dive) => dive.id == linkedId)
      ? null
      : dives.where((dive) => dive.id == linkedId).firstOrNull;
  final selectedDiveId =
      linkedId ??
      NavTrackMatcher.soleCandidateFor(
        routeStartSeconds: route.startTime ~/ 1000,
        routeEndSeconds: route.endTime ~/ 1000,
        dives: dives,
      )?.id;
  if (!context.mounted) return null;
  final chosen = await showNavTrackDiveChoiceSheet(
    context,
    dives: [?linkedOutsideNearest, ...nearest],
    selectedDiveId: selectedDiveId,
  );
  if (chosen == null || chosen.id == linkedId) return null;
  return chosen.id;
}
