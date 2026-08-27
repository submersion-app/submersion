import 'package:submersion/features/tides/domain/entities/tide_record.dart';

const _heightToleranceMeters = 0.05;
const _extremeTimeTolerance = Duration(minutes: 10);

/// Whether a stored tide record disagrees with a freshly computed one
/// enough to overwrite it. Records written before the 2026 harmonic
/// engine fixes are wrong by hours; records written after match within
/// these thresholds and are left alone (guaranteeing convergence).
bool tideRecordNeedsHeal({
  required TideRecord stored,
  required TideRecord fresh,
}) {
  if ((stored.heightMeters - fresh.heightMeters).abs() >
      _heightToleranceMeters) {
    return true;
  }
  if (stored.tideState != fresh.tideState) return true;
  if (_timesDiffer(stored.highTideTime, fresh.highTideTime)) return true;
  if (_timesDiffer(stored.lowTideTime, fresh.lowTideTime)) return true;
  return false;
}

bool _timesDiffer(DateTime? a, DateTime? b) {
  if (a == null || b == null) return (a == null) != (b == null);
  return a.difference(b).abs() > _extremeTimeTolerance;
}
