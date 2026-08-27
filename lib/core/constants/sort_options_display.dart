import 'package:submersion/core/constants/sort_options.dart';
import 'package:submersion/l10n/arb/app_localizations.dart';

/// Localized display names for the sort enums declared in `sort_options.dart`.
///
/// The `displayName` field on each enum stays English on purpose: it is a
/// stable, locale-independent value used by stored sort preferences and
/// diagnostics. These getters drive on-screen UI (the sort bottom sheet and its
/// direction toggle) so the same values honor the active locale.
///
/// Each switch is exhaustive by enum value, so adding a new value is a compile
/// error until its localization key is wired in.
extension SortDirectionDisplay on SortDirection {
  String localizedName(AppLocalizations l10n) => switch (this) {
    SortDirection.ascending => l10n.enum_sortDirection_ascending,
    SortDirection.descending => l10n.enum_sortDirection_descending,
  };
}

extension DiveSortFieldDisplay on DiveSortField {
  String localizedName(AppLocalizations l10n) => switch (this) {
    DiveSortField.date => l10n.enum_sortField_date,
    DiveSortField.site => l10n.enum_sortField_site,
    DiveSortField.depth => l10n.enum_sortField_maxDepth,
    DiveSortField.bottomTime => l10n.enum_sortField_bottomTime,
    DiveSortField.rating => l10n.enum_sortField_rating,
    DiveSortField.diveNumber => l10n.enum_sortField_diveNumber,
  };
}

extension SiteSortFieldDisplay on SiteSortField {
  String localizedName(AppLocalizations l10n) => switch (this) {
    SiteSortField.name => l10n.enum_sortField_name,
    SiteSortField.rating => l10n.enum_sortField_rating,
    SiteSortField.difficulty => l10n.enum_sortField_difficulty,
    SiteSortField.depth => l10n.enum_sortField_maxDepth,
    SiteSortField.diveCount => l10n.enum_sortField_diveCount,
  };
}

extension TripSortFieldDisplay on TripSortField {
  String localizedName(AppLocalizations l10n) => switch (this) {
    TripSortField.startDate => l10n.enum_sortField_startDate,
    TripSortField.endDate => l10n.enum_sortField_endDate,
    TripSortField.name => l10n.enum_sortField_name,
  };
}

extension EquipmentSortFieldDisplay on EquipmentSortField {
  String localizedName(AppLocalizations l10n) => switch (this) {
    EquipmentSortField.name => l10n.enum_sortField_name,
    EquipmentSortField.type => l10n.enum_sortField_type,
    EquipmentSortField.purchaseDate => l10n.enum_sortField_purchaseDate,
    EquipmentSortField.lastServiceDate => l10n.enum_sortField_lastServiceDate,
    EquipmentSortField.serviceDue => l10n.enum_sortField_serviceDue,
  };
}

extension BuddySortFieldDisplay on BuddySortField {
  String localizedName(AppLocalizations l10n) => switch (this) {
    BuddySortField.name => l10n.enum_sortField_name,
    BuddySortField.diveCount => l10n.enum_sortField_diveCount,
  };
}

extension DiveCenterSortFieldDisplay on DiveCenterSortField {
  String localizedName(AppLocalizations l10n) => switch (this) {
    DiveCenterSortField.name => l10n.enum_sortField_name,
    DiveCenterSortField.diveCount => l10n.enum_sortField_diveCount,
  };
}

extension CertificationSortFieldDisplay on CertificationSortField {
  String localizedName(AppLocalizations l10n) => switch (this) {
    CertificationSortField.name => l10n.enum_sortField_name,
    CertificationSortField.dateIssued => l10n.enum_sortField_dateIssued,
    CertificationSortField.agency => l10n.enum_sortField_agency,
  };
}

extension CourseSortFieldDisplay on CourseSortField {
  String localizedName(AppLocalizations l10n) => switch (this) {
    CourseSortField.name => l10n.enum_sortField_name,
    CourseSortField.startDate => l10n.enum_sortField_startDate,
    CourseSortField.agency => l10n.enum_sortField_agency,
    CourseSortField.status => l10n.enum_sortField_status,
  };
}

extension MediaSortFieldDisplay on MediaSortField {
  String localizedName(AppLocalizations l10n) => switch (this) {
    MediaSortField.dateTaken => l10n.enum_sortField_dateTaken,
    MediaSortField.fileName => l10n.enum_sortField_fileName,
    MediaSortField.fileSize => l10n.enum_sortField_fileSize,
  };
}
