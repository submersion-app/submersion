import 'package:uuid/uuid.dart';

import 'package:submersion/features/dive_log/domain/entities/dive.dart';
import 'package:submersion/features/wearables/domain/entities/wearable_dive.dart';

/// Converts a [WearableDive] into a [Dive] entity for database storage.
///
/// Pure, stateless converter. The [Uuid] is injectable for testing.
class WearableDiveConverter {
  const WearableDiveConverter({Uuid uuid = const Uuid()}) : _uuid = uuid;

  final Uuid _uuid;

  /// Convert a [WearableDive] into a [Dive] ready for database insertion.
  ///
  /// The resulting [Dive] will have:
  /// - A new UUID as its [Dive.id]
  /// - [WearableDive.startTime] mapped to both [Dive.dateTime] and [Dive.entryTime]
  /// - [WearableDive.endTime] mapped to [Dive.exitTime]
  /// - Profile samples converted to [DiveProfilePoint] list
  /// - [wearableSource] and [wearableId] set for dedup tracking
  Dive convert(WearableDive wearableDive, {String? diverId, int? diveNumber}) {
    final profile = _convertProfile(wearableDive);
    final sourceName = _sourceToString(wearableDive.source);

    return Dive(
      id: _uuid.v4(),
      diverId: diverId,
      diveNumber: diveNumber,
      dateTime: wearableDive.startTime,
      entryTime: wearableDive.startTime,
      exitTime: wearableDive.endTime,
      duration: wearableDive.duration,
      maxDepth: wearableDive.maxDepth,
      avgDepth: wearableDive.avgDepth,
      waterTemp: wearableDive.minTemperature,
      profile: profile,
      wearableSource: sourceName,
      wearableId: wearableDive.sourceId,
    );
  }

  List<DiveProfilePoint> _convertProfile(WearableDive wearableDive) {
    final sourceName = _sourceToString(wearableDive.source);

    return wearableDive.profile.map((sample) {
      return DiveProfilePoint(
        timestamp: sample.timeSeconds,
        depth: sample.depth,
        temperature: sample.temperature,
        heartRate: sample.heartRate,
        heartRateSource: sample.heartRate != null ? sourceName : null,
      );
    }).toList();
  }

  String _sourceToString(WearableSource source) {
    return switch (source) {
      WearableSource.appleWatch => 'appleWatch',
      WearableSource.garmin => 'garmin',
      WearableSource.suunto => 'suunto',
    };
  }
}
