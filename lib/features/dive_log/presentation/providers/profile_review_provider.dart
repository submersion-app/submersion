import 'package:submersion/core/providers/provider.dart';

/// Unified review position for the fullscreen profile view, as a timestamp
/// in dive-seconds. Written by chart scrubbing, the transport slider, and
/// the playback ticker; read by the chart cursor and the instrument tiles.
///
/// Keyed by dive ID. Null means no position is selected.
final profileReviewProvider = StateProvider.family<int?, String>(
  (ref, diveId) => null,
);
