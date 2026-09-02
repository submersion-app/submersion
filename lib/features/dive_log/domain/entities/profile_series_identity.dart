import 'package:uuid/uuid.dart';

/// Namespace for [profileSeriesMigratedId]. Fixed forever: changing it would
/// make two devices that migrate the same rows disagree on the series id.
const String kProfileSeriesNamespace = '7c2d9b1e-4f3a-4e8b-9c5d-2a1f6e8b3d47';

/// Namespace for [tankPressureSeriesMigratedId].
const String kTankPressureSeriesNamespace =
    'b8e1f2c3-5d6a-4b7c-8e9f-1a2b3c4d5e6f';

/// The series id the v182 migration assigns to a packed
/// (dive, computer, source, is_primary) group.
///
/// Every device runs the migration independently. A random id per device
/// would let sync union two primary series per dive, the duplicate
/// dive-types shape of issue #1360. Deriving the id from the identity tuple
/// makes devices that hold the same synced sample rows converge on upsert.
/// Only the migration uses this; repository writes mint uuid v4, because a
/// fresh download or edit genuinely is a new series.
///
/// Absent members are spelled `null` in the key (spec section 8). A member
/// that is literally the string "null" would collide with absence, and
/// cannot occur: every member is a uuid.
String profileSeriesMigratedId({
  required String diveId,
  required String? computerId,
  required String? sourceId,
  required bool isPrimary,
}) => const Uuid().v5(
  kProfileSeriesNamespace,
  '$diveId|${computerId ?? 'null'}|${sourceId ?? 'null'}|${isPrimary ? 1 : 0}',
);

/// The series id the v182 migration assigns to a packed
/// (dive, tank, computer) pressure group. See [profileSeriesMigratedId].
String tankPressureSeriesMigratedId({
  required String diveId,
  required String tankId,
  required String? computerId,
}) => const Uuid().v5(
  kTankPressureSeriesNamespace,
  '$diveId|$tankId|${computerId ?? 'null'}',
);
