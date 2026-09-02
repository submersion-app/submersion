import 'package:flutter/material.dart';

import 'package:submersion/core/constants/enums.dart';
import 'package:submersion/core/utils/unit_formatter.dart';
import 'package:submersion/features/buddies/domain/entities/buddy_with_dive_count.dart';
import 'package:submersion/l10n/arb/app_localizations.dart';
import 'package:submersion/shared/constants/entity_field.dart';

/// Entity handed to [BuddyFieldAdapter]. An alias of the repository's class so
/// the table view and the list cards share one type with no conversion.
typedef BuddyWithCount = BuddyWithDiveCount;

/// Enumeration of every displayable field for the buddy table view.
enum BuddyField implements EntityField {
  buddyName,
  email,
  phone,
  certificationLevel,
  certificationAgency,
  diveCount,
  notes,
  lastDive;

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
    BuddyField.lastDive => 'Last Dive',
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
    BuddyField.lastDive => 'Last dive',
  };

  @override
  String localizedDisplayName(AppLocalizations l10n) => switch (this) {
    BuddyField.buddyName => l10n.enum_buddyField_buddyName,
    BuddyField.email => l10n.enum_buddyField_email,
    BuddyField.phone => l10n.enum_buddyField_phone,
    BuddyField.certificationLevel => l10n.enum_buddyField_certificationLevel,
    BuddyField.certificationAgency => l10n.enum_buddyField_certificationAgency,
    BuddyField.diveCount => l10n.enum_buddyField_diveCount,
    BuddyField.notes => l10n.enum_buddyField_notes,
    BuddyField.lastDive => l10n.enum_buddyField_lastDive,
  };

  @override
  String localizedShortLabel(AppLocalizations l10n) => switch (this) {
    BuddyField.buddyName => l10n.enum_buddyField_buddyName_short,
    BuddyField.email => l10n.enum_buddyField_email_short,
    BuddyField.phone => l10n.enum_buddyField_phone_short,
    BuddyField.certificationLevel =>
      l10n.enum_buddyField_certificationLevel_short,
    BuddyField.certificationAgency =>
      l10n.enum_buddyField_certificationAgency_short,
    BuddyField.diveCount => l10n.enum_buddyField_diveCount_short,
    BuddyField.notes => l10n.enum_buddyField_notes_short,
    BuddyField.lastDive => l10n.enum_buddyField_lastDive_short,
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
    BuddyField.lastDive => Icons.history,
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
    BuddyField.lastDive => 110,
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
    BuddyField.lastDive => 70,
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
    BuddyField.lastDive => 'statistics',
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
      BuddyField.lastDive => entity.lastDiveAt,
    };
  }

  @override
  String formatValue(BuddyField field, dynamic value, UnitFormatter units) {
    if (value == null) return kFieldValuePlaceholder;
    return switch (field) {
      BuddyField.certificationLevel =>
        (value as CertificationLevel).displayName,
      BuddyField.certificationAgency =>
        (value as CertificationAgency).displayName,
      BuddyField.diveCount => (value as int).toString(),
      BuddyField.lastDive => units.formatDate(value as DateTime),
      _ =>
        value is String
            ? (value.isEmpty ? kFieldValuePlaceholder : value)
            : value.toString(),
    };
  }

  @override
  BuddyField fieldFromName(String name) {
    return BuddyField.values.firstWhere((e) => e.name == name);
  }
}
