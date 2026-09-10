import 'package:flutter_test/flutter_test.dart';

import 'package:submersion/features/dive_log/domain/entities/dive_summary.dart';
import 'package:submersion/features/dive_log/presentation/helpers/dive_list_sections.dart';

void main() {
  _retryDecisionTests();

  DiveSummary dive(String id, {String? tripId, String? tripName}) {
    return DiveSummary(
      id: id,
      dateTime: DateTime(2026, 6, 8),
      sortTimestamp: 0,
      tripId: tripId,
      tripName: tripName,
      tripStartDate: tripId == null ? null : DateTime(2026, 6, 8),
      tripEndDate: tripId == null ? null : DateTime(2026, 6, 9),
    );
  }

  group('buildDiveListSections', () {
    test('grouping off yields one loose section holding every dive', () {
      final sections = buildDiveListSections(
        dives: [
          dive('d1', tripId: 't1', tripName: 'Tassie'),
          dive('d2'),
        ],
        groupingEnabled: false,
        collapsedTripIds: const {},
        tripTotals: const {'t1': 4},
      );

      expect(sections, hasLength(1));
      expect(sections.single, isA<LooseSection>());
      expect(sections.single.entries, hasLength(2));
    });

    test('an empty list yields no sections', () {
      final sections = buildDiveListSections(
        dives: const [],
        groupingEnabled: true,
        collapsedTripIds: const {},
        tripTotals: const {},
      );

      expect(sections, isEmpty);
    });

    test('a run of same-trip dives becomes one trip section', () {
      final sections = buildDiveListSections(
        dives: [
          dive('d1'),
          dive('d2', tripId: 't1', tripName: 'Tassie'),
          dive('d3', tripId: 't1', tripName: 'Tassie'),
          dive('d4'),
        ],
        groupingEnabled: true,
        collapsedTripIds: const {},
        tripTotals: const {'t1': 4},
      );

      expect(sections, hasLength(3));
      expect(sections[0], isA<LooseSection>());
      expect(sections[2], isA<LooseSection>());

      final trip = sections[1] as TripSection;
      expect(trip.tripId, 't1');
      expect(trip.tripName, 'Tassie');
      expect(trip.loadedCount, 2);
      expect(trip.totalCount, 4);
      expect(trip.isPartial, isTrue);
      expect(trip.collapsed, isFalse);
    });

    test('two adjacent trips do not merge', () {
      final sections = buildDiveListSections(
        dives: [
          dive('d1', tripId: 't1', tripName: 'Tassie'),
          dive('d2', tripId: 't2', tripName: 'Red Sea'),
        ],
        groupingEnabled: true,
        collapsedTripIds: const {},
        tripTotals: const {'t1': 1, 't2': 1},
      );

      expect(sections, hasLength(2));
      expect((sections[0] as TripSection).tripId, 't1');
      expect((sections[1] as TripSection).tripId, 't2');
    });

    test('a trip interrupted by a loose dive yields two sections, both '
        'labelled with the trip total', () {
      final sections = buildDiveListSections(
        dives: [
          dive('d1', tripId: 't1', tripName: 'Tassie'),
          dive('d2'),
          dive('d3', tripId: 't1', tripName: 'Tassie'),
        ],
        groupingEnabled: true,
        collapsedTripIds: const {},
        tripTotals: const {'t1': 4},
      );

      expect(sections, hasLength(3));
      expect((sections[0] as TripSection).totalCount, 4);
      expect((sections[2] as TripSection).totalCount, 4);
    });

    test('a fully loaded trip is not partial', () {
      final sections = buildDiveListSections(
        dives: [
          dive('d1', tripId: 't1', tripName: 'Tassie'),
          dive('d2', tripId: 't1', tripName: 'Tassie'),
        ],
        groupingEnabled: true,
        collapsedTripIds: const {},
        tripTotals: const {'t1': 2},
      );

      expect((sections.single as TripSection).isPartial, isFalse);
    });

    test('entries keep their original flat index', () {
      final sections = buildDiveListSections(
        dives: [
          dive('d1'),
          dive('d2', tripId: 't1', tripName: 'Tassie'),
          dive('d3', tripId: 't1', tripName: 'Tassie'),
        ],
        groupingEnabled: true,
        collapsedTripIds: const {},
        tripTotals: const {'t1': 2},
      );

      final trip = sections[1] as TripSection;
      expect(trip.entries.map((e) => e.flatIndex), [1, 2]);
    });

    test('a collapsed trip keeps its entries but reports collapsed', () {
      final sections = buildDiveListSections(
        dives: [dive('d1', tripId: 't1', tripName: 'Tassie')],
        groupingEnabled: true,
        collapsedTripIds: const {'t1'},
        tripTotals: const {'t1': 1},
      );

      final trip = sections.single as TripSection;
      expect(trip.collapsed, isTrue);
      expect(trip.entries, hasLength(1));
    });

    test('forceExpandedTripId overrides a collapsed trip', () {
      final sections = buildDiveListSections(
        dives: [dive('d1', tripId: 't1', tripName: 'Tassie')],
        groupingEnabled: true,
        collapsedTripIds: const {'t1'},
        tripTotals: const {'t1': 1},
        forceExpandedTripId: 't1',
      );

      expect((sections.single as TripSection).collapsed, isFalse);
    });

    test('a trip with no known total falls back to the loaded count', () {
      final sections = buildDiveListSections(
        dives: [dive('d1', tripId: 't1', tripName: 'Tassie')],
        groupingEnabled: true,
        collapsedTripIds: const {},
        tripTotals: const {},
      );

      final trip = sections.single as TripSection;
      expect(trip.totalCount, 1);
      expect(trip.isPartial, isFalse);
    });

    test('an optimistic summary at the head does not blank the header', () {
      // DiveSummary.fromDive takes tripId from dive.tripId but the name and
      // dates only from dive.trip, so the optimistic update paths can produce
      // a summary that knows its trip id and nothing else. Heading a run with
      // one used to blank the whole header until the next database read.
      final optimistic = DiveSummary(
        id: 'd1',
        dateTime: DateTime(2026, 6, 8),
        sortTimestamp: 0,
        tripId: 't1',
      );

      final sections = buildDiveListSections(
        dives: [
          optimistic,
          dive('d2', tripId: 't1', tripName: 'Tassie'),
        ],
        groupingEnabled: true,
        collapsedTripIds: const {},
        tripTotals: const {'t1': 2},
      );

      final trip = sections.single as TripSection;
      expect(trip.tripName, 'Tassie');
      expect(trip.startDate, DateTime(2026, 6, 8));
      expect(trip.endDate, DateTime(2026, 6, 9));
    });

    test('a run of only optimistic summaries still groups', () {
      // Nothing to recover the name from; the group must still form on the
      // trip id rather than throwing or splitting.
      final sections = buildDiveListSections(
        dives: [
          DiveSummary(
            id: 'd1',
            dateTime: DateTime(2026, 6, 8),
            sortTimestamp: 0,
            tripId: 't1',
          ),
        ],
        groupingEnabled: true,
        collapsedTripIds: const {},
        tripTotals: const {'t1': 1},
      );

      final trip = sections.single as TripSection;
      expect(trip.tripId, 't1');
      expect(trip.tripName, '');
    });

    test('a stale total below the loaded count never reads as partial', () {
      final sections = buildDiveListSections(
        dives: [
          dive('d1', tripId: 't1', tripName: 'Tassie'),
          dive('d2', tripId: 't1', tripName: 'Tassie'),
        ],
        groupingEnabled: true,
        collapsedTripIds: const {},
        tripTotals: const {'t1': 1},
      );

      final trip = sections.single as TripSection;
      expect(trip.isPartial, isFalse);
      expect(trip.totalCount, 2);
    });
  });

  group('visibleDivesOf', () {
    test('skips dives inside a collapsed trip', () {
      final sections = buildDiveListSections(
        dives: [
          dive('d1'),
          dive('d2', tripId: 't1', tripName: 'Tassie'),
          dive('d3'),
        ],
        groupingEnabled: true,
        collapsedTripIds: const {'t1'},
        tripTotals: const {'t1': 1},
      );

      expect(visibleDivesOf(sections).map((d) => d.id), ['d1', 'd3']);
    });

    test('keeps every dive when nothing is collapsed', () {
      final sections = buildDiveListSections(
        dives: [
          dive('d1'),
          dive('d2', tripId: 't1', tripName: 'Tassie'),
          dive('d3'),
        ],
        groupingEnabled: true,
        collapsedTripIds: const {},
        tripTotals: const {'t1': 1},
      );

      expect(visibleDivesOf(sections).map((d) => d.id), ['d1', 'd2', 'd3']);
    });
  });
}

/// Covers the retry decision behind the programmatic scroll (#1193). The
/// widget's frame plumbing is not reachable from a settled test tree, so the
/// judgement it depends on lives here as a pure function.
void _retryDecisionTests() {
  DiveSummary dive(String id, {String? tripId}) => DiveSummary(
    id: id,
    dateTime: DateTime(2026, 6, 8),
    sortTimestamp: 0,
    tripId: tripId,
    tripName: tripId == null ? null : 'Trip',
  );

  group('shouldRetryScrollAfterExpanding', () {
    final loaded = [dive('d1'), dive('d2', tripId: 't1'), dive('d3')];

    test('retries a loaded dive folded inside a collapsed trip', () {
      expect(
        shouldRetryScrollAfterExpanding(
          targetId: 'd2',
          loadedDives: loaded,
          visibleDives: [dive('d1'), dive('d3')],
          alreadyRetriedFor: null,
        ),
        isTrue,
      );
    });

    test('does not retry a dive that is already visible', () {
      expect(
        shouldRetryScrollAfterExpanding(
          targetId: 'd2',
          loadedDives: loaded,
          visibleDives: loaded,
          alreadyRetriedFor: null,
        ),
        isFalse,
      );
    });

    test('does not retry a dive that is not loaded at all', () {
      // Opening a trip cannot conjure a dive the page has not fetched.
      expect(
        shouldRetryScrollAfterExpanding(
          targetId: 'd99',
          loadedDives: loaded,
          visibleDives: const [],
          alreadyRetriedFor: null,
        ),
        isFalse,
      );
    });

    test('does not retry a loose dive, which no trip can reveal', () {
      expect(
        shouldRetryScrollAfterExpanding(
          targetId: 'd1',
          loadedDives: loaded,
          visibleDives: const [],
          alreadyRetriedFor: null,
        ),
        isFalse,
      );
    });

    test('spends at most one retry per target', () {
      expect(
        shouldRetryScrollAfterExpanding(
          targetId: 'd2',
          loadedDives: loaded,
          visibleDives: const [],
          alreadyRetriedFor: 'd2',
        ),
        isFalse,
        reason: 'an unbounded retry would ping-pong build to frame forever',
      );
    });

    test('a retry spent on another dive does not block this one', () {
      expect(
        shouldRetryScrollAfterExpanding(
          targetId: 'd2',
          loadedDives: loaded,
          visibleDives: const [],
          alreadyRetriedFor: 'd7',
        ),
        isTrue,
      );
    });
  });
}
