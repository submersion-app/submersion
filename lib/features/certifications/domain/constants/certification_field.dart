import 'package:flutter/material.dart';
import 'package:intl/intl.dart' show DateFormat;

import 'package:submersion/core/constants/enums.dart';
import 'package:submersion/core/utils/unit_formatter.dart';
import 'package:submersion/features/certifications/domain/entities/certification.dart';
import 'package:submersion/l10n/arb/app_localizations.dart';
import 'package:submersion/shared/constants/entity_field.dart';
import 'package:submersion/features/certifications/domain/certification_title.dart';

/// Enumeration of every displayable field for the certification table view.
enum CertificationField implements EntityField {
  certName,
  agency,
  level,
  cardNumber,
  issueDate,
  expiryDate,
  instructorName,
  instructorNumber,
  expiryStatus,
  notes;

  @override
  String get name => toString().split('.').last;

  @override
  String get displayName => switch (this) {
    CertificationField.certName => 'Name',
    CertificationField.agency => 'Agency',
    CertificationField.level => 'Certification',
    CertificationField.cardNumber => 'Card Number',
    CertificationField.issueDate => 'Issue Date',
    CertificationField.expiryDate => 'Expiry Date',
    CertificationField.instructorName => 'Instructor Name',
    CertificationField.instructorNumber => 'Instructor Number',
    CertificationField.expiryStatus => 'Expiry Status',
    CertificationField.notes => 'Notes',
  };

  @override
  String get shortLabel => switch (this) {
    CertificationField.certName => 'Name',
    CertificationField.agency => 'Agency',
    CertificationField.level => 'Certification',
    CertificationField.cardNumber => 'Card #',
    CertificationField.issueDate => 'Issued',
    CertificationField.expiryDate => 'Expires',
    CertificationField.instructorName => 'Instructor',
    CertificationField.instructorNumber => 'Instr. #',
    CertificationField.expiryStatus => 'Status',
    CertificationField.notes => 'Notes',
  };

  @override
  String localizedDisplayName(AppLocalizations l10n) => switch (this) {
    CertificationField.certName => l10n.enum_certificationField_certName,
    CertificationField.agency => l10n.enum_certificationField_agency,
    CertificationField.level => l10n.enum_certificationField_level,
    CertificationField.cardNumber => l10n.enum_certificationField_cardNumber,
    CertificationField.issueDate => l10n.enum_certificationField_issueDate,
    CertificationField.expiryDate => l10n.enum_certificationField_expiryDate,
    CertificationField.instructorName =>
      l10n.enum_certificationField_instructorName,
    CertificationField.instructorNumber =>
      l10n.enum_certificationField_instructorNumber,
    CertificationField.expiryStatus =>
      l10n.enum_certificationField_expiryStatus,
    CertificationField.notes => l10n.enum_certificationField_notes,
  };

  @override
  String localizedShortLabel(AppLocalizations l10n) => switch (this) {
    CertificationField.certName => l10n.enum_certificationField_certName_short,
    CertificationField.agency => l10n.enum_certificationField_agency_short,
    CertificationField.level => l10n.enum_certificationField_level_short,
    CertificationField.cardNumber =>
      l10n.enum_certificationField_cardNumber_short,
    CertificationField.issueDate =>
      l10n.enum_certificationField_issueDate_short,
    CertificationField.expiryDate =>
      l10n.enum_certificationField_expiryDate_short,
    CertificationField.instructorName =>
      l10n.enum_certificationField_instructorName_short,
    CertificationField.instructorNumber =>
      l10n.enum_certificationField_instructorNumber_short,
    CertificationField.expiryStatus =>
      l10n.enum_certificationField_expiryStatus_short,
    CertificationField.notes => l10n.enum_certificationField_notes_short,
  };

  @override
  IconData? get icon => switch (this) {
    CertificationField.certName => Icons.card_membership,
    CertificationField.agency => Icons.business,
    CertificationField.level => Icons.workspace_premium,
    CertificationField.cardNumber => Icons.tag,
    CertificationField.issueDate => Icons.calendar_today,
    CertificationField.expiryDate => Icons.event,
    CertificationField.instructorName => Icons.person,
    CertificationField.instructorNumber => Icons.badge,
    CertificationField.expiryStatus => Icons.info_outline,
    CertificationField.notes => Icons.notes,
  };

  @override
  double get defaultWidth => switch (this) {
    CertificationField.certName => 150,
    CertificationField.agency => 100,
    CertificationField.level => 120,
    CertificationField.cardNumber => 110,
    CertificationField.issueDate => 100,
    CertificationField.expiryDate => 100,
    CertificationField.instructorName => 120,
    CertificationField.instructorNumber => 110,
    CertificationField.expiryStatus => 100,
    CertificationField.notes => 150,
  };

  @override
  double get minWidth => switch (this) {
    CertificationField.certName => 80,
    CertificationField.agency => 60,
    CertificationField.level => 70,
    CertificationField.cardNumber => 70,
    CertificationField.issueDate => 70,
    CertificationField.expiryDate => 70,
    CertificationField.instructorName => 80,
    CertificationField.instructorNumber => 70,
    CertificationField.expiryStatus => 70,
    CertificationField.notes => 60,
  };

  @override
  bool get sortable => switch (this) {
    CertificationField.certName => true,
    CertificationField.agency => true,
    CertificationField.level => true,
    CertificationField.cardNumber => true,
    CertificationField.issueDate => true,
    CertificationField.expiryDate => true,
    CertificationField.instructorName => true,
    CertificationField.instructorNumber => false,
    CertificationField.expiryStatus => false,
    CertificationField.notes => false,
  };

  @override
  String get categoryName => switch (this) {
    CertificationField.certName => 'core',
    CertificationField.agency => 'core',
    CertificationField.level => 'core',
    CertificationField.cardNumber => 'core',
    CertificationField.issueDate => 'dates',
    CertificationField.expiryDate => 'dates',
    CertificationField.expiryStatus => 'dates',
    CertificationField.instructorName => 'instructor',
    CertificationField.instructorNumber => 'instructor',
    CertificationField.notes => 'other',
  };

  @override
  bool get isRightAligned => false;
}

/// Adapter bridging [Certification] entities with [CertificationField] for the
/// generic table infrastructure.
class CertificationFieldAdapter
    extends EntityFieldAdapter<Certification, CertificationField> {
  static final CertificationFieldAdapter instance =
      CertificationFieldAdapter._();
  CertificationFieldAdapter._();

  static const List<CertificationField> _allFields = CertificationField.values;

  static final Map<String, List<CertificationField>> _fieldsByCategory = () {
    final map = <String, List<CertificationField>>{};
    for (final f in _allFields) {
      map.putIfAbsent(f.categoryName, () => []).add(f);
    }
    return map;
  }();

  static final DateFormat _dateFormat = DateFormat.yMMMd();

  @override
  List<CertificationField> get allFields => _allFields;

  @override
  Map<String, List<CertificationField>> get fieldsByCategory =>
      _fieldsByCategory;

  @override
  dynamic extractValue(CertificationField field, Certification entity) {
    return switch (field) {
      // Not entity.name: that is empty for certs without a custom name, and
      // for legacy rows it repeats the Agency and Certification columns.
      CertificationField.certName => certificationTitle(entity),
      CertificationField.agency => entity.agency,
      CertificationField.level => entity.level,
      CertificationField.cardNumber => entity.cardNumber,
      CertificationField.issueDate => entity.issueDate,
      CertificationField.expiryDate => entity.expiryDate,
      CertificationField.instructorName => entity.instructorName,
      CertificationField.instructorNumber => entity.instructorNumber,
      CertificationField.expiryStatus => entity.expiryStatus,
      CertificationField.notes => entity.notes,
    };
  }

  @override
  String formatValue(
    CertificationField field,
    dynamic value,
    UnitFormatter units,
  ) {
    if (value == null) return '--';
    return switch (field) {
      CertificationField.agency => (value as CertificationAgency).name,
      // displayName, not name: the latter is the enum identifier, so the
      // column read "openWater" rather than "Open Water".
      CertificationField.level => (value as CertificationLevel).displayName,
      CertificationField.issueDate => _dateFormat.format(value as DateTime),
      CertificationField.expiryDate => _dateFormat.format(value as DateTime),
      _ => value is String ? (value.isEmpty ? '--' : value) : value.toString(),
    };
  }

  @override
  CertificationField fieldFromName(String name) {
    return CertificationField.values.firstWhere((e) => e.name == name);
  }
}
