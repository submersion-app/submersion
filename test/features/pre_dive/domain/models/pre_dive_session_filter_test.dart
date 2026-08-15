import 'package:flutter/material.dart' show DateTimeRange;
import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/features/pre_dive/domain/entities/pre_dive_session.dart';
import 'package:submersion/features/pre_dive/domain/models/pre_dive_session_filter.dart';

void main() {
  PreDiveSession session(
    String id, {
    String name = 'CCR Build',
    PreDiveSessionStatus status = PreDiveSessionStatus.completed,
    DateTime? startedAt,
  }) {
    final at = startedAt ?? DateTime(2026, 3, 15, 9);
    return PreDiveSession(
      id: id,
      templateName: name,
      status: status,
      startedAt: at,
      createdAt: at,
      updatedAt: at,
    );
  }

  const noStats = <String, PreDiveSessionStats>{};

  group('hasActiveFilters', () {
    test('is false for a default filter', () {
      expect(const PreDiveSessionFilter().hasActiveFilters, isFalse);
    });

    test('is true when any single facet is set', () {
      expect(
        const PreDiveSessionFilter(
          templateNames: {'CCR Build'},
        ).hasActiveFilters,
        isTrue,
      );
      expect(
        const PreDiveSessionFilter(
          statuses: {PreDiveSessionStatus.aborted},
        ).hasActiveFilters,
        isTrue,
      );
      expect(
        const PreDiveSessionFilter(flaggedOnly: true).hasActiveFilters,
        isTrue,
      );
      expect(
        PreDiveSessionFilter(
          dateRange: DateTimeRange(
            start: DateTime(2026, 1, 1),
            end: DateTime(2026, 2, 1),
          ),
        ).hasActiveFilters,
        isTrue,
      );
    });
  });

  group('apply', () {
    test('returns every session when no facet is set', () {
      final sessions = [session('a'), session('b')];

      expect(const PreDiveSessionFilter().apply(sessions, noStats), sessions);
    });

    test('keeps only sessions whose template name was selected', () {
      final ccr = session('a', name: 'CCR Build');
      final bwraf = session('b', name: 'BWRAF');

      final result = const PreDiveSessionFilter(
        templateNames: {'CCR Build'},
      ).apply([ccr, bwraf], noStats);

      expect(result, [ccr]);
    });

    test('treats multiple selected template names as a union', () {
      final ccr = session('a', name: 'CCR Build');
      final bwraf = session('b', name: 'BWRAF');
      final gue = session('c', name: 'GUE EDGE');

      final result = const PreDiveSessionFilter(
        templateNames: {'CCR Build', 'GUE EDGE'},
      ).apply([ccr, bwraf, gue], noStats);

      expect(result, [ccr, gue]);
    });

    test('keeps only sessions in a selected status', () {
      final done = session('a', status: PreDiveSessionStatus.completed);
      final aborted = session('b', status: PreDiveSessionStatus.aborted);

      final result = const PreDiveSessionFilter(
        statuses: {PreDiveSessionStatus.aborted},
      ).apply([done, aborted], noStats);

      expect(result, [aborted]);
    });

    test('flaggedOnly keeps sessions with at least one flagged item', () {
      final clean = session('a');
      final flagged = session('b');
      const stats = {
        'a': PreDiveSessionStats(total: 3, resolved: 3),
        'b': PreDiveSessionStats(total: 3, resolved: 3, flagged: 1),
      };

      final result = const PreDiveSessionFilter(
        flaggedOnly: true,
      ).apply([clean, flagged], stats);

      expect(result, [flagged]);
    });

    test('flaggedOnly drops sessions with no stats entry', () {
      // A session whose tallies have not loaded cannot be proven flagged, and
      // showing it would misreport the safety-review view.
      final unknown = session('a');

      final result = const PreDiveSessionFilter(
        flaggedOnly: true,
      ).apply([unknown], noStats);

      expect(result, isEmpty);
    });

    test('date range includes sessions on both boundary days', () {
      final onStart = session('a', startedAt: DateTime(2026, 3, 1, 6));
      final middle = session('b', startedAt: DateTime(2026, 3, 15, 12));
      final onEnd = session('c', startedAt: DateTime(2026, 3, 31, 23, 30));
      final after = session('d', startedAt: DateTime(2026, 4, 1, 0, 30));
      final before = session('e', startedAt: DateTime(2026, 2, 28, 23, 30));

      final result = PreDiveSessionFilter(
        dateRange: DateTimeRange(
          start: DateTime(2026, 3, 1),
          end: DateTime(2026, 3, 31),
        ),
      ).apply([onStart, middle, onEnd, after, before], noStats);

      expect(result, [onStart, middle, onEnd]);
    });

    test('combines facets as an intersection', () {
      final match = session(
        'a',
        name: 'CCR Build',
        status: PreDiveSessionStatus.completed,
        startedAt: DateTime(2026, 3, 10),
      );
      final wrongTemplate = session(
        'b',
        name: 'BWRAF',
        status: PreDiveSessionStatus.completed,
        startedAt: DateTime(2026, 3, 10),
      );
      final wrongStatus = session(
        'c',
        name: 'CCR Build',
        status: PreDiveSessionStatus.aborted,
        startedAt: DateTime(2026, 3, 10),
      );
      final outOfRange = session(
        'd',
        name: 'CCR Build',
        status: PreDiveSessionStatus.completed,
        startedAt: DateTime(2026, 5, 10),
      );
      const stats = {
        'a': PreDiveSessionStats(total: 2, resolved: 2, flagged: 1),
        'b': PreDiveSessionStats(total: 2, resolved: 2, flagged: 1),
        'c': PreDiveSessionStats(total: 2, resolved: 2, flagged: 1),
        'd': PreDiveSessionStats(total: 2, resolved: 2, flagged: 1),
      };

      final result = PreDiveSessionFilter(
        templateNames: const {'CCR Build'},
        statuses: const {PreDiveSessionStatus.completed},
        flaggedOnly: true,
        dateRange: DateTimeRange(
          start: DateTime(2026, 3, 1),
          end: DateTime(2026, 3, 31),
        ),
      ).apply([match, wrongTemplate, wrongStatus, outOfRange], stats);

      expect(result, [match]);
    });
  });

  group('copyWith', () {
    test('replaces individual facets', () {
      const original = PreDiveSessionFilter(templateNames: {'CCR Build'});

      final updated = original.copyWith(flaggedOnly: true);

      expect(updated.templateNames, {'CCR Build'});
      expect(updated.flaggedOnly, isTrue);
    });

    test('clearDateRange removes a range that copyWith cannot null out', () {
      final original = PreDiveSessionFilter(
        dateRange: DateTimeRange(
          start: DateTime(2026, 1, 1),
          end: DateTime(2026, 2, 1),
        ),
      );

      expect(original.copyWith(clearDateRange: true).dateRange, isNull);
      // Omitting the flag must preserve the existing range.
      expect(original.copyWith(flaggedOnly: true).dateRange, isNotNull);
    });
  });
}
