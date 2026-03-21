import 'package:submersion/features/dive_computer/domain/entities/downloaded_dive.dart';
import 'package:submersion/features/dive_log/domain/entities/dive.dart';
import 'package:submersion/features/dive_log/domain/entities/dive_computer.dart';

/// Normalized representation of an incoming dive from any import source.
///
/// Bridges [DownloadedDive] (dive computer download) and the
/// `Map<String, dynamic>` format (file import) so comparison logic
/// and the [DiveComparisonCard] can work with a single type.
class IncomingDiveData {
  final DateTime? startTime;
  final double? maxDepth;
  final double? avgDepth;
  final int? durationSeconds;
  final double? waterTemp;
  final String? computerName;
  final String? computerModel;
  final String? computerSerial;
  final List<DiveProfilePoint> profile;
  final String? siteName;

  const IncomingDiveData({
    this.startTime,
    this.maxDepth,
    this.avgDepth,
    this.durationSeconds,
    this.waterTemp,
    this.computerName,
    this.computerModel,
    this.computerSerial,
    this.profile = const [],
    this.siteName,
  });

  /// Create from a [DownloadedDive] (dive computer download flow).
  factory IncomingDiveData.fromDownloadedDive(
    DownloadedDive dive, {
    DiveComputer? computer,
  }) {
    return IncomingDiveData(
      startTime: dive.startTime,
      maxDepth: dive.maxDepth,
      avgDepth: dive.avgDepth,
      durationSeconds: dive.durationSeconds,
      waterTemp: dive.minTemperature,
      computerName: computer?.displayName,
      computerModel: computer?.fullName,
      computerSerial: computer?.serialNumber,
      profile: dive.profile
          .map(
            (s) => DiveProfilePoint(timestamp: s.timeSeconds, depth: s.depth),
          )
          .toList(),
    );
  }

  /// Create from an import map (file import flow).
  ///
  /// Prefers `runtime` over `duration` for the duration field.
  /// Computer fields use `diveComputerModel` / `diveComputerSerial` keys
  /// (only populated by UDDF parsers).
  factory IncomingDiveData.fromImportMap(Map<String, dynamic> data) {
    final runtime = data['runtime'] as Duration?;
    final duration = data['duration'] as Duration?;
    final effectiveDuration = runtime ?? duration;

    final profileMaps = data['profile'] as List?;
    final profile =
        profileMaps
            ?.map(
              (p) => DiveProfilePoint(
                timestamp: (p as Map)['timestamp'] as int,
                depth: (p['depth'] as num).toDouble(),
              ),
            )
            .toList() ??
        const [];

    return IncomingDiveData(
      startTime: data['dateTime'] as DateTime?,
      maxDepth: (data['maxDepth'] as num?)?.toDouble(),
      avgDepth: (data['avgDepth'] as num?)?.toDouble(),
      durationSeconds: effectiveDuration?.inSeconds,
      waterTemp: (data['waterTemp'] as num?)?.toDouble(),
      computerModel: data['diveComputerModel'] as String?,
      computerSerial: data['diveComputerSerial'] as String?,
      siteName: data['siteName'] as String?,
      profile: profile,
    );
  }
}
