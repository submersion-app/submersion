import 'package:flutter/material.dart';
import 'package:intl/intl.dart' show DateFormat;

import 'package:submersion/core/constants/enums.dart';
import 'package:submersion/core/utils/unit_formatter.dart';
import 'package:submersion/features/trips/domain/entities/trip.dart';
import 'package:submersion/l10n/arb/app_localizations.dart';
import 'package:submersion/shared/constants/entity_field.dart';

/// Enumeration of every displayable field for the trip table view.
enum TripField implements EntityField {
  tripName,
  startDate,
  endDate,
  durationDays,
  location,
  tripType,
  resortName,
  liveaboardName,
  diveCount,
  totalRuntime,
  maxDepth,
  avgDepth,
  notes;

  @override
  String get name => toString().split('.').last;

  @override
  String get displayName => switch (this) {
    TripField.tripName => 'Name',
    TripField.startDate => 'Start Date',
    TripField.endDate => 'End Date',
    TripField.durationDays => 'Duration',
    TripField.location => 'Location',
    TripField.tripType => 'Trip Type',
    TripField.resortName => 'Resort',
    TripField.liveaboardName => 'Liveaboard',
    TripField.diveCount => 'Dive Count',
    TripField.totalRuntime => 'Total Runtime',
    TripField.maxDepth => 'Max Depth',
    TripField.avgDepth => 'Avg Depth',
    TripField.notes => 'Notes',
  };

  @override
  String get shortLabel => switch (this) {
    TripField.tripName => 'Name',
    TripField.startDate => 'Start',
    TripField.endDate => 'End',
    TripField.durationDays => 'Days',
    TripField.location => 'Location',
    TripField.tripType => 'Type',
    TripField.resortName => 'Resort',
    TripField.liveaboardName => 'Liveaboard',
    TripField.diveCount => 'Dives',
    TripField.totalRuntime => 'RT Total',
    TripField.maxDepth => 'Max D',
    TripField.avgDepth => 'Avg D',
    TripField.notes => 'Notes',
  };

  @override
  String localizedDisplayName(AppLocalizations l10n) => switch (this) {
    TripField.tripName => l10n.enum_tripField_tripName,
    TripField.startDate => l10n.enum_tripField_startDate,
    TripField.endDate => l10n.enum_tripField_endDate,
    TripField.durationDays => l10n.enum_tripField_durationDays,
    TripField.location => l10n.enum_tripField_location,
    TripField.tripType => l10n.enum_tripField_tripType,
    TripField.resortName => l10n.enum_tripField_resortName,
    TripField.liveaboardName => l10n.enum_tripField_liveaboardName,
    TripField.diveCount => l10n.enum_tripField_diveCount,
    TripField.totalRuntime => l10n.enum_tripField_totalRuntime,
    TripField.maxDepth => l10n.enum_tripField_maxDepth,
    TripField.avgDepth => l10n.enum_tripField_avgDepth,
    TripField.notes => l10n.enum_tripField_notes,
  };

  @override
  String localizedShortLabel(AppLocalizations l10n) => switch (this) {
    TripField.tripName => l10n.enum_tripField_tripName_short,
    TripField.startDate => l10n.enum_tripField_startDate_short,
    TripField.endDate => l10n.enum_tripField_endDate_short,
    TripField.durationDays => l10n.enum_tripField_durationDays_short,
    TripField.location => l10n.enum_tripField_location_short,
    TripField.tripType => l10n.enum_tripField_tripType_short,
    TripField.resortName => l10n.enum_tripField_resortName_short,
    TripField.liveaboardName => l10n.enum_tripField_liveaboardName_short,
    TripField.diveCount => l10n.enum_tripField_diveCount_short,
    TripField.totalRuntime => l10n.enum_tripField_totalRuntime_short,
    TripField.maxDepth => l10n.enum_tripField_maxDepth_short,
    TripField.avgDepth => l10n.enum_tripField_avgDepth_short,
    TripField.notes => l10n.enum_tripField_notes_short,
  };

  @override
  IconData? get icon => switch (this) {
    TripField.tripName => Icons.flight,
    TripField.startDate => Icons.calendar_today,
    TripField.endDate => Icons.event,
    TripField.durationDays => Icons.timer,
    TripField.location => Icons.place,
    TripField.tripType => Icons.category,
    TripField.resortName => Icons.hotel,
    TripField.liveaboardName => Icons.directions_boat,
    TripField.diveCount => Icons.scuba_diving,
    TripField.totalRuntime => Icons.access_time,
    TripField.maxDepth => Icons.arrow_downward,
    TripField.avgDepth => Icons.trending_down,
    TripField.notes => Icons.notes,
  };

  @override
  double get defaultWidth => switch (this) {
    TripField.tripName => 150,
    TripField.startDate => 110,
    TripField.endDate => 110,
    TripField.durationDays => 80,
    TripField.location => 120,
    TripField.tripType => 90,
    TripField.resortName => 120,
    TripField.liveaboardName => 120,
    TripField.diveCount => 80,
    TripField.totalRuntime => 90,
    TripField.maxDepth => 80,
    TripField.avgDepth => 80,
    TripField.notes => 150,
  };

  @override
  double get minWidth => switch (this) {
    TripField.tripName => 80,
    TripField.startDate => 70,
    TripField.endDate => 70,
    TripField.durationDays => 50,
    TripField.location => 70,
    TripField.tripType => 60,
    TripField.resortName => 70,
    TripField.liveaboardName => 70,
    TripField.diveCount => 50,
    TripField.totalRuntime => 60,
    TripField.maxDepth => 50,
    TripField.avgDepth => 50,
    TripField.notes => 60,
  };

  @override
  bool get sortable => switch (this) {
    TripField.notes => false,
    _ => true,
  };

  @override
  String get categoryName => switch (this) {
    TripField.tripName => 'core',
    TripField.startDate => 'core',
    TripField.endDate => 'core',
    TripField.durationDays => 'core',
    TripField.location => 'core',
    TripField.tripType => 'core',
    TripField.resortName => 'accommodation',
    TripField.liveaboardName => 'accommodation',
    TripField.diveCount => 'statistics',
    TripField.totalRuntime => 'statistics',
    TripField.maxDepth => 'statistics',
    TripField.avgDepth => 'statistics',
    TripField.notes => 'other',
  };

  @override
  bool get isRightAligned => switch (this) {
    TripField.durationDays => true,
    TripField.diveCount => true,
    TripField.totalRuntime => true,
    TripField.maxDepth => true,
    TripField.avgDepth => true,
    _ => false,
  };
}

/// Adapter bridging [TripWithStats] entities with [TripField] for the generic
/// table infrastructure.
class TripFieldAdapter extends EntityFieldAdapter<TripWithStats, TripField> {
  static final TripFieldAdapter instance = TripFieldAdapter._();
  TripFieldAdapter._();

  static const List<TripField> _allFields = TripField.values;

  static final Map<String, List<TripField>> _fieldsByCategory = () {
    final map = <String, List<TripField>>{};
    for (final f in _allFields) {
      map.putIfAbsent(f.categoryName, () => []).add(f);
    }
    return map;
  }();

  static final DateFormat _dateFormat = DateFormat.yMMMd();

  @override
  List<TripField> get allFields => _allFields;

  @override
  Map<String, List<TripField>> get fieldsByCategory => _fieldsByCategory;

  @override
  dynamic extractValue(TripField field, TripWithStats entity) {
    return switch (field) {
      TripField.tripName => entity.trip.name,
      TripField.startDate => entity.trip.startDate,
      TripField.endDate => entity.trip.endDate,
      TripField.durationDays => entity.trip.durationDays,
      TripField.location => entity.trip.location,
      TripField.tripType => entity.trip.tripType,
      TripField.resortName => entity.trip.resortName,
      TripField.liveaboardName => entity.trip.liveaboardName,
      TripField.diveCount => entity.diveCount,
      TripField.totalRuntime => entity.totalRuntime,
      TripField.maxDepth => entity.maxDepth,
      TripField.avgDepth => entity.avgDepth,
      TripField.notes => entity.trip.notes,
    };
  }

  @override
  String formatValue(TripField field, dynamic value, UnitFormatter units) {
    if (value == null) return '--';
    return switch (field) {
      TripField.startDate => _dateFormat.format(value as DateTime),
      TripField.endDate => _dateFormat.format(value as DateTime),
      TripField.durationDays => '${value as int} days',
      TripField.tripType => (value as TripType).name,
      TripField.diveCount => (value as int).toString(),
      TripField.totalRuntime => _formatRuntime(value as int),
      TripField.maxDepth => units.formatDepth(value as double),
      TripField.avgDepth => units.formatDepth(value as double),
      _ => value is String ? (value.isEmpty ? '--' : value) : value.toString(),
    };
  }

  String _formatRuntime(int seconds) {
    if (seconds <= 0) return '--';
    final hours = seconds ~/ 3600;
    final mins = (seconds % 3600) ~/ 60;
    if (hours > 0) return '${hours}h ${mins}m';
    return '${mins}m';
  }

  /// Field names persisted by table layouts written before a rename, mapped to
  /// the field that replaced them.
  ///
  /// Saved layouts store [TripField.name] verbatim, and an unresolved name
  /// throws out of `EntityTableViewConfig.fromJson`, so dropping an old name
  /// would break the trips table for anyone who had customized it.
  static const Map<String, TripField> _legacyNames = {
    // Renamed when trip totals moved from bottom time to runtime (#889).
    'totalBottomTime': TripField.totalRuntime,
  };

  @override
  TripField fieldFromName(String name) {
    final legacy = _legacyNames[name];
    if (legacy != null) return legacy;
    return TripField.values.firstWhere((e) => e.name == name);
  }
}
