import 'package:equatable/equatable.dart';

import 'package:submersion/features/dive_log/domain/entities/dive.dart';

/// Assumed duration when a dive has neither runtime nor bottom time.
const Duration _fallbackDuration = Duration(minutes: 45);

/// Minimum visual width so very short dives stay tappable/visible.
const double _minWidthFraction = 0.02;

/// One dive rendered as a block on a 24h day axis.
class RhythmBlock extends Equatable {
  final double startFraction;
  final double widthFraction;
  final bool isNight;

  const RhythmBlock({
    required this.startFraction,
    required this.widthFraction,
    required this.isNight,
  });

  @override
  List<Object?> get props => [startFraction, widthFraction, isNight];
}

/// Lay out one day's dives on a 24h axis as fractions of the day.
///
/// Position is derived from each dive's wall-clock time of day (hour/minute/
/// second), not `difference()` from midnight: the latter measures elapsed
/// physical time and would shift by an hour across a DST boundary. Dive times
/// are wall-clock-as-UTC in this codebase, so the components are the truth.
/// This is why the day's date isn't needed — dives are already grouped into
/// their calendar day upstream, and only the time-of-day matters here.
List<RhythmBlock> computeRhythmBlocks(List<Dive> dives) {
  const daySeconds = 24 * 3600;

  return dives.map((dive) {
    final entry = dive.entryTime ?? dive.dateTime;
    final duration = dive.runtime ?? dive.bottomTime ?? _fallbackDuration;

    final startSeconds = entry.hour * 3600 + entry.minute * 60 + entry.second;
    var start = (startSeconds / daySeconds).clamp(0.0, 1.0);
    var width = (duration.inSeconds / daySeconds).clamp(_minWidthFraction, 1.0);
    if (start + width > 1.0) {
      width = 1.0 - start;
      if (width < _minWidthFraction) {
        start = 1.0 - _minWidthFraction;
        width = _minWidthFraction;
      }
    }

    final hour = entry.hour;
    return RhythmBlock(
      startFraction: start,
      widthFraction: width,
      isNight: hour >= 18 || hour < 6,
    );
  }).toList();
}
