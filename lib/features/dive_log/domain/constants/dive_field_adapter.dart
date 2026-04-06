import 'package:flutter/material.dart';

import 'package:submersion/core/constants/dive_field.dart';
import 'package:submersion/core/utils/unit_formatter.dart';
import 'package:submersion/features/dive_log/domain/entities/dive.dart';
import 'package:submersion/shared/constants/entity_field.dart';

/// Wraps a [DiveField] enum value as an [EntityField] for use with the generic
/// table infrastructure.
///
/// This avoids modifying the [DiveField] enum itself (which has extension
/// methods that can't satisfy an interface directly in Dart).
class DiveEntityField implements EntityField {
  final DiveField field;

  const DiveEntityField(this.field);

  @override
  String get name => field.name;
  @override
  String get displayName => field.displayName;
  @override
  String get shortLabel => field.shortLabel;
  @override
  IconData? get icon => field.icon;
  @override
  double get defaultWidth => field.defaultWidth;
  @override
  double get minWidth => field.minWidth;
  @override
  bool get sortable => field.sortable;
  @override
  String get categoryName => field.category.name;

  @override
  bool get isRightAligned {
    switch (field) {
      case DiveField.diveNumber:
      case DiveField.maxDepth:
      case DiveField.avgDepth:
      case DiveField.bottomTime:
      case DiveField.runtime:
      case DiveField.waterTemp:
      case DiveField.airTemp:
      case DiveField.swellHeight:
      case DiveField.altitude:
      case DiveField.surfacePressure:
      case DiveField.windSpeed:
      case DiveField.humidity:
      case DiveField.tankCount:
      case DiveField.startPressure:
      case DiveField.endPressure:
      case DiveField.sacRate:
      case DiveField.gasConsumed:
      case DiveField.totalWeight:
      case DiveField.gradientFactorLow:
      case DiveField.gradientFactorHigh:
      case DiveField.cnsStart:
      case DiveField.cnsEnd:
      case DiveField.otu:
      case DiveField.setpointLow:
      case DiveField.setpointHigh:
      case DiveField.setpointDeco:
      case DiveField.ratingStars:
      case DiveField.surfaceInterval:
      case DiveField.siteLatitude:
      case DiveField.siteLongitude:
        return true;
      default:
        return false;
    }
  }

  @override
  bool operator ==(Object other) =>
      other is DiveEntityField && other.field == field;

  @override
  int get hashCode => field.hashCode;
}

/// Adapter bridging [Dive] entities with [DiveEntityField] for the generic
/// table infrastructure.
class DiveFieldAdapter extends EntityFieldAdapter<Dive, DiveEntityField> {
  static final DiveFieldAdapter instance = DiveFieldAdapter._();
  DiveFieldAdapter._();

  static final List<DiveEntityField> _allFields = DiveField.values
      .map((f) => DiveEntityField(f))
      .toList();

  static final Map<String, List<DiveEntityField>> _fieldsByCategory = () {
    final map = <String, List<DiveEntityField>>{};
    for (final f in _allFields) {
      map.putIfAbsent(f.categoryName, () => []).add(f);
    }
    return map;
  }();

  @override
  List<DiveEntityField> get allFields => _allFields;

  @override
  Map<String, List<DiveEntityField>> get fieldsByCategory => _fieldsByCategory;

  @override
  dynamic extractValue(DiveEntityField field, Dive entity) {
    return field.field.extractFromDive(entity);
  }

  @override
  String formatValue(
    DiveEntityField field,
    dynamic value,
    UnitFormatter units,
  ) {
    return field.field.formatValue(value, units);
  }

  @override
  DiveEntityField fieldFromName(String name) {
    return DiveEntityField(DiveField.values.firstWhere((e) => e.name == name));
  }
}
