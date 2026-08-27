import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:submersion/l10n/arb/app_localizations.dart';
import 'package:submersion/shared/widgets/master_detail/detail_scroll_retainer.dart';
import 'package:submersion/shared/widgets/master_detail/master_detail_scaffold.dart';

/// A detail whose content starts short and grows to [finalHeight] one microtask
/// after mount — mimicking the real detail pages, whose sections (profile
/// chart, photos, marine life) fill in height asynchronously. Its scroll view
/// opts into retention via [DetailScrollController.maybeOf].
class _GrowingDetail extends StatefulWidget {
  const _GrowingDetail(this.id, this.finalHeight);
  final String id;
  final double finalHeight;
  @override
  State<_GrowingDetail> createState() => _GrowingDetailState();
}

class _GrowingDetailState extends State<_GrowingDetail> {
  double _height = 150;
  @override
  void initState() {
    super.initState();
    Future.microtask(() {
      if (mounted) setState(() => _height = widget.finalHeight);
    });
  }

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      controller: DetailScrollController.maybeOf(context),
      child: SizedBox(height: _height, child: Text('Detail ${widget.id}')),
    );
  }
}

/// Builds a [MasterDetailScaffold] at desktop width with five selectable items.
Widget _app({required double Function(String id) finalHeight}) {
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
                for (final id in ['1', '2', '3', '4', '5'])
                  TextButton(
                    onPressed: () => onSelect(id),
                    child: Text('select-$id'),
                  ),
              ],
            ),
            detailBuilder: (_, id) => _GrowingDetail(id, finalHeight(id)),
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
    testWidgets('retains offset across many selections despite content growing', (
      tester,
    ) async {
      await tester.pumpWidget(_app(finalHeight: (_) => 3000));
      await tester.pumpAndSettle();

      // A user scroll on item 1 (fires notifications -> captured into the pane).
      _detailScrollable(tester).position.jumpTo(800);
      await tester.pump();
      expect(_detailScrollable(tester).position.pixels, 800);

      // Switching through several items must not degrade the offset — this is
      // the regression: the old PageStorage approach ratcheted to 0 here
      // because restore clamped against still-loading content and saved that.
      for (final id in ['2', '3', '4', '5']) {
        await tester.tap(find.text('select-$id'));
        await tester.pumpAndSettle();
        expect(find.text('Detail $id'), findsOneWidget);
        expect(
          _detailScrollable(tester).position.pixels,
          800,
          reason: 'offset lost after selecting item $id',
        );
      }
    });

    testWidgets('clamps retained offset to a shorter item extent', (
      tester,
    ) async {
      // Item 2 is only slightly taller than the ~800px viewport.
      await tester.pumpWidget(
        _app(finalHeight: (id) => id == '2' ? 900 : 3000),
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

    testWidgets('a detail that does not opt in starts at the top', (
      tester,
    ) async {
      // Detail with no DetailScrollController wiring: no retention.
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
                  child: SizedBox(height: 3000, child: Text('Detail $id')),
                ),
                summaryBuilder: (_) => const Text('Summary'),
              ),
            ),
          ),
        ],
      );
      await tester.pumpWidget(
        ProviderScope(
          child: MaterialApp.router(
            localizationsDelegates: AppLocalizations.localizationsDelegates,
            supportedLocales: AppLocalizations.supportedLocales,
            routerConfig: router,
          ),
        ),
      );
      await tester.pumpAndSettle();

      _detailScrollable(tester).position.jumpTo(800);
      await tester.pump();

      await tester.tap(find.text('select-2'));
      await tester.pumpAndSettle();

      expect(_detailScrollable(tester).position.pixels, 0);
    });
  });
}
