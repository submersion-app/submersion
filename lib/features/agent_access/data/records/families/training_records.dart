import 'package:drift/drift.dart' show Variable;

import 'package:submersion/core/query/domain/query_subject.dart';
import 'package:submersion/features/agent_access/data/documents/training_documents.dart';
import 'package:submersion/features/agent_access/data/records/record_entity.dart';
import 'package:submersion/features/agent_access/data/records/record_repositories.dart';
import 'package:submersion/features/agent_access/data/records/record_scope.dart';
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
import 'package:submersion/features/query/data/query_id_set_runner.dart';

/// The diver's own certifications plus those of the diver's buddies, whose
/// `diver_id` is null. `query` lists only the first; the second are reached
/// from a buddy, so their ids must read too.
QueryScope _certificationScope(String diverId, String alias) => (
  sql:
      '($alias.diver_id = ? OR $alias.buddy_id IN '
      '(SELECT ${alias}b.id FROM buddies ${alias}b '
      'WHERE ${alias}b.diver_id = ?))',
  params: [diverId, diverId],
);

final _viaCertification = viaParent(
  'certifications',
  'certification_id',
  _certificationScope,
);

/// Buddies, certifications, courses and species.
List<RecordEntry> trainingEntries(RecordRepositories r) => [
  RecordEntity<Buddy>(
    name: 'buddies',
    table: 'buddies',
    scope: rootScope(QuerySubject.buddies),
    orderBy: 'r0.name COLLATE NOCASE',
    load: (ids, _) => loadEach(ids, r.buddies.getBuddyById),
    document: buddyDocument,
    summaryKeys: const ['name', 'email', 'certification_title', 'is_favorite'],
    blocks: {
      'certifications': (buddy, _) async => [
        for (final c in await r.certifications.getCertificationMetadataByBuddy(
          buddy.id,
        ))
          certificationDocument(c),
      ],
    },
  ),
  RecordEntity<Certification>(
    name: 'certifications',
    table: 'certifications',
    scope: _certificationScope,
    orderBy: 'r0.issue_date DESC',
    load: (ids, _) => loadEach(ids, r.certifications.getCertificationById),
    document: certificationDocument,
    summaryKeys: const ['name', 'agency', 'level', 'issue_date', 'expiry_date'],
    blocks: {
      'currency_prefs': (certification, _) async => [
        for (final p in await r.currency.getPrefs(certification.id))
          currencyPrefDocument(p),
      ],
      'currency_events': (certification, _) async => [
        for (final e in await r.currency.getEvents(certification.id))
          currencyEventDocument(e),
      ],
    },
  ),
  RecordEntity<CurrencyRule>(
    name: 'currency_rules',
    table: 'certification_currency_rules',
    scope: ownedNullOrBuiltIn(),
    orderBy: 'r0.name COLLATE NOCASE',
    load: (ids, _) async => byId(await r.currency.getRules(), (x) => x.id),
    document: currencyRuleDocument,
    summaryKeys: const ['name', 'clock_kind', 'lapse_days', 'is_built_in'],
  ),
  RecordEntity<CurrencyPref>(
    name: 'currency_prefs',
    table: 'certification_currency_prefs',
    scope: _viaCertification,
    parentColumn: 'certification_id',
    load: (ids, _) async => byId(await r.currency.getAllPrefs(), (p) => p.id),
    document: currencyPrefDocument,
    summaryKeys: const ['certification_id', 'rule_id', 'muted'],
  ),
  RecordEntity<CurrencyEvent>(
    name: 'currency_events',
    table: 'certification_currency_events',
    scope: _viaCertification,
    parentColumn: 'certification_id',
    orderBy: 'r0.certification_id, r0.event_date DESC',
    load: (ids, _) async => byId(await r.currency.getAllEvents(), (e) => e.id),
    document: currencyEventDocument,
    summaryKeys: const ['certification_id', 'event_type', 'event_date'],
  ),
  RecordEntity<CustomCertificationAgency>(
    name: 'custom_agencies',
    table: 'custom_certification_agencies',
    scope: ownedOrShared(),
    orderBy: 'r0.name COLLATE NOCASE',
    load: (ids, _) async =>
        byId(await r.customCertifications.getAllAgencies(), (a) => a.id),
    document: customAgencyDocument,
    summaryKeys: const ['name', 'is_shared'],
  ),
  RecordEntity<CustomCertificationLevel>(
    name: 'custom_levels',
    table: 'custom_certification_levels',
    scope: ownedOrShared(),
    parentColumn: 'agency_id',
    orderBy: 'r0.agency_id, r0.sort_order',
    load: (ids, _) async =>
        byId(await r.customCertifications.getAllLevels(), (l) => l.id),
    document: customLevelDocument,
    summaryKeys: const ['agency_id', 'name', 'is_progression'],
  ),
  RecordEntity<Course>(
    name: 'courses',
    table: 'courses',
    scope: rootScope(QuerySubject.courses),
    orderBy: 'r0.start_date DESC',
    load: (ids, _) => loadEach(ids, r.courses.getCourseById),
    document: courseDocument,
    summaryKeys: const ['name', 'agency', 'start_date', 'completion_date'],
    blocks: {
      'requirements': (course, _) async => [
        for (final p in await _requirements(r, course.id))
          courseRequirementDocument(p),
      ],
      'dive_ids': (course, _) async {
        final rows = await r.db
            .customSelect(
              'SELECT dive_id FROM dive_courses WHERE course_id = ?',
              variables: [Variable<String>(course.id)],
            )
            .get();
        return [for (final row in rows) row.read<String>('dive_id')];
      },
    },
  ),
  RecordEntity<CourseRequirement>(
    name: 'course_requirements',
    table: 'course_requirements',
    scope: viaParent('courses', 'course_id', rootScope(QuerySubject.courses)),
    parentColumn: 'course_id',
    orderBy: 'r0.course_id, r0.sort_order',
    load: (ids, _) => loadChildren(
      r.db,
      table: 'course_requirements',
      parentColumn: 'course_id',
      ids: ids,
      idOf: (x) => x.id,
      byParents: (courses) async => {
        for (final id in courses) id: await _requirements(r, id),
      },
    ),
    document: courseRequirementDocument,
    summaryKeys: const ['course_id', 'name', 'kind', 'completed_at'],
  ),
  RecordEntity<Species>(
    name: 'species',
    table: 'species',
    scope: rootScope(QuerySubject.species),
    orderBy: 'r0.common_name COLLATE NOCASE',
    load: (ids, _) => loadEach(ids, r.species.getSpeciesById),
    document: speciesDocument,
    summaryKeys: const ['common_name', 'scientific_name', 'category'],
  ),
];

Future<List<CourseRequirement>> _requirements(
  RecordRepositories r,
  String courseId,
) async => [
  for (final p in (await r.courseRequirements.getCourseProgress(
    courseId,
  )).requirements)
    p.requirement,
];
