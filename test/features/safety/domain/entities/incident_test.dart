import 'package:flutter_test/flutter_test.dart';

import 'package:submersion/features/safety/domain/entities/incident.dart';

void main() {
  Incident base() => Incident(
    id: 'i1',
    diverId: 'diver-1',
    diveId: 'dive-1',
    occurredAt: DateTime.utc(2026, 7, 10),
    category: IncidentCategory.gasSupply,
    severity: IncidentSeverity.moderate,
    narrative: 'Free-flow at 18 m.',
    contributingFactors: 'Cold water.',
    lessonsLearned: 'Service the reg.',
    createdAt: DateTime.utc(2026, 7, 10),
    updatedAt: DateTime.utc(2026, 7, 10),
  );

  test('value equality is by every field (props)', () {
    expect(base(), equals(base()));
    expect(base().hashCode, equals(base().hashCode));
    expect(base(), isNot(equals(base().copyWith(narrative: 'different'))));
  });

  test('copyWith replaces only the named fields', () {
    final updated = base().copyWith(
      category: IncidentCategory.equipment,
      severity: IncidentSeverity.serious,
    );
    expect(updated.category, IncidentCategory.equipment);
    expect(updated.severity, IncidentSeverity.serious);
    expect(updated.id, base().id);
    expect(updated.narrative, base().narrative);
    expect(updated.diveId, base().diveId);
  });

  test('copyWith(clearDiveId: true) severs the dive link', () {
    expect(base().copyWith(clearDiveId: true).diveId, isNull);
    // Without the flag, an omitted diveId is preserved (not nulled).
    expect(base().copyWith(narrative: 'x').diveId, 'dive-1');
  });

  test('enum db-value round-trips, unknown values fall back', () {
    expect(
      IncidentCategory.fromDbValue('equipment'),
      IncidentCategory.equipment,
    );
    expect(IncidentCategory.fromDbValue('bogus'), IncidentCategory.other);
    expect(IncidentSeverity.fromDbValue('serious'), IncidentSeverity.serious);
    expect(IncidentSeverity.fromDbValue(null), IncidentSeverity.minor);
  });
}
