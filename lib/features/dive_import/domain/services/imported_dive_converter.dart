import 'package:uuid/uuid.dart';

import 'package:submersion/features/dive_log/domain/entities/dive.dart';
import 'package:submersion/features/dive_import/domain/entities/imported_dive.dart';

/// Converts an [ImportedDive] into a [Dive] entity for database storage.
///
/// Pure, stateless converter. The [Uuid] is injectable for testing.
class ImportedDiveConverter {
  const ImportedDiveConverter({Uuid uuid = const Uuid()}) : _uuid = uuid;

  final Uuid _uuid;

  /// Convert an [ImportedDive] into a [Dive] ready for database insertion.
  ///
  /// The resulting [Dive] will have:
  /// - A new UUID as its [Dive.id]
  /// - [ImportedDive.startTime] mapped to both [Dive.dateTime] and [Dive.entryTime]
  /// - [ImportedDive.endTime] mapped to [Dive.exitTime]
  /// - Profile samples converted to [DiveProfilePoint] list
  /// - [importSource] and [importId] set for dedup tracking
  Dive convert(ImportedDive importedDive, {String? diverId, int? diveNumber}) {
    final profile = _convertProfile(importedDive);
    final sourceName = _sourceToString(importedDive.source);

    // importedDive.duration is endTime - startTime (total runtime),
    // not bottom time. Store it as runtime and auto-calculate bottom time.
    final dive = Dive(
      id: _uuid.v4(),
      diverId: diverId,
      diveNumber: diveNumber,
      dateTime: importedDive.startTime,
      entryTime: importedDive.startTime,
      exitTime: importedDive.endTime,
      runtime: importedDive.duration,
      maxDepth: importedDive.maxDepth,
      avgDepth: importedDive.avgDepth,
      waterTemp: importedDive.minTemperature,
      profile: profile,
      importSource: sourceName,
      importId: importedDive.sourceId,
    );

    // Calculate bottom time from profile if available
    if (profile.isNotEmpty) {
      final bottomTime = dive.calculateBottomTimeFromProfile();
      if (bottomTime != null) {
        return dive.copyWith(bottomTime: bottomTime);
      }
    }

    return dive;
  }

  List<DiveProfilePoint> _convertProfile(ImportedDive importedDive) {
    final sourceName = _sourceToString(importedDive.source);

    return importedDive.profile.map((sample) {
      return DiveProfilePoint(
        timestamp: sample.timeSeconds,
        depth: sample.depth,
        temperature: sample.temperature,
        heartRate: sample.heartRate,
        heartRateSource: sample.heartRate != null ? sourceName : null,
      );
    }).toList();
  }

  String _sourceToString(ImportSource source) {
    return switch (source) {
      ImportSource.appleWatch => 'appleWatch',
      ImportSource.garmin => 'garmin',
      ImportSource.suunto => 'suunto',
      ImportSource.uddf => 'uddf',
    };
  }
}
