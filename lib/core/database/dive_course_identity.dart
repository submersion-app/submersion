import 'package:uuid/uuid.dart';

/// The id of the `dive_courses` row linking [diveId] to [courseId] (#2515).
///
/// Deterministic, so the same link made on two devices, or seeded by the v288
/// migration on two devices, is one row under sync upsert rather than two.
/// The name string is frozen: changing it would fork every link in a synced
/// fleet.
String diveCourseLinkId(String diveId, String courseId) => const Uuid().v5(
  Namespace.url.value,
  'submersion:dive-course:$diveId:$courseId',
);
