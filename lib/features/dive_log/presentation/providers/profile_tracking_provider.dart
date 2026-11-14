import 'package:submersion/core/providers/provider.dart';
import 'package:submersion/features/dive_log/domain/entities/dive.dart';
import 'package:submersion/features/dive_log/domain/services/profile_position.dart';

/// Currently tracked profile point index, shared across all profile charts
/// for the same dive. Written by whichever chart the user is interacting
/// with; read by all charts to show a synchronized highlight cursor.
///
/// Keyed by dive ID so that each dive has independent tracking state.
final profileTrackingIndexProvider = StateProvider.family<int?, String>(
  (ref, diveId) => null,
);

/// Moves [diveId]'s shared profile cursor to the sample of [chartProfile]
/// at [seconds], or clears it for null. [chartProfile] is the series the
/// profile chart draws (#543), which the cursor indexes. Writes only on a
/// change, so a pointer moving within one sample wakes no listener.
void setProfileCursorSeconds(
  WidgetRef ref,
  String diveId,
  List<DiveProfilePoint> chartProfile,
  int? seconds,
) => setProfileCursorSecondsIn(ref.container, diveId, chartProfile, seconds);

/// [setProfileCursorSeconds] for a caller that holds the [ProviderContainer]
/// rather than a widget's ref, because it can run after that widget is gone.
void setProfileCursorSecondsIn(
  ProviderContainer container,
  String diveId,
  List<DiveProfilePoint> chartProfile,
  int? seconds,
) {
  final notifier = container.read(
    profileTrackingIndexProvider(diveId).notifier,
  );
  final index = seconds == null
      ? null
      : indexForTimestamp(chartProfile, seconds);
  if (notifier.state != index) notifier.state = index;
}
