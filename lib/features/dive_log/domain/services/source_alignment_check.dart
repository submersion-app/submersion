import 'package:submersion/features/dive_log/domain/entities/dive.dart';
import 'package:submersion/features/dive_log/domain/services/dive_consolidation_builder.dart';
import 'package:submersion/features/dive_log/domain/services/profile_alignment.dart';

/// How one secondary computer of a consolidated dive sits on the primary's
/// timeline, and where its depth trace says it should sit.
class SourceAlignmentCheck {
  const SourceAlignmentCheck({
    required this.sourceId,
    required this.storedOffsetSeconds,
    required this.fit,
    this.primaryTrace = const [],
    this.sourceTrace = const [],
  });

  final String sourceId;

  /// The source's `time_offset_seconds`: how far its samples were moved to
  /// land on the primary's timeline.
  final int storedOffsetSeconds;

  /// The depth fit, from the source's own start, against the primary trace.
  final ProfileAlignmentResult fit;

  /// The primary's depth trace, on the dive's timeline.
  final List<DiveProfilePoint> primaryTrace;

  /// This source's depth trace from its own start, before any offset.
  final List<DiveProfilePoint> sourceTrace;

  /// Whether the fit is trustworthy and disagrees with the stored offset by
  /// more than computers on different arms do: the clock the offset came
  /// from had drifted (#2894).
  bool get isMisaligned =>
      fit.isStrongMatch &&
      (fit.offsetSeconds - storedOffsetSeconds).abs() >
          DiveConsolidationBuilder.clockToleranceSeconds;
}
