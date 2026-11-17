import 'package:flutter_test/flutter_test.dart';

import 'package:submersion/core/services/change_log/change_log_scope.dart';
import 'package:submersion/features/change_log/domain/entities/change_log_operation.dart';

void main() {
  final operation = ChangeLogOperation(
    id: 'op',
    source: ChangeLogSource.manual,
    label: 'record_edit:dives:d1:notes',
    diverId: 'owner',
    rootTable: 'dives',
    rootId: 'd1',
    rootLabel: 'Reef',
    rootOrdinal: 24,
    startedAt: DateTime(2026, 11, 16),
    endedAt: DateTime(2026, 11, 16),
    eventCount: 5,
  );

  // A diver who sees only part of an entry (issue #4527) reads it titled
  // with a record they see, and with no dive number.
  test('restrictedTo retitles the entry and keeps the rest', () {
    final shown = {(table: 'dive_sites', id: 's1')};

    final restricted = operation.restrictedTo(
      shown,
      root: (table: 'dive_sites', id: 's1'),
      label: 'La Machaca',
    );

    expect(restricted.rootTable, 'dive_sites');
    expect(restricted.rootId, 's1');
    expect(restricted.rootLabel, 'La Machaca');
    expect(restricted.rootOrdinal, isNull);
    expect(restricted.shownRoots, shown);
    expect(restricted.id, operation.id);
    expect(restricted.label, operation.label);
    expect(restricted.eventCount, 5);
    expect(restricted.isBulk, isFalse);
  });

  test('copyWith marks it reverted and keeps what a diver sees', () {
    final restricted = operation.restrictedTo(
      {(table: 'dive_sites', id: 's1')},
      root: (table: 'dive_sites', id: 's1'),
      label: null,
    );

    final reverted = restricted.copyWith(revertedById: 'undo');

    expect(reverted.isReverted, isTrue);
    expect(reverted.revertedById, 'undo');
    expect(reverted.shownRoots, restricted.shownRoots);
    expect(reverted.rootId, 's1');
    expect(reverted, isNot(restricted));
    expect(operation.copyWith(), operation);
  });
}
