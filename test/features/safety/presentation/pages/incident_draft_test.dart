import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/features/safety/domain/entities/incident.dart';
import 'package:submersion/features/safety/domain/entities/incident_changes.dart';
import 'package:submersion/features/safety/presentation/pages/incident_draft.dart';

/// The near-miss editor's draft (issue #4527, phase 4, plan 4).
void main() {
  final day = DateTime.utc(2026, 7, 10);

  IncidentDraft stored({
    IncidentSeverity severity = IncidentSeverity.moderate,
    String? observationId = 'o1',
    String? diveId,
    String? checkInDiveId = 'd1',
    String lessons = 'Service the reg.',
  }) => (
    category: IncidentCategory.gasSupply,
    severity: severity,
    occurredAt: day,
    equipmentId: 'reg',
    observationId: observationId,
    diveId: diveId,
    checkInDiveId: checkInDiveId,
    narrative: 'Free-flow at 18 m.',
    factors: '',
    lessons: lessons,
  );

  test('a blank draft is equal to another blank draft of the same day', () {
    expect(blankIncidentDraft(day), blankIncidentDraft(day));
    final blank = blankIncidentDraft(day);
    expect(blank.category, IncidentCategory.other);
    expect(blank.severity, IncidentSeverity.minor);
    expect(blank.occurredAt, day);
    expect(blank.equipmentId, isNull);
    expect(blank.diveId, isNull);
    expect(blank.narrative, '');
  });

  test('a severity change is the only change', () {
    expect(
      incidentChanges(
        draft: stored(severity: IncidentSeverity.serious),
        start: stored(),
        linkable: null,
      ),
      const IncidentChanges(severity: IncidentSeverity.serious),
    );
  });

  test('texts are trimmed and a blank one is cleared', () {
    final changes = incidentChanges(
      draft: stored(lessons: '   '),
      start: stored(),
      linkable: null,
    );
    expect(changes.lessonsLearned, (value: null));
    final trimmed = incidentChanges(
      draft: stored(lessons: '  Carry a spare. '),
      start: stored(),
      linkable: null,
    );
    expect(trimmed.lessonsLearned, (value: 'Carry a spare.'));
  });

  test('an untouched link writes no link even when it no longer stands', () {
    final changes = incidentChanges(
      draft: stored(severity: IncidentSeverity.serious),
      start: stored(),
      linkable: null,
    );
    expect(changes.observationId, isNull);
    expect(changes.diveId, isNull);
  });

  test('a check-in picked writes it, its item and its dive', () {
    final changes = incidentChanges(
      draft: stored(observationId: 'o2', checkInDiveId: 'd2'),
      start: stored(),
      linkable: 'o2',
    );
    expect(changes.observationId, (value: 'o2'));
    expect(changes.equipmentId, (value: 'reg'));
    expect(changes.diveId, (value: 'd2'));
  });

  test('a check-in on the dive the report already has leaves the dive as '
      'stored', () {
    // Only the link changed: a dive synced in meanwhile is not overwritten
    // with the one the page loaded.
    final start = stored(
      observationId: null,
      diveId: 'd1',
      checkInDiveId: null,
    );
    final picked = stored(
      observationId: 'o2',
      diveId: 'd1',
      checkInDiveId: 'd1',
    );
    final changes = incidentChanges(
      draft: picked,
      start: start,
      linkable: 'o2',
    );
    expect(changes.observationId, (value: 'o2'));
    expect(changes.diveId, isNull);
  });

  test('a check-in that has gone takes its dive with it', () {
    final changes = incidentChanges(
      draft: stored(observationId: 'o2', checkInDiveId: 'd2'),
      start: stored(),
      linkable: null,
    );
    expect(changes.observationId, (value: null));
    expect(changes.diveId, (value: null));
    expect(changes.equipmentId, isNull);
  });

  test('the report keeps its own dive when its check-in goes', () {
    expect(incidentSavedDiveId(stored(diveId: 'own'), null), 'own');
    expect(incidentSavedDiveId(stored(diveId: null), 'o1'), 'd1');
    expect(incidentSavedDiveId(stored(diveId: null), null), isNull);
  });

  test('moving the report to another item writes its link afresh', () {
    // A check-in belongs to one item: a link stored on the old item (even
    // one that does not stand, which reads as none) must not follow.
    final start = stored(observationId: null, checkInDiveId: null);
    final moved = (
      category: start.category,
      severity: start.severity,
      occurredAt: start.occurredAt,
      equipmentId: 'bcd',
      observationId: null,
      diveId: start.diveId,
      checkInDiveId: null,
      narrative: start.narrative,
      factors: start.factors,
      lessons: start.lessons,
    );
    final changes = incidentChanges(draft: moved, start: start, linkable: null);
    expect(changes.equipmentId, (value: 'bcd'));
    expect(changes.observationId, (value: null));
    // The report's own dive is the same before and after: left as stored.
    expect(changes.diveId, isNull);
  });

  test('an unchanged draft changes nothing', () {
    expect(
      incidentChanges(draft: stored(), start: stored(), linkable: 'o1').isEmpty,
      isTrue,
    );
  });
}
