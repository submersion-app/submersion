import 'package:submersion/features/dive_log/domain/entities/dive.dart';

/// One data source's profile samples for a dive, keyed by the
/// dive_data_sources row that owns them.
class SourceProfile {
  const SourceProfile({
    required this.sourceId,
    required this.computerId,
    required this.isEdited,
    required this.points,
  });

  final String sourceId;
  final String? computerId;

  /// True when these are user-edited rows replacing the primary source's
  /// original samples.
  final bool isEdited;
  final List<DiveProfilePoint> points;
}
