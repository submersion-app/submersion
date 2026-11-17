import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/features/dive_log/presentation/providers/open_dive_sitting_provider.dart';
import 'package:submersion/features/dive_log/presentation/widgets/dive_detail/dive_detail_embedded_header.dart';

import '../../../../helpers/test_database.dart';
import 'dive_detail_page_unlock_harness.dart';

/// The dive list's pane unlocks as the full page does (issue #4527, plan 7):
/// its own header carries the lock, then Cancel and Save, and nothing moves.
void main() {
  setUp(setUpTestDatabase);
  tearDown(tearDownTestDatabase);

  const pane = Size(1200, 900);

  Finder header() => find.byType(DiveDetailEmbeddedHeader);

  testWidgets('the pane shows the lock and History, and favourite as state '
      'only', (tester) async {
    await pumpPage(
      tester,
      embedded: true,
      size: pane,
      stored: dive.copyWith(isFavorite: true),
    );

    expect(find.byTooltip('Unlock to edit'), findsOneWidget);
    expect(find.byTooltip('History'), findsOneWidget);
    expect(find.byTooltip('Remove from favorites'), findsNothing);
    expect(find.byIcon(Icons.favorite), findsOneWidget);
  });

  testWidgets('unlocking the pane: Cancel and Save in its header, the same '
      'height', (tester) async {
    await pumpPage(tester, embedded: true, size: pane);
    final locked = tester.getSize(header()).height;

    await unlock(tester);

    expect(action(tester, 'Cancel'), isNotNull);
    expect(action(tester, 'Save').onPressed, isNull);
    expect(tester.getSize(header()).height, locked);
    // The locked row keeps its place beneath, out of reach.
    expect(find.byTooltip('Unlock to edit').hitTestable(), findsNothing);
  });

  testWidgets('editing Notes in the pane and saving writes one sitting', (
    tester,
  ) async {
    final page = await pumpPage(tester, embedded: true, size: pane);
    await unlock(tester);
    await openNotes(tester);
    await tester.enterText(find.byType(TextField).first, 'Choppy');
    await settle(tester);

    await tester.tap(find.text('Save'));
    await settle(tester);

    expect(page.save.calls, hasLength(1));
    expect(page.save.calls.single.merged.notes, 'Choppy');
    expect(find.byTooltip('Unlock to edit'), findsOneWidget);
  });

  testWidgets('the pane menu lists the operations as the full page does', (
    tester,
  ) async {
    await pumpPage(tester, embedded: true, size: pane);

    await tester.tap(
      find.byWidgetPredicate((w) => w is PopupMenuButton<String>).first,
    );
    await settle(tester);

    expect(find.text('Unlock to use these'), findsOneWidget);
    expect(find.text('Open Full Page'), findsOneWidget);
    expect(find.text('History'), findsNothing);
  });

  // One sitting per dive: the full page could be unlocked too while the
  // pane holds one, so it waits until the pane is locked again.
  group('Open Full Page while the pane is unlocked', () {
    Finder openItem() => find.ancestor(
      of: find.text('Open Full Page'),
      matching: find.byWidgetPredicate((w) => w is PopupMenuItem<String>),
    );

    Future<void> openMenu(WidgetTester tester) async {
      await tester.tap(
        find.byWidgetPredicate((w) => w is PopupMenuButton<String>).last,
      );
      await settle(tester);
    }

    testWidgets('locked, it opens the full page', (tester) async {
      final page = await pumpPage(tester, embedded: true, size: pane);
      await openMenu(tester);

      expect(tester.widget<PopupMenuItem<String>>(openItem()).enabled, isTrue);
      await tester.tap(find.text('Open Full Page'));
      await settle(tester);
      expect(location(page.router), '/dives/${dive.id}');
    });

    testWidgets('unlocked with nothing to save, it is disabled and says why', (
      tester,
    ) async {
      final page = await pumpPage(tester, embedded: true, size: pane);
      await unlock(tester);
      await openMenu(tester);

      expect(tester.widget<PopupMenuItem<String>>(openItem()).enabled, isFalse);
      expect(
        find.descendant(
          of: openItem(),
          matching: find.text('Save or cancel your changes first'),
        ),
        findsOneWidget,
      );
      await tester.tap(find.text('Open Full Page'), warnIfMissed: false);
      await settle(tester);
      expect(location(page.router), '/home/dive');
    });

    testWidgets('unlocked with a change, it is disabled', (tester) async {
      await pumpPage(tester, embedded: true, size: pane);
      await unlock(tester);
      await openNotes(tester);
      await tester.enterText(find.byType(TextField).first, 'Choppy');
      await settle(tester);
      await openMenu(tester);

      expect(tester.widget<PopupMenuItem<String>>(openItem()).enabled, isFalse);
    });
  });

  testWidgets('the pane tells a drop which sitting is open', (tester) async {
    await pumpPage(tester, embedded: true, size: pane);
    OpenDiveSitting? open() => ProviderScope.containerOf(
      tester.element(header()),
    ).read(openDiveSittingProvider);
    expect(open(), isNull);

    await unlock(tester);
    await tester.pump();

    expect(open()?.diveId, dive.id);
  });

  testWidgets('the pane\'s banners follow the lock', (tester) async {
    await pumpPage(
      tester,
      embedded: true,
      size: pane,
      stored: dive.copyWith(isPlanned: true),
    );
    TextButton mark() => tester.widget<TextButton>(
      find.widgetWithText(TextButton, 'Mark as logged'),
    );
    expect(mark().onPressed, isNull);

    await unlock(tester);
    expect(mark().onPressed, isNotNull);
  });
}
