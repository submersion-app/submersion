import 'package:submersion/core/tide/entities/tide_extremes.dart';
import 'package:submersion/features/tides/domain/entities/tide_record.dart';

/// A rising tide between a 08:20 low and a 14:20 high, recorded at noon.
///
/// Tide instants are stored wall-clock-as-UTC, so these are the site's clock
/// readings, not instants to convert.
final risingTideRecord = TideRecord(
  id: 'tide-1',
  diveId: 'dive-1',
  heightMeters: 1.6,
  tideState: TideState.rising,
  rateOfChange: 0.4,
  highTideHeight: 2.4,
  highTideTime: DateTime.utc(2026, 3, 28, 14, 20),
  lowTideHeight: 0.4,
  lowTideTime: DateTime.utc(2026, 3, 28, 8, 20),
  createdAt: DateTime.utc(2026, 3, 28, 12),
);
