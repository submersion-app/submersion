import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/core/providers/provider.dart';
import 'package:submersion/core/query/domain/query_node.dart';
import 'package:submersion/core/query/names/name_index.dart';
import 'package:submersion/features/buddies/domain/entities/buddy.dart';
import 'package:submersion/features/buddies/presentation/providers/buddy_providers.dart';
import 'package:submersion/features/dive_log/domain/entities/dive_summary.dart';
import 'package:submersion/features/dive_log/presentation/providers/dive_providers.dart';
import 'package:submersion/features/dive_log/presentation/providers/dive_search_providers.dart';
import 'package:submersion/features/dive_log/presentation/widgets/search/dive_search_header.dart';
import 'package:submersion/features/dive_log/query/dive_number_query.dart';
import 'package:submersion/features/divers/presentation/providers/diver_providers.dart';
import 'package:submersion/features/explore/presentation/providers/recent_query_providers.dart';
import 'package:submersion/features/query/presentation/providers/query_name_index_provider.dart';
import 'package:submersion/features/query/presentation/providers/saved_query_providers.dart';

import '../../../../../helpers/mock_providers.dart';
import '../../../../../helpers/test_app.dart';

DiveSummary _dive(String id, {int? number, String? site}) => DiveSummary(
  id: id,
  diveNumber: number,
  dateTime: DateTime(2026, 3, 1),
  sortTimestamp: 0,
  siteName: site,
);

final _d500 = _dive('d500', number: 500, site: 'Blue Hole');
final _d50 = _dive('d50', number: 50, site: 'Salt Pier');
final _swim = _dive('swim', number: 487, site: 'Hilma Hooker');

/// Answers as the real provider does: the numbered dive first for a bare
/// number, then the text matches.
Future<List<DiveSummary>> _rowsFor(QueryNode q) async =>
    switch (bareDiveNumber(q)) {
      500 => [_d500, _swim],
      50 => [_d50],
      _ => [_swim],
    };

void main() {
  Future<void> pumpHeader(
    WidgetTester tester, {
    ValueChanged<DiveSummary>? onOpenDive,
    ValueChanged<DiveSummary>? onJumpToDive,
    void Function(String text)? onRecord,
    Future<List<DiveSummary>> Function(QueryNode q) rowsFor = _rowsFor,
  }) async {
    final base = await getBaseOverrides();
    await tester.pumpWidget(
      testApp(
        locale: const Locale('en'),
        overrides: [
          ...base,
          diveSearchBarOpenProvider.overrideWith((ref) => true),
          queryNameIndexProvider.overrideWith((ref) async => NameIndex.empty),
          diveJumpResultsProvider.overrideWith((ref, q) => rowsFor(q)),
          savedQueryLoadsProvider('dives').overrideWith((ref) async => []),
          recentQueriesProvider.overrideWith((ref) async => []),
          allBuddiesProvider.overrideWith((ref) async => const <Buddy>[]),
          validatedCurrentDiverIdProvider.overrideWith((ref) async => 'ana'),
          recentTypedRecorderProvider.overrideWithValue(
            (text, node, locale, diverId) async => onRecord?.call(text),
          ),
        ],
        child: DiveSearchHeader(
          onOpenDive: onOpenDive ?? (_) {},
          onJumpToDive: onJumpToDive,
        ),
      ),
    );
    await tester.pumpAndSettle();
  }

  Future<void> type(WidgetTester tester, String text) async {
    await tester.enterText(find.byKey(kDiveSearchFieldKey), text);
    // The jump list searches once typing rests, and its provider
    // resolves on the next frame.
    await tester.pump(kDiveSearchDebounce);
    await tester.pump();
  }

  // The header, not the field: a jump closes the row, field and all.
  ProviderContainer containerOf(WidgetTester tester) =>
      ProviderScope.containerOf(tester.element(find.byType(DiveSearchHeader)));

  Future<void> pressEnter(WidgetTester tester) async {
    await tester.testTextInput.receiveAction(TextInputAction.search);
    await tester.pumpAndSettle();
  }

  testWidgets('the numbered dive leads the jump rows, labelled by number', (
    tester,
  ) async {
    await pumpHeader(tester);
    await type(tester, '500');
    final number = find.byKey(const ValueKey('dive-jump-d500'));
    final text = find.byKey(const ValueKey('dive-jump-swim'));
    expect(number, findsOneWidget);
    expect(tester.getTopLeft(number).dy, lessThan(tester.getTopLeft(text).dy));
    expect(
      find.descendant(of: number, matching: find.text('#500 · Blue Hole')),
      findsOneWidget,
    );
    // A text match keeps its plain title, even though it has a number.
    expect(
      find.descendant(of: text, matching: find.text('Hilma Hooker')),
      findsOneWidget,
    );
  });

  testWidgets('tapping the numbered row opens that dive', (tester) async {
    DiveSummary? opened;
    await pumpHeader(tester, onOpenDive: (d) => opened = d);
    await type(tester, '#500');
    await tester.tap(find.byKey(const ValueKey('dive-jump-d500')));
    await tester.pump();
    expect(opened?.id, 'd500');
  });

  testWidgets('Enter opens the numbered dive and still records the search', (
    tester,
  ) async {
    DiveSummary? opened;
    final recorded = <String>[];
    await pumpHeader(
      tester,
      onOpenDive: (d) => opened = d,
      onRecord: recorded.add,
    );
    await type(tester, '500');
    await pressEnter(tester);
    expect(opened?.id, 'd500');
    expect(recorded, hasLength(1));
    expect(find.byKey(const ValueKey('dive-jump-d500')), findsNothing);
  });

  testWidgets('Enter inside the debounce opens the number typed, not the '
      'one still shown', (tester) async {
    DiveSummary? opened;
    await pumpHeader(tester, onOpenDive: (d) => opened = d);
    await type(tester, '50');
    expect(find.byKey(const ValueKey('dive-jump-d50')), findsOneWidget);
    await tester.enterText(find.byKey(kDiveSearchFieldKey), '500');
    await pressEnter(tester);
    expect(opened?.id, 'd500');
  });

  testWidgets('Enter on plain text opens nothing', (tester) async {
    DiveSummary? opened;
    await pumpHeader(tester, onOpenDive: (d) => opened = d);
    await type(tester, 'manta');
    expect(find.byKey(const ValueKey('dive-jump-swim')), findsOneWidget);
    await pressEnter(tester);
    expect(opened, isNull);
  });

  testWidgets('Enter on a number no dive has opens nothing', (tester) async {
    DiveSummary? opened;
    await pumpHeader(tester, onOpenDive: (d) => opened = d);
    await type(tester, '9999');
    expect(find.byKey(const ValueKey('dive-jump-swim')), findsOneWidget);
    await pressEnter(tester);
    expect(opened, isNull);
  });

  testWidgets('Enter opens nothing once the text changed during the lookup', (
    tester,
  ) async {
    final pending = Completer<List<DiveSummary>>();
    var lookups = 0;
    DiveSummary? opened;
    await pumpHeader(
      tester,
      onOpenDive: (d) => opened = d,
      rowsFor: (q) {
        if (bareDiveNumber(q) != 500) return _rowsFor(q);
        // The first lookup answers the rows; every later one waits on
        // [pending], so Enter's lookup is still loading when the text changes.
        return ++lookups == 1 ? _rowsFor(q) : pending.future;
      },
    );
    await type(tester, '500');
    // Drop the cached answer so the next lookup, Enter's, is a slow one.
    final element = tester.element(find.byKey(kDiveSearchFieldKey));
    ProviderScope.containerOf(
      element,
    ).invalidate(diveJumpResultsProvider(TextNode(['500'])));
    await tester.testTextInput.receiveAction(TextInputAction.search);
    await tester.pump();
    await tester.enterText(find.byKey(kDiveSearchFieldKey), 'manta');
    await tester.pump();
    pending.complete([_d500]);
    await tester.pumpAndSettle();
    expect(
      lookups,
      greaterThan(1),
      reason: 'the lookup re-ran after the invalidate',
    );
    expect(opened, isNull);
  });

  testWidgets('Enter opens nothing when the jump query fails', (tester) async {
    DiveSummary? opened;
    await pumpHeader(
      tester,
      onOpenDive: (d) => opened = d,
      rowsFor: (q) async => throw StateError('jump failed'),
    );
    await type(tester, '500');
    await pressEnter(tester);
    expect(opened, isNull);
  });

  testWidgets('rows kept while the next query loads keep their labels', (
    tester,
  ) async {
    final pending = Completer<List<DiveSummary>>();
    await pumpHeader(
      tester,
      rowsFor: (q) => bareDiveNumber(q) == 50 ? pending.future : _rowsFor(q),
    );
    await type(tester, '500');
    await type(tester, '50');
    // The 500 rows stay until 50 answers, still titled for 500.
    final kept = find.byKey(const ValueKey('dive-jump-d500'));
    expect(
      find.descendant(of: kept, matching: find.text('#500 · Blue Hole')),
      findsOneWidget,
    );
    pending.complete([_d50]);
    // The provider settles, then the rows rebuild.
    await tester.pump();
    await tester.pump();
    expect(
      find.descendant(
        of: find.byKey(const ValueKey('dive-jump-d50')),
        matching: find.text('#50 · Salt Pier'),
      ),
      findsOneWidget,
    );
  });

  group('a jump to a number clears the search to land on it (#3744)', () {
    testWidgets('Enter jumps to the numbered dive and clears the search', (
      tester,
    ) async {
      DiveSummary? opened;
      DiveSummary? jumped;
      await pumpHeader(
        tester,
        onOpenDive: (d) => opened = d,
        onJumpToDive: (d) => jumped = d,
      );
      await type(tester, '500');
      expect(containerOf(tester).read(diveFilterProvider).query, isNotNull);
      await pressEnter(tester);
      expect(jumped?.id, 'd500');
      expect(opened, isNull);
      // The whole list comes back, so the dive can be shown in it.
      expect(
        containerOf(tester).read(diveFilterProvider).hasActiveFilters,
        isFalse,
      );
    });

    testWidgets('tapping the numbered row jumps and clears the search', (
      tester,
    ) async {
      DiveSummary? opened;
      DiveSummary? jumped;
      await pumpHeader(
        tester,
        onOpenDive: (d) => opened = d,
        onJumpToDive: (d) => jumped = d,
      );
      await type(tester, '#500');
      await tester.tap(find.byKey(const ValueKey('dive-jump-d500')));
      await tester.pumpAndSettle();
      expect(jumped?.id, 'd500');
      expect(opened, isNull);
      expect(
        containerOf(tester).read(diveFilterProvider).hasActiveFilters,
        isFalse,
      );
    });

    testWidgets('tapping a text match only opens it, keeping the search', (
      tester,
    ) async {
      DiveSummary? opened;
      DiveSummary? jumped;
      await pumpHeader(
        tester,
        onOpenDive: (d) => opened = d,
        onJumpToDive: (d) => jumped = d,
      );
      await type(tester, '500');
      await tester.tap(find.byKey(const ValueKey('dive-jump-swim')));
      await tester.pumpAndSettle();
      expect(opened?.id, 'swim');
      expect(jumped, isNull);
      expect(containerOf(tester).read(diveFilterProvider).query, isNotNull);
    });
  });
}
