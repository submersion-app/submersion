import 'package:submersion/core/services/sync/conflict_reference.dart';
import 'package:submersion/core/utils/unit_formatter.dart';
import 'package:submersion/l10n/arb/app_localizations.dart';

/// Separator between the parts of a composed conflict title.
const String kConflictSummarySeparator = ' • ';

/// What to call a resolved reference in the conflict dialog.
///
/// Most columns are named after the entity they point at, so the target type
/// carries the label. The handful of columns that point at the same entity for
/// a different reason (a related dive, a course instructor) name themselves.
String conflictReferenceLabel(
  AppLocalizations l10n,
  ConflictReference reference,
) {
  switch (reference.field) {
    case 'relatedDiveId':
      return l10n.settings_conflict_ref_relatedDive;
    case 'linkedDiveId':
      return l10n.settings_conflict_ref_linkedDive;
    case 'sourceDiveId':
      return l10n.settings_conflict_ref_sourceDive;
    case 'instructorId':
      return l10n.settings_conflict_ref_instructor;
    case 'signerId':
      return l10n.settings_conflict_ref_signer;
  }
  switch (reference.targetType) {
    case 'dives':
      return l10n.settings_conflict_ref_dive;
    case 'diveSites':
      return l10n.settings_conflict_ref_diveSite;
    case 'tags':
      return l10n.settings_conflict_ref_tag;
    case 'diveTypes':
      return l10n.settings_conflict_ref_diveType;
    case 'divers':
      return l10n.settings_conflict_ref_diver;
    case 'buddies':
      return l10n.settings_conflict_ref_buddy;
    case 'equipment':
      return l10n.settings_conflict_ref_equipment;
    case 'equipmentSets':
      return l10n.settings_conflict_ref_equipmentSet;
    case 'cylinderConfigs':
      return l10n.settings_conflict_ref_cylinderConfig;
    case 'diveComputers':
      return l10n.settings_conflict_ref_diveComputer;
    case 'diveDataSources':
      return l10n.settings_conflict_ref_dataSource;
    case 'diveTanks':
      return l10n.settings_conflict_ref_tank;
    case 'divePlanTanks':
      return l10n.settings_conflict_ref_plannedTank;
    case 'divePlans':
      return l10n.settings_conflict_ref_divePlan;
    case 'trips':
      return l10n.settings_conflict_ref_trip;
    case 'diveCenters':
      return l10n.settings_conflict_ref_diveCenter;
    case 'courses':
      return l10n.settings_conflict_ref_course;
    case 'certifications':
      return l10n.settings_conflict_ref_certification;
    case 'courseRequirements':
      return l10n.settings_conflict_ref_courseRequirement;
    case 'serviceKinds':
      return l10n.settings_conflict_ref_serviceKind;
    case 'species':
      return l10n.settings_conflict_ref_species;
    case 'sightings':
      return l10n.settings_conflict_ref_sighting;
    case 'media':
      return l10n.settings_conflict_ref_media;
    case 'mediaSubscriptions':
      return l10n.settings_conflict_ref_mediaSubscription;
    case 'connectedAccounts':
      return l10n.settings_conflict_ref_connectedAccount;
    case 'preDiveSessions':
      return l10n.settings_conflict_ref_preDiveSession;
    case 'checklistTemplates':
      return l10n.settings_conflict_ref_checklistTemplate;
    case 'preDiveChecklistTemplates':
      return l10n.settings_conflict_ref_preDiveChecklistTemplate;
    default:
      return humanizeEntityType(reference.targetType);
  }
}

/// The referenced record in one line: its name, its date, or both. A record
/// that is not in the local library says so rather than rendering blank; one
/// that is present but carries no anchor at all (an unnamed dive tank, say)
/// falls back to a short id, which at least tells the two versions apart.
String conflictReferenceValue(
  AppLocalizations l10n,
  UnitFormatter units,
  ConflictReference reference,
) {
  if (reference.isMissing) return l10n.settings_conflict_ref_missing;
  final date = reference.timestamp == null
      ? null
      : units.formatDate(reference.timestamp);
  final name = reference.name;
  if (name != null && date != null) {
    return l10n.settings_conflict_ref_named(name, date);
  }
  return name ?? date ?? shortRecordId(reference.recordId);
}

/// The leading segment of a record id, the way a user would quote one.
String shortRecordId(String recordId) =>
    '#${recordId.length <= 8 ? recordId : recordId.substring(0, 8)}';

/// Names the conflicting record from the records it points at, for junction
/// and relation entities that have no name of their own. Null when nothing
/// resolved, so the caller can fall back to the entity type and id.
String? conflictReferenceSummary(List<ConflictReference> references) {
  final names = [
    for (final reference in references)
      if (reference.name != null) reference.name!,
  ];
  if (names.isEmpty) return null;
  return names.take(3).join(kConflictSummarySeparator);
}

/// Turns a sync entity type into readable words: `diveTags` -> `Dive Tags`.
/// Used for the entity types that have no dedicated label of their own.
String humanizeEntityType(String entityType) {
  final spaced = entityType
      .replaceAll('_', ' ')
      .replaceAllMapped(RegExp(r'(?<=[a-z0-9])(?=[A-Z])'), (_) => ' ');
  return spaced
      .split(' ')
      .where((word) => word.isNotEmpty)
      .map((word) => '${word[0].toUpperCase()}${word.substring(1)}')
      .join(' ');
}
