import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/core/providers/provider.dart';
import 'package:submersion/features/dashboard/presentation/home_panels.dart';
import 'package:submersion/features/dashboard/presentation/widgets/home_charts.dart';
import 'package:submersion/features/dashboard/presentation/widgets/home_panel.dart';
import 'package:submersion/l10n/arb/app_localizations.dart';

Future<void> _pump(
  WidgetTester tester,
  Widget child, {
  double width = 400,
  double height = 180,
  double textScale = 1,
}) => tester.pumpWidget(
  MaterialApp(
    localizationsDelegates: AppLocalizations.localizationsDelegates,
    supportedLocales: AppLocalizations.supportedLocales,
    home: MediaQuery(
      data: MediaQueryData(textScaler: TextScaler.linear(textScale)),
      child: Scaffold(
        body: Align(
          alignment: Alignment.topLeft,
          child: SizedBox(width: width, height: height, child: child),
        ),
      ),
    ),
  ),
);

void main() {
  group('HomePanel', () {
    testWidgets('reads as its title and headline value', (tester) async {
      final handle = tester.ensureSemantics();
      await _pump(
        tester,
        HomePanel(
          title: 'Dives',
          semanticsValue: '412 dives',
          onTap: () {},
          child: const Text('412'),
        ),
      );
      expect(find.bySemanticsLabel(RegExp('Dives, 412 dives')), findsOneWidget);
      handle.dispose();
    });

    // No outline: the fill alone sets a panel off the page, one step of the
    // theme's tonal surfaces from it, so a page of panels is not a wall of
    // boxes.
    testWidgets('is a filled shape with no border', (tester) async {
      await _pump(
        tester,
        const HomePanel(title: 'Dives', semanticsValue: '', child: Text('412')),
      );
      final material = tester.widget<Material>(
        find
            .descendant(
              of: find.byType(HomePanel),
              matching: find.byType(Material),
            )
            .first,
      );
      final shape = material.shape! as RoundedRectangleBorder;
      expect(shape.side, BorderSide.none);
      final scheme = Theme.of(
        tester.element(find.byType(HomePanel)),
      ).colorScheme;
      expect(material.color, scheme.surfaceContainer);
    });

    testWidgets('a tap anywhere runs its action', (tester) async {
      var taps = 0;
      await _pump(
        tester,
        HomePanel(
          title: 'Dives',
          semanticsValue: '',
          onTap: () => taps++,
          child: const SizedBox.expand(),
        ),
      );
      await tester.tap(find.byType(HomePanel));
      expect(taps, 1);
    });

    testWidgets('long trailing text elides at 120 wide', (tester) async {
      await _pump(
        tester,
        const HomePanel(
          title: 'Latest profile',
          trailing:
              'Something Special, Kralendijk, Bonaire · 18.4 m · 52 min · 27°C',
          semanticsValue: '',
          child: SizedBox.expand(),
        ),
        width: 120,
      );
      expect(tester.takeException(), isNull);
    });

    testWidgets('tall content is clipped, not overflowed', (tester) async {
      await _pump(
        tester,
        const HomePanel(
          title: 'Recent dives',
          semanticsValue: '',
          fit: HomePanelFit.clip,
          child: Column(children: [SizedBox(height: 900)]),
        ),
        height: 96,
      );
      expect(tester.takeException(), isNull);
    });
  });

  group('HomePanelAsync', () {
    Widget async(AsyncValue<List<int>> value) => HomePanelAsync<List<int>>(
      value: value,
      isEmpty: (v) => v.isEmpty,
      emptyText: 'Nothing yet',
      builder: (v) => Text('n=${v.length}'),
    );

    testWidgets('loading shows a quiet placeholder', (tester) async {
      await _pump(tester, async(const AsyncLoading()));
      expect(find.byType(LinearProgressIndicator), findsOneWidget);
    });

    testWidgets('error shows one line', (tester) async {
      await _pump(tester, async(const AsyncError('x', StackTrace.empty)));
      expect(find.text("Couldn't load this"), findsOneWidget);
    });

    testWidgets('empty shows the empty text', (tester) async {
      await _pump(tester, async(const AsyncData([])));
      expect(find.text('Nothing yet'), findsOneWidget);
    });

    testWidgets('data builds the child', (tester) async {
      await _pump(tester, async(const AsyncData([1, 2])));
      expect(find.text('n=2'), findsOneWidget);
    });
  });

  testWidgets('row height grows with text scale, capped at 1.6', (
    tester,
  ) async {
    late double h1, h2;
    await _pump(
      tester,
      Builder(
        builder: (context) {
          h1 = homeRowHeight(HomePanelHeight.short, context);
          return const SizedBox();
        },
      ),
    );
    await _pump(
      tester,
      Builder(
        builder: (context) {
          h2 = homeRowHeight(HomePanelHeight.short, context);
          return const SizedBox();
        },
      ),
      textScale: 2,
    );
    expect(h1, 96);
    expect(h2, closeTo(96 * 1.6, 0.01));
  });

  group('charts survive empty, single and all-zero data', () {
    for (final values in [
      const <double>[],
      const [5.0],
      const [0.0, 0.0, 0.0],
    ]) {
      testWidgets('$values', (tester) async {
        await _pump(
          tester,
          Column(
            children: [
              SizedBox(height: 30, child: HomeSparkline(values)),
              SizedBox(
                height: 60,
                child: HomeBars(
                  values,
                  labels: [for (var i = 0; i < values.length; i++) '$i'],
                ),
              ),
              const HomeBarRow(label: 'Nitrox', value: '61%', fraction: 0.61),
              SizedBox(
                height: 60,
                child: HomeDayGrid(
                  counts: const {},
                  from: DateTime(2025, 11, 21),
                  to: DateTime(2026, 11, 20),
                ),
              ),
            ],
          ),
        );
        expect(tester.takeException(), isNull);
      });
    }
  });

  testWidgets('a bar row puts its value at the right edge', (tester) async {
    await _pump(
      tester,
      const Align(
        alignment: Alignment.topLeft,
        child: SizedBox(
          width: 300,
          child: HomeBarRow(label: 'Nitrox', value: '61%', fraction: 0.61),
        ),
      ),
    );
    final row = tester.getRect(find.byType(HomeBarRow));
    final value = tester.getRect(find.text('61%'));
    expect(value.right, closeTo(row.right, 0.5));
  });

  testWidgets('a long value still leaves the label room', (tester) async {
    await _pump(
      tester,
      const Align(
        alignment: Alignment.topLeft,
        child: SizedBox(
          width: 200,
          child: HomeBarRow(
            label: 'Max depth',
            value: '18.4 m · avg 21.0 m and a very long tail of text',
            fraction: 0.4,
          ),
        ),
      ),
    );
    expect(tester.getSize(find.text('Max depth')).width, greaterThan(60));
    expect(tester.takeException(), isNull);
  });

  test('the day grid fits a full year at 600 wide and trims when narrow', () {
    final from = DateTime(2025, 11, 21);
    final to = DateTime(2026, 11, 20);
    expect(HomeDayGrid.weeksShown(from, to, 600), 53);
    final narrow = HomeDayGrid.weeksShown(from, to, 200);
    expect(narrow, lessThan(53));
    expect(narrow * HomeDayGrid.minCell, lessThanOrEqualTo(200));
  });
}
