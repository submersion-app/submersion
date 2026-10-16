import 'package:flutter/material.dart';

import 'package:submersion/features/certification_agencies/domain/certification_catalog.dart';
import 'package:submersion/features/certifications/presentation/certification_title_l10n.dart';
import 'package:submersion/features/documents/data/repositories/document_repository.dart';
import 'package:submersion/features/documents/domain/entities/document.dart';
import 'package:submersion/l10n/arb/app_localizations.dart';

String documentTypeLabel(AppLocalizations l10n, DocumentType type) =>
    switch (type) {
      DocumentType.insurance => l10n.documents_type_insurance,
      DocumentType.medicalClearance => l10n.documents_type_medicalClearance,
      DocumentType.certificationCard => l10n.documents_type_certificationCard,
      DocumentType.permit => l10n.documents_type_permit,
      DocumentType.booking => l10n.documents_type_booking,
      DocumentType.receipt => l10n.documents_type_receipt,
      DocumentType.manual => l10n.documents_type_manual,
      DocumentType.map => l10n.documents_type_map,
      DocumentType.other => l10n.documents_type_other,
    };

IconData documentTypeIcon(DocumentType type) => switch (type) {
  DocumentType.insurance => Icons.health_and_safety_outlined,
  DocumentType.medicalClearance => Icons.medical_information_outlined,
  DocumentType.certificationCard => Icons.card_membership_outlined,
  DocumentType.permit => Icons.verified_outlined,
  DocumentType.booking => Icons.confirmation_number_outlined,
  DocumentType.receipt => Icons.receipt_long_outlined,
  DocumentType.manual => Icons.menu_book_outlined,
  DocumentType.map => Icons.map_outlined,
  DocumentType.other => Icons.description_outlined,
};

String documentOwnerKindLabel(AppLocalizations l10n, DocumentOwnerKind kind) =>
    switch (kind) {
      DocumentOwnerKind.personal => l10n.documents_owner_personal,
      DocumentOwnerKind.dive => l10n.documents_owner_dive,
      DocumentOwnerKind.site => l10n.documents_owner_site,
      DocumentOwnerKind.trip => l10n.documents_owner_trip,
      DocumentOwnerKind.equipment => l10n.documents_owner_equipment,
      DocumentOwnerKind.course => l10n.documents_owner_course,
      DocumentOwnerKind.certification => l10n.documents_owner_certification,
      DocumentOwnerKind.buddy => l10n.documents_owner_buddy,
      DocumentOwnerKind.diveCenter => l10n.documents_owner_diveCenter,
    };

IconData documentOwnerKindIcon(DocumentOwnerKind kind) => switch (kind) {
  DocumentOwnerKind.personal => Icons.person_outline,
  DocumentOwnerKind.dive => Icons.scuba_diving,
  DocumentOwnerKind.site => Icons.place_outlined,
  DocumentOwnerKind.trip => Icons.luggage_outlined,
  DocumentOwnerKind.equipment => Icons.backpack_outlined,
  DocumentOwnerKind.course => Icons.school_outlined,
  DocumentOwnerKind.certification => Icons.card_membership_outlined,
  DocumentOwnerKind.buddy => Icons.people_outline,
  DocumentOwnerKind.diveCenter => Icons.storefront_outlined,
};

/// The document's own title, or its type's name when it has none, so a
/// default title follows the app language. A certification card is titled
/// by its certification ([ownerLabel], the certification's name), so a
/// rename shows everywhere without a second write.
String documentDisplayTitle(
  AppLocalizations l10n,
  Document document, {
  String? ownerLabel,
}) {
  final label = ownerLabel?.trim() ?? '';
  if (document.type == DocumentType.certificationCard && label.isNotEmpty) {
    return label;
  }
  final title = document.title.trim();
  return title.isEmpty ? documentTypeLabel(l10n, document.type) : title;
}

/// [entry] with a certification owner titled the way the Certifications
/// screens title it: its custom name, else its certification. The stored
/// name alone is empty for a certification with no custom title (#3366).
DocumentListEntry withCertificationOwnerTitle(
  DocumentListEntry entry,
  AppLocalizations l10n, {
  CertificationCatalog? catalog,
}) => switch (entry.certification) {
  final fields? => entry.withOwnerLabel(
    certificationTitleFieldsL10n(fields, l10n, catalog: catalog),
  ),
  null => entry,
};
