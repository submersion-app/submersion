import 'package:submersion/core/tide/tide_calculator.dart';
import 'package:submersion/features/dive_sites/domain/entities/dive_site.dart';
import 'package:submersion/features/tides/data/repositories/tide_record_repository.dart';
import 'package:submersion/features/tides/domain/entities/tide_record.dart';
import 'package:submersion/features/tides/domain/services/tide_status_for_dive.dart';

/// Records the tide for a dive being saved. [entryWallClock] is the dive's
/// stored wall clock (wall-clock-as-UTC); the tide is evaluated at the real
/// instant at [location], and the record stores real instants.
Future<TideRecord> recordDiveTide({
  required TideRecordRepository repository,
  required TideCalculator calculator,
  required String diveId,
  required DateTime entryWallClock,
  required GeoPoint location,
}) async {
  final status = await tideStatusForDive(
    calculator: calculator,
    entryWallClock: entryWallClock,
    location: location,
  );
  return repository.createFromStatus(diveId: diveId, status: status);
}
