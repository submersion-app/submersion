import 'package:flutter/foundation.dart';

/// One dive's factors for Dive focus, in storage units. Categorical values
/// are the stable keys the Insights distributions already emit, so the
/// existing label helpers can render them.
@immutable
class FocusFactorRow {
  const FocusFactorRow({
    required this.diveId,
    required this.dateTime,
    this.entryTime,
    this.maxDepth,
    this.avgDepth,
    this.durationMinutes,
    this.waterTemp,
    this.visibilityKey,
    this.currentStrength,
    this.waterType,
    this.entryMethod,
    this.siteId,
    this.siteName,
    this.diveTypes = const [],
    this.gasClass,
    this.firstTankVolume,
    this.weight,
    this.suitKey,
    this.buddyKey,
  });

  final String diveId;

  /// `dive_date_time`, a wall-clock value stored as UTC.
  final DateTime dateTime;

  /// `entry_time` when recorded; preferred for time of day.
  final DateTime? entryTime;
  final double? maxDepth;
  final double? avgDepth;

  /// Runtime, falling back to bottom time, in minutes.
  final double? durationMinutes;
  final double? waterTemp;

  /// A `VisibilityBand` name or `legacy_<Visibility>`, as
  /// `getVisibilityDistribution` emits.
  final String? visibilityKey;

  /// A `CurrentStrength` enum name.
  final String? currentStrength;

  /// A `WaterType` enum name, falling back to the site's.
  final String? waterType;

  /// An `EntryMethod` enum name, falling back to the site's.
  final String? entryMethod;
  final String? siteId;
  final String? siteName;

  /// Every dive type linked to the dive (ids or slugs); a dive can be
  /// several types at once.
  final List<String> diveTypes;

  /// `air`, `nitrox` or `trimix`; null with no tanks.
  final String? gasClass;

  /// Litres of water capacity of the first tank by tank order.
  final double? firstTankVolume;

  /// Lead in kilograms.
  final double? weight;

  /// `drysuit`, `wetsuit:<mm>` or `unknown`; null with no suit linked.
  final String? suitKey;

  /// `solo` or `buddy`; null when neither is recorded.
  final String? buddyKey;
}
