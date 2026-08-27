import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:submersion/features/dive_log/domain/entities/dive.dart';
import 'package:submersion/features/dive_log/presentation/widgets/legend_candidates.dart';

LegendCandidate _candidate(String id, int priority, {bool isActive = false}) {
  return LegendCandidate(
    id: id,
    label: id,
    color: Colors.blue,
    isActive: isActive,
    priority: priority,
    onTap: () {},
  );
}

void main() {
  group('selectInlineCandidates', () {
    test('returns all candidates in priority order when everything fits', () {
      final candidates = [
        _candidate('b', 1),
        _candidate('a', 0, isActive: true),
        _candidate('c', 2),
      ];
      final admitted = selectInlineCandidates(
        candidates: candidates,
        availableWidth: 1000,
        itemWidth: (c) => 50,
      );
      expect(admitted.map((c) => c.id).toList(), ['a', 'b', 'c']);
    });

    test('active candidates win space over higher-priority inactive ones', () {
      final candidates = [
        _candidate('inactiveHigh', 0),
        _candidate('activeLow', 1, isActive: true),
      ];
      final admitted = selectInlineCandidates(
        candidates: candidates,
        availableWidth: 60,
        itemWidth: (c) => 50,
      );
      expect(admitted.map((c) => c.id).toList(), ['activeLow']);
    });

    test('stops at the first candidate that does not fit', () {
      // Admission order: a (40), b (100, does not fit) -> stop; c is never
      // admitted even though its 40px would fit the remaining budget. This
      // keeps the row prefix-stable instead of skipping around.
      final candidates = [
        _candidate('a', 0, isActive: true),
        _candidate('b', 1, isActive: true),
        _candidate('c', 2, isActive: true),
      ];
      final admitted = selectInlineCandidates(
        candidates: candidates,
        availableWidth: 90,
        itemWidth: (c) => c.id == 'b' ? 100 : 40,
      );
      expect(admitted.map((c) => c.id).toList(), ['a']);
    });

    test(
      'admitted set renders in priority order even when active order differs',
      () {
        final candidates = [
          _candidate('first', 0),
          _candidate('last', 3, isActive: true),
          _candidate('middle', 1, isActive: true),
        ];
        final admitted = selectInlineCandidates(
          candidates: candidates,
          availableWidth: 150,
          itemWidth: (c) => 50,
        );
        // All fit; display order is canonical priority order.
        expect(admitted.map((c) => c.id).toList(), ['first', 'middle', 'last']);
      },
    );

    test('returns empty for zero or negative width', () {
      final candidates = [_candidate('a', 0, isActive: true)];
      expect(
        selectInlineCandidates(
          candidates: candidates,
          availableWidth: 0,
          itemWidth: (c) => 50,
        ),
        isEmpty,
      );
      expect(
        selectInlineCandidates(
          candidates: candidates,
          availableWidth: -10,
          itemWidth: (c) => 50,
        ),
        isEmpty,
      );
    });

    test('returns empty for empty input', () {
      expect(
        selectInlineCandidates(
          candidates: const [],
          availableWidth: 100,
          itemWidth: (c) => 50,
        ),
        isEmpty,
      );
    });
  });

  group('sortTankIdsByOrder', () {
    test('sorts ids by tank order with unknown ids last', () {
      const tanks = [
        DiveTank(id: 't2', gasMix: GasMix(o2: 21), order: 1),
        DiveTank(id: 't1', gasMix: GasMix(o2: 21), order: 0),
      ];
      expect(sortTankIdsByOrder(['unknown', 't2', 't1'], tanks), [
        't1',
        't2',
        'unknown',
      ]);
    });
  });

  group('tankFallbackColor', () {
    test('cycles through the palette', () {
      expect(tankFallbackColor(0), tankFallbackColor(6));
      expect(tankFallbackColor(1), isNot(tankFallbackColor(2)));
    });
  });
}
