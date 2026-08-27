import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:submersion/features/dive_log/domain/entities/dive_summary.dart';
import 'package:submersion/features/dive_log/presentation/providers/dive_providers.dart';
import 'package:submersion/features/pre_dive/presentation/providers/pre_dive_providers.dart';
import 'package:submersion/features/pre_dive/presentation/widgets/link_dive_picker.dart';

import '../../../../helpers/test_app.dart';

/// The picker that restores manual checklist-to-dive linking (issue #1066).
/// Recent dives are offered without typing; the shared dive search takes over
/// once the diver types, so an older dive stays reachable.
void main() {
  DiveSummary summary(String id, {int? number, String? site, DateTime? when}) {
    final at = when ?? DateTime(2026, 8, 14, 9, 30);
    return DiveSummary(
      id: id,
      diveNumber: number,
      dateTime: at,
      siteName: site,
      sortTimestamp: at.millisecondsSinceEpoch,
    );
  }

  /// Opens the picker from a host button and records what it returned, so a
  /// test can assert on the value handed back to the caller rather than on
  /// picker internals.
  Future<List<String?>> pumpPicker(
    WidgetTester tester, {
    required List<DiveSummary> recent,
    Map<String, List<DiveSummary>> searchResults = const {},
    Set<String> alreadyLinked = const {},
  }) async {
    final returned = <String?>[];

    await tester.pumpWidget(
      testApp(
        locale: const Locale('en'),
        overrides: [
          preDiveLinkCandidateDivesProvider.overrideWith((ref) async => recent),
          preDiveLinkedDiveIdsProvider.overrideWith(
            (ref) async => alreadyLinked,
          ),
          diveSearchProvider.overrideWith(
            (ref, query) async => searchResults[query] ?? const <DiveSummary>[],
          ),
        ],
        child: Builder(
          builder: (context) => ElevatedButton(
            onPressed: () async =>
                returned.add(await showLinkDivePicker(context)),
            child: const Text('Open'),
          ),
        ),
      ),
    );
    await tester.tap(find.text('Open'));
    await tester.pumpAndSettle();

    return returned;
  }

  testWidgets('offers recent dives before anything is typed', (tester) async {
    await pumpPicker(
      tester,
      recent: [
        summary('d1', number: 412, site: 'Blue Hole'),
        summary(
          'd2',
          number: 411,
          site: "Devil's Den",
          when: DateTime(2026, 8, 12, 8, 0),
        ),
      ],
    );

    expect(find.text('Link to dive'), findsOneWidget);
    expect(find.textContaining('#412'), findsOneWidget);
    expect(find.textContaining('Blue Hole'), findsOneWidget);
    expect(find.textContaining("Devil's Den"), findsOneWidget);
  });

  testWidgets('typing replaces the recent list with search results', (
    tester,
  ) async {
    await pumpPicker(
      tester,
      recent: [summary('d1', number: 412, site: 'Blue Hole')],
      searchResults: {
        'ginnie': [
          summary(
            'd9',
            number: 300,
            site: 'Ginnie Springs',
            when: DateTime(2024, 5, 1, 11, 0),
          ),
        ],
      },
    );

    await tester.enterText(find.byType(TextField), 'ginnie');
    // One plain frame first: the debounce timer is armed in didUpdateWidget,
    // so a pump(duration) here would advance the clock before the timer even
    // exists and it would never fire.
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));
    await tester.pumpAndSettle();

    expect(find.textContaining('Ginnie Springs'), findsOneWidget);
    expect(find.textContaining('Blue Hole'), findsNothing);
  });

  testWidgets('choosing a dive closes the picker and returns its id', (
    tester,
  ) async {
    final returned = await pumpPicker(
      tester,
      recent: [summary('dive-42', number: 42, site: 'Blue Hole')],
    );

    await tester.tap(find.textContaining('Blue Hole'));
    await tester.pumpAndSettle();

    expect(returned, ['dive-42']);
  });

  testWidgets('an empty dive log says so instead of showing a bare list', (
    tester,
  ) async {
    await pumpPicker(tester, recent: []);

    expect(find.text('No dives to link to'), findsOneWidget);
  });

  testWidgets('a search that matches nothing reports it', (tester) async {
    await pumpPicker(
      tester,
      recent: [summary('d1', number: 412, site: 'Blue Hole')],
      searchResults: const {},
    );

    await tester.enterText(find.byType(TextField), 'nowhere');
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));
    await tester.pumpAndSettle();

    expect(find.text('No dives match "nowhere"'), findsOneWidget);
  });

  testWidgets('a dive that already has a checklist run is not offered', (
    tester,
  ) async {
    // ChecklistDiveLinker holds one run per dive; linking a second by hand
    // would leave the older run invisible from the dive side.
    await pumpPicker(
      tester,
      recent: [
        summary('d1', number: 412, site: 'Blue Hole'),
        summary('d2', number: 411, site: "Devil's Den"),
      ],
      alreadyLinked: {'d1'},
    );

    expect(find.textContaining('Blue Hole'), findsNothing);
    expect(find.textContaining("Devil's Den"), findsOneWidget);
  });

  testWidgets('search results drop dives that already have a run', (
    tester,
  ) async {
    await pumpPicker(
      tester,
      recent: const [],
      alreadyLinked: {'d9'},
      searchResults: {
        'ginnie': [
          summary('d9', number: 300, site: 'Ginnie Springs'),
          summary('d10', number: 301, site: 'Ginnie Ballroom'),
        ],
      },
    );

    await tester.enterText(find.byType(TextField), 'ginnie');
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));
    await tester.pumpAndSettle();

    expect(find.textContaining('Ginnie Springs'), findsNothing);
    expect(find.textContaining('Ginnie Ballroom'), findsOneWidget);
  });

  testWidgets(
    'a search whose every hit is taken reports it, not a blank list',
    (tester) async {
      await pumpPicker(
        tester,
        recent: const [],
        alreadyLinked: {'d9'},
        searchResults: {
          'ginnie': [summary('d9', number: 300, site: 'Ginnie Springs')],
        },
      );

      await tester.enterText(find.byType(TextField), 'ginnie');
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 400));
      await tester.pumpAndSettle();

      expect(find.text('No dives match "ginnie"'), findsOneWidget);
    },
  );

  testWidgets('dismissing without choosing returns null', (tester) async {
    final returned = await pumpPicker(
      tester,
      recent: [summary('d1', number: 412, site: 'Blue Hole')],
    );

    await tester.tap(find.text('Cancel'));
    await tester.pumpAndSettle();

    expect(returned, [null]);
  });
}
