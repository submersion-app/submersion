import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/legacy.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/features/dive_log/domain/models/dive_filter_state.dart';
import 'package:submersion/features/dive_log/presentation/widgets/dive_filter_sheet.dart';
import 'package:submersion/l10n/arb/app_localizations.dart';

import '../../../../helpers/mock_providers.dart';
import '../../../../helpers/test_database.dart';

final _testFilter = StateProvider<DiveFilterState>(
  (ref) => const DiveFilterState(),
);

/// Layout contract for the filter sheet (#989).
///
/// The sheet is far taller than the 70% viewport it opens into, so its chrome
/// -- title, close button and the Clear All / Apply actions -- has to live
/// outside the scrolling field list. Otherwise the primary action sits about a
/// thousand pixels below the fold with no scrollbar hinting at it, which on
/// desktop reads as a sheet clipped by the bottom of the window.
void main() {
  setUp(() async {
    await setUpTestDatabase();
  });

  tearDown(() async {
    await tearDownTestDatabase();
  });

  Future<void> openSheet(WidgetTester tester) async {
    final overrides = await getBaseOverrides();

    await tester.pumpWidget(
      ProviderScope(
        overrides: overrides.cast(),
        child: MaterialApp(
          // Pinned: the assertions below match English strings. flutter_test
          // forwards the HOST machine's locale list rather than a fixed en_US,
          // and the app ships 11 locales, so an unpinned MaterialApp renders a
          // translated sheet on a non-English dev machine and every
          // find.text() here misses.
          locale: const Locale('en'),
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: Scaffold(
            body: Consumer(
              builder: (context, ref, _) {
                return Center(
                  child: ElevatedButton(
                    onPressed: () => showModalBottomSheet<void>(
                      context: context,
                      isScrollControlled: true,
                      builder: (_) => DiveFilterSheet(
                        ref: ref,
                        filterProvider: _testFilter,
                      ),
                    ),
                    child: const Text('Open filter'),
                  ),
                );
              },
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.text('Open filter'));
    await tester.pumpAndSettle();
  }

  testWidgets('Apply Filters is visible without scrolling the field list', (
    tester,
  ) async {
    await openSheet(tester);

    // No scrollUntilVisible, no ensureVisible: the action row is pinned, so it
    // is in the tree and hit-testable the moment the sheet opens.
    expect(find.text('Apply Filters'), findsOneWidget);
    expect(find.text('Clear All'), findsOneWidget);

    await tester.tap(find.text('Apply Filters'));
    await tester.pumpAndSettle();

    expect(find.text('Apply Filters'), findsNothing, reason: 'sheet closed');
  });

  testWidgets('the pinned action row sits inside the window', (tester) async {
    await openSheet(tester);

    final apply = tester.getRect(find.text('Apply Filters'));
    final windowHeight =
        tester.view.physicalSize.height / tester.view.devicePixelRatio;

    expect(apply.bottom, lessThanOrEqualTo(windowHeight));
  });

  testWidgets('the title stays pinned while the field list scrolls', (
    tester,
  ) async {
    await openSheet(tester);

    // Measured against the grip, not the window: the first drag on a list that
    // sits at offset zero grows the sheet rather than scrolling it, so the
    // whole chrome legitimately moves up together.
    double titleOffsetInSheet() =>
        tester.getTopLeft(find.text('Filter Dives')).dy -
        tester.getTopLeft(find.byKey(DiveFilterSheet.gripKey)).dy;

    final offsetBefore = titleOffsetInSheet();
    expect(find.text('Date Range'), findsOneWidget);

    // Two drags: the first expands the sheet to its maximum, the second
    // actually scrolls the field list.
    for (var i = 0; i < 2; i++) {
      await tester.drag(
        find.byType(Scrollable).first,
        const Offset(0, -400),
        warnIfMissed: false,
      );
      await tester.pumpAndSettle();
    }

    expect(find.text('Date Range'), findsNothing, reason: 'the list scrolled');
    expect(find.text('Filter Dives'), findsOneWidget);
    expect(titleOffsetInSheet(), offsetBefore);
    expect(find.text('Apply Filters'), findsOneWidget);
  });

  testWidgets('dragging the grip upward grows the sheet', (tester) async {
    await openSheet(tester);

    final grip = find.byKey(DiveFilterSheet.gripKey);
    expect(grip, findsOneWidget);

    final topBefore = tester.getTopLeft(grip).dy;

    await tester.drag(grip, const Offset(0, -150));
    await tester.pumpAndSettle();

    expect(
      tester.getTopLeft(grip).dy,
      lessThan(topBefore),
      reason: 'the sheet should grow when the grip is dragged upward',
    );
  });

  testWidgets('dragging the grip downward shrinks the sheet', (tester) async {
    await openSheet(tester);

    final grip = find.byKey(DiveFilterSheet.gripKey);
    final topBefore = tester.getTopLeft(grip).dy;

    await tester.drag(grip, const Offset(0, 100));
    await tester.pumpAndSettle();

    expect(tester.getTopLeft(grip).dy, greaterThan(topBefore));
  });
}
