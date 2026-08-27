import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/core/services/sync/conflict_reference.dart';
import 'package:submersion/core/utils/unit_formatter.dart';
import 'package:submersion/features/settings/presentation/providers/settings_providers.dart';
import 'package:submersion/features/settings/presentation/widgets/conflict_reference_labels.dart';
import 'package:submersion/l10n/arb/app_localizations.dart';

/// Coverage for how the conflict dialog labels and renders a resolved
/// reference (#1031). The label table is the part of this feature that a new
/// foreign key silently falls out of, so it is asserted against the resolver's
/// own set of targets rather than a hand-kept list.
void main() {
  late AppLocalizations l10n;
  const units = UnitFormatter(AppSettings());

  setUpAll(() async {
    l10n = await AppLocalizations.delegate.load(const Locale('en'));
  });

  ConflictReference ref({
    String field = 'someId',
    String targetType = 'dives',
    String recordId = 'rec-1',
    bool exists = true,
    String? name,
    DateTime? timestamp,
  }) => ConflictReference(
    field: field,
    targetType: targetType,
    recordId: recordId,
    exists: exists,
    name: name,
    timestamp: timestamp,
  );

  group('labels', () {
    /// The label every target type is expected to carry. Kept explicit so a
    /// wrong switch arm fails loudly rather than reading plausibly.
    const expected = <String, String>{
      'dives': 'Dive',
      'diveSites': 'Dive site',
      'tags': 'Tag',
      'diveTypes': 'Dive type',
      'divers': 'Diver',
      'buddies': 'Buddy',
      'equipment': 'Equipment',
      'equipmentSets': 'Equipment set',
      'cylinderConfigs': 'Cylinder configuration',
      'diveComputers': 'Dive computer',
      'diveDataSources': 'Data source',
      'diveTanks': 'Tank',
      'divePlanTanks': 'Planned tank',
      'divePlans': 'Dive plan',
      'trips': 'Trip',
      'diveCenters': 'Dive center',
      'courses': 'Course',
      'certifications': 'Certification',
      'courseRequirements': 'Course requirement',
      'serviceKinds': 'Service type',
      'species': 'Species',
      'sightings': 'Sighting',
      'media': 'Media',
      'mediaSubscriptions': 'Media subscription',
      'connectedAccounts': 'Connected account',
      'preDiveSessions': 'Pre-dive checklist run',
      'checklistTemplates': 'Checklist template',
      'preDiveChecklistTemplates': 'Pre-dive checklist template',
    };

    test('covers every entity type a foreign key can point at', () {
      expect(
        expected.keys.toSet(),
        ConflictReferenceResolver.targetTypes,
        reason:
            'a new foreign-key target needs its own label arm and an entry '
            'here, or the dialog falls back to a humanized entity name',
      );
    });

    test('names each target type', () {
      for (final entry in expected.entries) {
        expect(
          conflictReferenceLabel(l10n, ref(targetType: entry.key)),
          entry.value,
          reason: entry.key,
        );
      }
    });

    test('lets a column name override its target type', () {
      // These columns all point at an entity that already has a label, but
      // mean something more specific than "another one of those".
      expect(
        conflictReferenceLabel(l10n, ref(field: 'relatedDiveId')),
        'Related dive',
      );
      expect(
        conflictReferenceLabel(l10n, ref(field: 'linkedDiveId')),
        'Linked dive',
      );
      expect(
        conflictReferenceLabel(l10n, ref(field: 'sourceDiveId')),
        'Source dive',
      );
      expect(
        conflictReferenceLabel(
          l10n,
          ref(field: 'instructorId', targetType: 'buddies'),
        ),
        'Instructor',
      );
      expect(
        conflictReferenceLabel(
          l10n,
          ref(field: 'signerId', targetType: 'buddies'),
        ),
        'Signed by',
      );
    });

    test('falls back to a readable entity name for an unknown target', () {
      expect(
        conflictReferenceLabel(l10n, ref(targetType: 'somethingNewEntirely')),
        'Something New Entirely',
      );
    });
  });

  group('values', () {
    test('pairs a name with a date when the record has both', () {
      final value = conflictReferenceValue(
        l10n,
        units,
        ref(name: 'Blue Hole', timestamp: DateTime(2026, 3, 28)),
      );
      expect(value, startsWith('Blue Hole ('));
      expect(value, endsWith(')'));
    });

    test('uses the name alone when there is no date', () {
      expect(conflictReferenceValue(l10n, units, ref(name: 'Wreck')), 'Wreck');
    });

    test('uses the date alone when there is no name', () {
      final value = conflictReferenceValue(
        l10n,
        units,
        ref(timestamp: DateTime(2026, 3, 28)),
      );
      expect(value, isNot(contains('(')));
      expect(value, isNotEmpty);
    });

    test('says so when the record is not in the library', () {
      expect(
        conflictReferenceValue(l10n, units, ref(exists: false)),
        'No longer in this library',
      );
    });

    test('falls back to a short id for a record with no anchor', () {
      expect(
        conflictReferenceValue(
          l10n,
          units,
          ref(recordId: 'aabbccdd-1111-2222-3333-444455556666'),
        ),
        '#aabbccdd',
      );
    });
  });

  group('summary', () {
    test('joins the names of the records a row points at', () {
      expect(
        conflictReferenceSummary([
          ref(targetType: 'dives', name: 'Blue Hole'),
          ref(targetType: 'tags', name: 'Wreck'),
        ]),
        'Blue Hole${kConflictSummarySeparator}Wreck',
      );
    });

    test('skips references that resolved to no name', () {
      expect(
        conflictReferenceSummary([
          ref(targetType: 'dives', name: 'Blue Hole'),
          ref(targetType: 'tags', exists: false),
        ]),
        'Blue Hole',
      );
    });

    test('caps the summary so a wide row does not run away', () {
      expect(
        conflictReferenceSummary([
          for (final n in ['a', 'b', 'c', 'd', 'e']) ref(name: n),
        ]),
        'a${kConflictSummarySeparator}b${kConflictSummarySeparator}c',
      );
    });

    test('is null when nothing resolved to a name', () {
      expect(conflictReferenceSummary([ref(exists: false)]), isNull);
      expect(conflictReferenceSummary(const []), isNull);
    });
  });

  group('short ids', () {
    test('trims a uuid to its leading segment', () {
      expect(shortRecordId('aabbccdd-1111-2222'), '#aabbccdd');
    });

    test('leaves an id shorter than the trim alone', () {
      expect(shortRecordId('ab12'), '#ab12');
    });
  });

  group('entity names', () {
    test('splits camelCase into words', () {
      expect(humanizeEntityType('diveTags'), 'Dive Tags');
      expect(humanizeEntityType('qualityFindings'), 'Quality Findings');
    });

    test('splits legacy snake_case too', () {
      expect(humanizeEntityType('dive_sites'), 'Dive Sites');
    });

    test('leaves a single lowercase word capitalized', () {
      expect(humanizeEntityType('media'), 'Media');
    });
  });
}
