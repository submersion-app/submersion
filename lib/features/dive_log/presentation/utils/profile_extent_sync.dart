import 'package:flutter/widgets.dart';

import 'package:submersion/core/providers/provider.dart';
import 'package:submersion/features/dive_log/domain/entities/dive.dart';
import 'package:submersion/features/dive_log/presentation/providers/profile_playback_provider.dart';
import 'package:submersion/features/dive_log/presentation/providers/profile_range_provider.dart';

/// Keep the playback and range extents on the series the chart draws.
///
/// Called from the build of every surface that draws a dive's profile with
/// playback or range handles: the chart host (detail page and dashboard
/// preview) and the fullscreen page (#1577). Today every route into
/// fullscreen leaves a host mounted underneath, but the page keeps its own
/// extents rather than depend on whichever screen opened it. All of these
/// surfaces read the dive through diveProvider and draw the same series, so
/// whichever runs second finds nothing to do.
///
/// Deliberately not a one-shot "initialize if still zero": the data sources
/// load asynchronously, so the first build falls back to dive.profile and a
/// zero-guard would freeze the merged series' extent in place forever. The
/// active source can also change at any time. Both cases leave the range
/// slider running past the end of the visible curve (#1167).
/// Re-initializing resets playback position and range selection, which is
/// the wanted behavior when the series underneath them changed.
///
/// The comparison runs in build, so a frame callback is only scheduled on
/// the rare build that has work to do.
///
/// Both extents are read, not watched: watching playback would resubscribe
/// the caller to the 25ms ticker that #2231 removed. Reading is enough,
/// because the only thing that can invalidate an extent is the drawn series
/// changing, and the caller already rebuilds for that. The one other caller
/// of [PlaybackNotifier.initialize], `ProfileTransportControls.initState`,
/// derives its value from the same dive's drawn series, so it can only ever
/// agree.
void keepProfileExtentsOnDrawnSeries(
  BuildContext context,
  WidgetRef ref, {
  required String diveId,
  required List<DiveProfilePoint> chartProfile,
}) {
  if (chartProfile.isEmpty) return;
  final maxTimestamp = chartProfile.last.timestamp;
  if (ref.read(playbackProvider(diveId)).maxTimestamp == maxTimestamp &&
      ref.read(rangeSelectionProvider(diveId)).maxTimestamp == maxTimestamp) {
    return;
  }
  WidgetsBinding.instance.addPostFrameCallback((_) {
    // riverpod's own liveness check: a ConsumerWidget's ref throws a
    // StateError, in release as well as debug, once its element is gone.
    // Scheduled from build, this callback drains at the end of that same
    // frame and so has never yet outlived the widget (probed against a
    // LayoutBuilder that drops the chart on resize: still mounted). The
    // guard is here so that stays a scheduling detail rather than a
    // precondition, for whoever next moves the call off the build path.
    if (!context.mounted) return;
    // Re-read rather than trusting the build-time snapshot: the rest of the
    // frame may have moved either extent already.
    if (ref.read(playbackProvider(diveId)).maxTimestamp != maxTimestamp) {
      ref.read(playbackProvider(diveId).notifier).initialize(maxTimestamp);
    }
    if (ref.read(rangeSelectionProvider(diveId)).maxTimestamp != maxTimestamp) {
      ref
          .read(rangeSelectionProvider(diveId).notifier)
          .initialize(maxTimestamp);
    }
  });
}
