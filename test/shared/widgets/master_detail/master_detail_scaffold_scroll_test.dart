import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:submersion/l10n/arb/app_localizations.dart';
import 'package:submersion/shared/widgets/master_detail/master_detail_scaffold.dart';

/// Builds a [MasterDetailScaffold] inside a router at desktop width (>=800) so
/// the split layout renders. The master pane exposes two buttons that call
/// [onItemSelected] to drive selection changes via query params.
///
/// [detailHeight] returns the content height for a given item id, so tests can
/// make item 2 shorter than item 1 to exercise clamping. When [tagKey] is
/// false the detail scroll view carries no [PageStorageKey] (opt-out case).
Widget _app({
  required double Function(String id) detailHeight,
  bool tagKey = true,
}) {
  final router = GoRouter(
    initialLocation: '/test?selected=1',
    routes: [
      GoRoute(
        path: '/test',
        builder: (context, state) => MediaQuery(
          data: const MediaQueryData(size: Size(1200, 800)),
          child: MasterDetailScaffold(
            sectionId: 'test',
            masterBuilder: (context, onSelect, selectedId) => Column(
              children: [
                TextButton(
                  onPressed: () => onSelect('1'),
                  child: const Text('select-1'),
                ),
                TextButton(
                  onPressed: () => onSelect('2'),
                  child: const Text('select-2'),
                ),
              ],
            ),
            detailBuilder: (_, id) => SingleChildScrollView(
              key: tagKey ? const PageStorageKey('testDetailScroll') : null,
              child: SizedBox(
                height: detailHeight(id),
                child: Text('Detail $id'),
              ),
            ),
            summaryBuilder: (_) => const Text('Summary'),
          ),
        ),
      ),
    ],
  );

  return ProviderScope(
    child: MaterialApp.router(
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      routerConfig: router,
    ),
  );
}

/// The (single, post-settle) detail scroll view's scroll state.
ScrollableState _detailScrollable(WidgetTester tester) {
  return tester.state<ScrollableState>(
    find.descendant(
      of: find.byType(SingleChildScrollView),
      matching: find.byType(Scrollable),
    ),
  );
}

void main() {
  group('MasterDetailScaffold detail scroll retention', () {
    testWidgets('retains offset when switching to another item', (
      tester,
    ) async {
      await tester.pumpWidget(_app(detailHeight: (_) => 3000));
      await tester.pumpAndSettle();

      _detailScrollable(tester).position.jumpTo(800);
      await tester.pump();
      expect(_detailScrollable(tester).position.pixels, 800);

      await tester.tap(find.text('select-2'));
      await tester.pumpAndSettle();

      expect(find.text('Detail 2'), findsOneWidget);
      expect(_detailScrollable(tester).position.pixels, 800);
    });

    testWidgets('clamps retained offset to the new item extent', (
      tester,
    ) async {
      // Item 1 is tall (scrollable); item 2 is only slightly taller than the
      // ~800px viewport, so its maxScrollExtent is small and 800 must clamp.
      await tester.pumpWidget(
        _app(detailHeight: (id) => id == '2' ? 900 : 3000),
      );
      await tester.pumpAndSettle();

      _detailScrollable(tester).position.jumpTo(800);
      await tester.pump();

      await tester.tap(find.text('select-2'));
      await tester.pumpAndSettle();

      final position = _detailScrollable(tester).position;
      expect(position.pixels, position.maxScrollExtent);
      expect(position.pixels, lessThan(800));
    });

    testWidgets('without a PageStorageKey the offset resets to top', (
      tester,
    ) async {
      await tester.pumpWidget(_app(detailHeight: (_) => 3000, tagKey: false));
      await tester.pumpAndSettle();

      _detailScrollable(tester).position.jumpTo(800);
      await tester.pump();

      await tester.tap(find.text('select-2'));
      await tester.pumpAndSettle();

      expect(_detailScrollable(tester).position.pixels, 0);
    });
  });
}
