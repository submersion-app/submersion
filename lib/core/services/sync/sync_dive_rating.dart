import 'package:submersion/core/utils/dive_rating_scale.dart';

/// Issue #4415. A peer below v358, or a sync store written before it, can
/// hold a dive rated on a UDDF file's 1 to 10 scale, or 0 for an unrated
/// dive. Every inbound dive row (payload, base file, adoption, conflict) is
/// put on the 1 to 5 star scale once, as the v358 rung put this device's own
/// rows, and so is the remote side of a stored conflict before it is shown.
/// The sync stamp does not move: the sending peer makes the same change when
/// it upgrades.
///
/// Returns [data] itself when it is not a dive or its rating is already on
/// the scale.
Map<String, dynamic> withDiveRatingInScale(
  String entityType,
  Map<String, dynamic> data,
) {
  if (entityType != 'dives') return data;
  final rating = data['rating'];
  final stars = DiveRatingScale.normalizeStored(rating);
  return identical(stars, rating) ? data : {...data, 'rating': stars};
}
