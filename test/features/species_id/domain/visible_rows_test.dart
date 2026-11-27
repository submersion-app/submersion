import 'package:flutter_test/flutter_test.dart';

import 'package:submersion/features/species_id/domain/entities/media_identification.dart';
import 'package:submersion/features/species_id/domain/services/identification_rules.dart';

import '../data/identification_fixtures.dart';

/// The rows shown for a media (issue #4876): a run's own, and every row the
/// diver said something on. Rows of a run that lost a sync race are hidden.
void main() {
  final current = run().copyWith(runId: () => 'r2');
  MediaIdentification of(String id, String? runId) =>
      identification(id).copyWith(runId: () => runId);

  test('hides an undecided, unclaimed row of another run', () {
    expect(
      visibleRows(current, [of('a', 'r2'), of('b', 'r1')]).map((i) => i.id),
      ['a'],
    );
  });

  test('keeps a decided, claimed or reopened row of another run', () {
    final decided = identification(
      'd',
      decision: IdentificationDecision.accepted,
    ).copyWith(runId: () => 'r1');
    final claimed = of('c', 'r1').copyWith(claimedSpeciesId: () => 'sp1');
    final reopened = of('o', 'r1').copyWith(decidedAt: DateTime.utc(2026));
    expect(
      visibleRows(current, [decided, claimed, reopened]).map((i) => i.id),
      ['d', 'c', 'o'],
    );
  });

  test('keeps a row with no run id', () {
    expect(visibleRows(current, [of('a', null)]), hasLength(1));
  });

  test('keeps every row with no run, or a run with no id', () {
    final rows = [of('a', 'r1'), of('b', 'r9')];
    expect(visibleRows(null, rows), rows);
    expect(visibleRows(run(), rows), rows);
  });
}
