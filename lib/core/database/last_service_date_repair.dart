import 'package:drift/drift.dart';

/// Moves `equipment.last_service_date` forward to the item's newest service
/// record where it is older than that record or unset (v346, #4201), and
/// returns how many items it rewrote.
///
/// Logging a service record wrote that record's date as the item's last
/// service date until v346, so back-filling an older record moved the date
/// back. A date later than every record stays: an import can set one with no
/// record behind it, and that is not this bug's doing.
///
/// Cheap enough to run again after every inbound sync apply, which is how a
/// row from a peer below v346, or from a sync store still holding one, gets
/// the same repair. The sync stamp (`updated_at`, `hlc`) does not move: every
/// device runs this same rewrite over the same records, so they agree
/// without a sync round.
///
/// Raw SQL, as the other ladder helpers, so it keeps compiling against any
/// later shape of the generated classes.
Future<int> repairLastServiceDates(DatabaseConnectionUser db) =>
    db.customUpdate('''
      UPDATE equipment
      SET last_service_date = (
        SELECT MAX(r.service_date) FROM service_records r
        WHERE r.equipment_id = equipment.id
      )
      WHERE EXISTS (
        SELECT 1 FROM service_records r
        WHERE r.equipment_id = equipment.id
          AND (equipment.last_service_date IS NULL
            OR r.service_date > equipment.last_service_date)
      )
    ''');
