import 'package:flutter/material.dart';

import 'package:submersion/core/constants/enums.dart';
import 'package:submersion/core/utils/unit_formatter.dart';
import 'package:submersion/features/buddies/domain/entities/buddy.dart';
import 'package:submersion/shared/constants/entity_field.dart';

/// Wrapper carrying a [Buddy] with its computed dive count.
typedef BuddyWithCount = ({Buddy buddy, int diveCount});

/// Enumeration of every displayable field for the buddy table view.
enum BuddyField implements EntityField {
  buddyName,
  email,
  phone,
  certificationLevel,
  certificationAgency,
  diveCount,
  notes;

  @override
  String get name => toString().split('.').last;

  @override
  String get displayName => switch (this) {
    BuddyField.buddyName => 'Name',
    BuddyField.email => 'Email',
    BuddyField.phone => 'Phone',
    BuddyField.certificationLevel => 'Certification Level',
    BuddyField.certificationAgency => 'Certification Agency',
    BuddyField.diveCount => 'Dive Count',
    BuddyField.notes => 'Notes',
  };

  @override
  String get shortLabel => switch (this) {
    BuddyField.buddyName => 'Name',
    BuddyField.email => 'Email',
    BuddyField.phone => 'Phone',
    BuddyField.certificationLevel => 'Cert Level',
    BuddyField.certificationAgency => 'Agency',
    BuddyField.diveCount => 'Dives',
    BuddyField.notes => 'Notes',
  };

  @override
  IconData? get icon => switch (this) {
    BuddyField.buddyName => Icons.person,
    BuddyField.email => Icons.email,
    BuddyField.phone => Icons.phone,
    BuddyField.certificationLevel => Icons.card_membership,
    BuddyField.certificationAgency => Icons.business,
    BuddyField.diveCount => Icons.scuba_diving,
    BuddyField.notes => Icons.notes,
  };

  @override
  double get defaultWidth => switch (this) {
    BuddyField.buddyName => 150,
    BuddyField.email => 180,
    BuddyField.phone => 120,
    BuddyField.certificationLevel => 130,
    BuddyField.certificationAgency => 110,
    BuddyField.diveCount => 80,
    BuddyField.notes => 150,
  };

  @override
  double get minWidth => switch (this) {
    BuddyField.buddyName => 80,
    BuddyField.email => 80,
    BuddyField.phone => 70,
    BuddyField.certificationLevel => 70,
    BuddyField.certificationAgency => 70,
    BuddyField.diveCount => 50,
    BuddyField.notes => 60,
  };

  @override
  bool get sortable => switch (this) {
    BuddyField.notes => false,
    _ => true,
  };

  @override
  String get categoryName => switch (this) {
    BuddyField.buddyName => 'core',
    BuddyField.diveCount => 'core',
    BuddyField.email => 'contact',
    BuddyField.phone => 'contact',
    BuddyField.certificationLevel => 'certification',
    BuddyField.certificationAgency => 'certification',
    BuddyField.notes => 'other',
  };

  @override
  bool get isRightAligned => switch (this) {
    BuddyField.diveCount => true,
    _ => false,
  };
}

/// Adapter bridging [BuddyWithCount] records with [BuddyField] for the
/// generic table infrastructure.
class BuddyFieldAdapter extends EntityFieldAdapter<BuddyWithCount, BuddyField> {
  static final BuddyFieldAdapter instance = BuddyFieldAdapter._();
  BuddyFieldAdapter._();

  static const List<BuddyField> _allFields = BuddyField.values;

  static final Map<String, List<BuddyField>> _fieldsByCategory = () {
    final map = <String, List<BuddyField>>{};
    for (final f in _allFields) {
      map.putIfAbsent(f.categoryName, () => []).add(f);
    }
    return map;
  }();

  @override
  List<BuddyField> get allFields => _allFields;

  @override
  Map<String, List<BuddyField>> get fieldsByCategory => _fieldsByCategory;

  @override
  dynamic extractValue(BuddyField field, BuddyWithCount entity) {
    return switch (field) {
      BuddyField.buddyName => entity.buddy.name,
      BuddyField.email => entity.buddy.email,
      BuddyField.phone => entity.buddy.phone,
      BuddyField.certificationLevel => entity.buddy.certificationLevel,
      BuddyField.certificationAgency => entity.buddy.certificationAgency,
      BuddyField.diveCount => entity.diveCount,
      BuddyField.notes => entity.buddy.notes,
    };
  }

  @override
  String formatValue(BuddyField field, dynamic value, UnitFormatter units) {
    if (value == null) return '--';
    return switch (field) {
      BuddyField.certificationLevel => (value as CertificationLevel).name,
      BuddyField.certificationAgency => (value as CertificationAgency).name,
      BuddyField.diveCount => (value as int).toString(),
      _ => value is String ? (value.isEmpty ? '--' : value) : value.toString(),
    };
  }

  @override
  BuddyField fieldFromName(String name) {
    return BuddyField.values.firstWhere((e) => e.name == name);
  }
}
