import 'package:flutter/material.dart';

import 'package:submersion/core/utils/unit_formatter.dart';
import 'package:submersion/features/dive_centers/domain/entities/dive_center.dart';
import 'package:submersion/shared/constants/entity_field.dart';

/// Record type used as the adapter entity: pairs a [DiveCenter] with its
/// associated dive count.
typedef DiveCenterRow = ({DiveCenter center, int diveCount});

/// Enumeration of every displayable field for the dive center table view.
enum DiveCenterField implements EntityField {
  centerName,
  city,
  country,
  stateProvince,
  street,
  postalCode,
  phone,
  email,
  website,
  affiliations,
  rating,
  latitude,
  longitude,
  diveCount,
  notes;

  @override
  String get name => toString().split('.').last;

  @override
  String get displayName => switch (this) {
    DiveCenterField.centerName => 'Name',
    DiveCenterField.city => 'City',
    DiveCenterField.country => 'Country',
    DiveCenterField.stateProvince => 'State / Province',
    DiveCenterField.street => 'Street',
    DiveCenterField.postalCode => 'Postal Code',
    DiveCenterField.phone => 'Phone',
    DiveCenterField.email => 'Email',
    DiveCenterField.website => 'Website',
    DiveCenterField.affiliations => 'Affiliations',
    DiveCenterField.rating => 'Rating',
    DiveCenterField.latitude => 'Latitude',
    DiveCenterField.longitude => 'Longitude',
    DiveCenterField.diveCount => 'Dive Count',
    DiveCenterField.notes => 'Notes',
  };

  @override
  String get shortLabel => switch (this) {
    DiveCenterField.centerName => 'Name',
    DiveCenterField.city => 'City',
    DiveCenterField.country => 'Country',
    DiveCenterField.stateProvince => 'State',
    DiveCenterField.street => 'Street',
    DiveCenterField.postalCode => 'ZIP',
    DiveCenterField.phone => 'Phone',
    DiveCenterField.email => 'Email',
    DiveCenterField.website => 'Website',
    DiveCenterField.affiliations => 'Affiliations',
    DiveCenterField.rating => 'Rating',
    DiveCenterField.latitude => 'Lat',
    DiveCenterField.longitude => 'Lon',
    DiveCenterField.diveCount => 'Dives',
    DiveCenterField.notes => 'Notes',
  };

  @override
  IconData? get icon => switch (this) {
    DiveCenterField.centerName => Icons.store,
    DiveCenterField.city => Icons.location_city,
    DiveCenterField.country => Icons.flag,
    DiveCenterField.stateProvince => Icons.map,
    DiveCenterField.street => Icons.signpost,
    DiveCenterField.postalCode => Icons.local_post_office,
    DiveCenterField.phone => Icons.phone,
    DiveCenterField.email => Icons.email,
    DiveCenterField.website => Icons.language,
    DiveCenterField.affiliations => Icons.badge,
    DiveCenterField.rating => Icons.star,
    DiveCenterField.latitude => Icons.explore,
    DiveCenterField.longitude => Icons.explore,
    DiveCenterField.diveCount => Icons.scuba_diving,
    DiveCenterField.notes => Icons.notes,
  };

  @override
  double get defaultWidth => switch (this) {
    DiveCenterField.centerName => 150,
    DiveCenterField.city => 100,
    DiveCenterField.country => 100,
    DiveCenterField.stateProvince => 100,
    DiveCenterField.street => 130,
    DiveCenterField.postalCode => 90,
    DiveCenterField.phone => 110,
    DiveCenterField.email => 150,
    DiveCenterField.website => 150,
    DiveCenterField.affiliations => 120,
    DiveCenterField.rating => 70,
    DiveCenterField.latitude => 90,
    DiveCenterField.longitude => 90,
    DiveCenterField.diveCount => 80,
    DiveCenterField.notes => 150,
  };

  @override
  double get minWidth => switch (this) {
    DiveCenterField.centerName => 80,
    DiveCenterField.city => 60,
    DiveCenterField.country => 60,
    DiveCenterField.stateProvince => 60,
    DiveCenterField.street => 80,
    DiveCenterField.postalCode => 60,
    DiveCenterField.phone => 70,
    DiveCenterField.email => 80,
    DiveCenterField.website => 80,
    DiveCenterField.affiliations => 60,
    DiveCenterField.rating => 50,
    DiveCenterField.latitude => 60,
    DiveCenterField.longitude => 60,
    DiveCenterField.diveCount => 50,
    DiveCenterField.notes => 60,
  };

  @override
  bool get sortable => switch (this) {
    DiveCenterField.centerName => true,
    DiveCenterField.city => true,
    DiveCenterField.country => true,
    DiveCenterField.stateProvince => true,
    DiveCenterField.street => true,
    DiveCenterField.postalCode => true,
    DiveCenterField.phone => false,
    DiveCenterField.email => false,
    DiveCenterField.website => false,
    DiveCenterField.affiliations => false,
    DiveCenterField.rating => true,
    DiveCenterField.latitude => true,
    DiveCenterField.longitude => true,
    DiveCenterField.diveCount => true,
    DiveCenterField.notes => false,
  };

  @override
  String get categoryName => switch (this) {
    DiveCenterField.centerName => 'core',
    DiveCenterField.city => 'core',
    DiveCenterField.country => 'core',
    DiveCenterField.diveCount => 'core',
    DiveCenterField.street => 'address',
    DiveCenterField.stateProvince => 'address',
    DiveCenterField.postalCode => 'address',
    DiveCenterField.phone => 'contact',
    DiveCenterField.email => 'contact',
    DiveCenterField.website => 'contact',
    DiveCenterField.affiliations => 'details',
    DiveCenterField.rating => 'details',
    DiveCenterField.notes => 'details',
    DiveCenterField.latitude => 'coordinates',
    DiveCenterField.longitude => 'coordinates',
  };

  @override
  bool get isRightAligned => switch (this) {
    DiveCenterField.rating => true,
    DiveCenterField.latitude => true,
    DiveCenterField.longitude => true,
    DiveCenterField.diveCount => true,
    _ => false,
  };
}

/// Adapter bridging [DiveCenterRow] records with [DiveCenterField] for the
/// generic table infrastructure.
class DiveCenterFieldAdapter
    extends EntityFieldAdapter<DiveCenterRow, DiveCenterField> {
  static final DiveCenterFieldAdapter instance = DiveCenterFieldAdapter._();
  DiveCenterFieldAdapter._();

  static const List<DiveCenterField> _allFields = DiveCenterField.values;

  static final Map<String, List<DiveCenterField>> _fieldsByCategory = () {
    final map = <String, List<DiveCenterField>>{};
    for (final f in _allFields) {
      map.putIfAbsent(f.categoryName, () => []).add(f);
    }
    return map;
  }();

  @override
  List<DiveCenterField> get allFields => _allFields;

  @override
  Map<String, List<DiveCenterField>> get fieldsByCategory => _fieldsByCategory;

  @override
  dynamic extractValue(DiveCenterField field, DiveCenterRow entity) {
    final center = entity.center;
    return switch (field) {
      DiveCenterField.centerName => center.name,
      DiveCenterField.city => center.city,
      DiveCenterField.country => center.country,
      DiveCenterField.stateProvince => center.stateProvince,
      DiveCenterField.street => center.street,
      DiveCenterField.postalCode => center.postalCode,
      DiveCenterField.phone => center.phone,
      DiveCenterField.email => center.email,
      DiveCenterField.website => center.website,
      DiveCenterField.affiliations => center.affiliations,
      DiveCenterField.rating => center.rating,
      DiveCenterField.latitude => center.latitude,
      DiveCenterField.longitude => center.longitude,
      DiveCenterField.diveCount => entity.diveCount,
      DiveCenterField.notes => center.notes,
    };
  }

  @override
  String formatValue(
    DiveCenterField field,
    dynamic value,
    UnitFormatter units,
  ) {
    if (value == null) return '--';
    return switch (field) {
      DiveCenterField.affiliations =>
        (value as List<String>).isEmpty ? '--' : value.join(', '),
      DiveCenterField.rating => (value as double).toStringAsFixed(1),
      DiveCenterField.latitude => (value as double).toStringAsFixed(5),
      DiveCenterField.longitude => (value as double).toStringAsFixed(5),
      DiveCenterField.diveCount => value.toString(),
      _ => value is String ? (value.isEmpty ? '--' : value) : value.toString(),
    };
  }

  @override
  DiveCenterField fieldFromName(String name) {
    return DiveCenterField.values.firstWhere((e) => e.name == name);
  }
}
