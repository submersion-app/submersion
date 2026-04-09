import 'package:submersion/core/providers/provider.dart';

/// Currently tracked profile point index, shared across all profile charts
/// for the same dive. Written by whichever chart the user is interacting
/// with; read by all charts to show a synchronized highlight cursor.
///
/// Keyed by dive ID so that each dive has independent tracking state.
final profileTrackingIndexProvider = StateProvider.family<int?, String>(
  (ref, diveId) => null,
);
