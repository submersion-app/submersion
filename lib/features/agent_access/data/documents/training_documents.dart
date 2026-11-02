import 'package:submersion/features/agent_access/data/documents/document_dates.dart';
import 'package:submersion/features/buddies/domain/entities/buddy.dart';
import 'package:submersion/features/certification_agencies/domain/entities/custom_certification_agency.dart';
import 'package:submersion/features/certification_agencies/domain/entities/custom_certification_level.dart';
import 'package:submersion/features/certifications/domain/entities/certification.dart';
import 'package:submersion/features/certifications/domain/entities/currency_event.dart';
import 'package:submersion/features/certifications/domain/entities/currency_pref.dart';
import 'package:submersion/features/certifications/domain/entities/currency_rule.dart';
import 'package:submersion/features/courses/domain/entities/course.dart';
import 'package:submersion/features/courses/domain/entities/course_requirement.dart';
import 'package:submersion/features/marine_life/domain/entities/species.dart';

/// The agent-facing document for a buddy. Contact details stay in; the photo
/// bytes never do.
Map<String, Object?> buddyDocument(Buddy b) => {
  'id': b.id,
  'diver_id': b.diverId,
  'linked_diver_id': b.linkedDiverId,
  'name': b.name,
  'email': b.email,
  'phone': b.phone,
  'social_handle': b.socialHandle,
  'certification_level': b.certificationLevel,
  'certification_agency': b.certificationAgency,
  'certification_title': b.certificationTitle,
  'photo_path': b.photoPath,
  'notes': b.notes,
  'is_favorite': b.isFavorite,
  'excluded_from_rankings': b.excludedFromRankings,
  'card_id': b.cardId,
  'card_dive_count': b.cardDiveCount,
  'card_diving_since_date': calendarDate(b.cardDivingSince),
  'card_last_dive_date': calendarDate(b.cardLastDive),
  'card_received_at': instant(b.cardReceivedAt),
};

/// A certification without its card images, which are bytes.
Map<String, Object?> certificationDocument(Certification c) => {
  'id': c.id,
  'diver_id': c.diverId,
  'buddy_id': c.buddyId,
  'name': c.name,
  'agency': c.agency,
  'level': c.level,
  'additional_credentials': [
    for (final credential in c.additionalCredentials) credential.toJson(),
  ],
  'card_number': c.cardNumber,
  'issue_date': calendarDate(c.issueDate),
  'expiry_date': calendarDate(c.expiryDate),
  'instructor_name': c.instructorName,
  'instructor_number': c.instructorNumber,
  'instructor_id': c.instructorId,
  'course_id': c.courseId,
  'card_id': c.cardId,
  'notes': c.notes,
};

Map<String, Object?> currencyRuleDocument(CurrencyRule r) => {
  'id': r.id,
  'diver_id': r.diverId,
  'name': r.name,
  'clock_kind': r.clockKind.name,
  'agencies': [for (final a in r.agencies) a.name],
  'levels': [for (final l in r.levels) l.name],
  'lapse_days': r.lapseDays,
  'lead_days': r.leadDays,
  'counted_dive_type_ids': r.countedDiveTypeIds,
  'counted_dive_modes': [for (final m in r.countedDiveModes) m.name],
  'advisory_key': r.advisoryKey,
  'advisory_text': r.advisoryText,
  'supersedes_rule_id': r.supersedesRuleId,
  'is_built_in': r.isBuiltIn,
};

Map<String, Object?> currencyPrefDocument(CurrencyPref p) => {
  'id': p.id,
  'certification_id': p.certificationId,
  'rule_id': p.ruleId,
  'lapse_days_override': p.lapseDaysOverride,
  'lead_days_override': p.leadDaysOverride,
  'counted_dive_type_ids': p.countedDiveTypeIds,
  'counted_dive_modes': p.countedDiveModes == null
      ? null
      : [for (final m in p.countedDiveModes!) m.name],
  'muted': p.muted,
};

Map<String, Object?> currencyEventDocument(CurrencyEvent e) => {
  'id': e.id,
  'certification_id': e.certificationId,
  'rule_id': e.ruleId,
  'event_type': e.eventType.name,
  'event_date': calendarDate(e.eventDate),
  'provider': e.provider,
  'notes': e.notes,
};

Map<String, Object?> customAgencyDocument(CustomCertificationAgency a) => {
  'id': a.id,
  'diver_id': a.diverId,
  'name': a.name,
  'color_argb': a.colorArgb,
  'is_shared': a.isShared,
};

Map<String, Object?> customLevelDocument(CustomCertificationLevel l) => {
  'id': l.id,
  'diver_id': l.diverId,
  'agency_id': l.agencyId,
  'name': l.name,
  'is_progression': l.isProgression,
  'sort_order': l.sortOrder,
  'is_shared': l.isShared,
};

Map<String, Object?> courseDocument(Course c) => {
  'id': c.id,
  'diver_id': c.diverId,
  'name': c.name,
  'agency': c.agency,
  'start_date': calendarDate(c.startDate),
  'completion_date': calendarDate(c.completionDate),
  'instructor_id': c.instructorId,
  'instructor_name': c.instructorName,
  'instructor_number': c.instructorNumber,
  'certification_id': c.certificationId,
  'location': c.location,
  'notes': c.notes,
};

Map<String, Object?> courseRequirementDocument(CourseRequirement r) => {
  'id': r.id,
  'course_id': r.courseId,
  'name': r.name,
  'kind': r.kind.name,
  'target_count': r.targetCount,
  'completed_at': instant(r.completedAt),
  'sort_order': r.sortOrder,
  'notes': r.notes,
};

Map<String, Object?> speciesDocument(Species s) => {
  'id': s.id,
  'common_name': s.commonName,
  'scientific_name': s.scientificName,
  'category': s.category.name,
  'taxonomy_class': s.taxonomyClass,
  'description': s.description,
  'photo_path': s.photoPath,
  'is_built_in': s.isBuiltIn,
};
