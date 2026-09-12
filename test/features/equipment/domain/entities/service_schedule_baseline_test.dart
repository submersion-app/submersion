import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/features/equipment/domain/entities/service_schedule.dart';

/// [ServiceSchedule.withBaseline] decides when a baseline's set time is
/// stamped, and that set time is what lets it outrank earlier records.
void main() {
  final created = DateTime(2025, 1, 1);
  final now = DateTime(2026, 9, 12, 10);

  ServiceSchedule schedule({DateTime? anchor, DateTime? setAt}) =>
      ServiceSchedule(
        id: 's1',
        equipmentId: 'e1',
        serviceKindId: 'hydro',
        anchorDate: anchor,
        anchorSetAt: setAt,
        createdAt: created,
        updatedAt: created,
      );

  test('a new date is stamped', () {
    final s = schedule().withBaseline(DateTime(2025, 6, 1), now: now);
    expect(s.anchorDate, DateTime(2025, 6, 1));
    expect(s.anchorSetAt, now);
  });

  test('a save that leaves the date alone keeps its set time', () {
    final setAt = DateTime(2026, 1, 2);
    final s = schedule(
      anchor: DateTime(2025, 6, 1),
      setAt: setAt,
    ).withBaseline(DateTime(2025, 6, 1), now: now);
    expect(s.anchorSetAt, setAt);
  });

  test('picking the same date again is stamped', () {
    // A baseline set before v213 carries no set time, so the old rule (any
    // record wins) still governs it. Re-picking it is how a diver moves it
    // onto the new rule; a same-date pick must not be a no-op.
    final s = schedule(
      anchor: DateTime(2025, 6, 1),
    ).withBaseline(DateTime(2025, 6, 1), now: now, picked: true);
    expect(s.anchorDate, DateTime(2025, 6, 1));
    expect(s.anchorSetAt, now);
  });

  test('clearing drops the set time too', () {
    final s = schedule(
      anchor: DateTime(2025, 6, 1),
      setAt: DateTime(2026, 1, 2),
    ).withBaseline(null, now: now);
    expect(s.anchorDate, isNull);
    expect(s.anchorSetAt, isNull);
  });
}
