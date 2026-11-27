import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/features/dashboard/presentation/home_layout.dart';
import 'package:submersion/features/dashboard/presentation/home_panels.dart';
import 'package:submersion/features/dashboard/presentation/widgets/dashboard_grid.dart';

/// A panel stand-in that remembers how often it was created.
class _Probe extends StatefulWidget {
  final String label;
  const _Probe(this.label, {super.key});

  static int created = 0;

  @override
  State<_Probe> createState() => _ProbeState();
}

class _ProbeState extends State<_Probe> {
  @override
  void initState() {
    super.initState();
    _Probe.created++;
  }

  @override
  Widget build(BuildContext context) =>
      ColoredBox(color: Colors.teal, child: Text(widget.label));
}

Future<void> _pump(
  WidgetTester tester,
  List<HomeRow> rows, {
  Widget? leading,
  double width = 1280,
}) async {
  tester.view.physicalSize = Size(width, 2000);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);
  await tester.pumpWidget(
    MaterialApp(
      home: Scaffold(
        body: CustomScrollView(
          slivers: [
            DashboardGrid(
              rows: rows,
              panelBuilder: (p) => _Probe(p.name, key: ValueKey(p)),
              rowHeight: (r) => r.height == HomePanelHeight.short ? 96 : 180,
              leading: leading,
            ),
          ],
        ),
      ),
    ),
  );
}

void main() {
  testWidgets('every row spans the full width', (tester) async {
    final rows = packHomeRows([
      HomePanelType.photoRibbon,
      HomePanelType.recentSitesMap,
      HomePanelType.latestProfile,
      HomePanelType.recentDives,
      HomePanelType.gearService,
    ], HomeWidthTier.desktop);
    await _pump(tester, rows);
    final grid = tester.getRect(find.byType(CustomScrollView));
    // gearService sits alone in its row and stretches to the full width.
    final lone = tester.getRect(find.text('gearService'));
    expect(lone.width, closeTo(grid.width, 1));
    // photos and the map share a row, left edge to right edge.
    final left = tester.getRect(find.text('photoRibbon'));
    final right = tester.getRect(find.text('recentSitesMap'));
    expect(left.left, closeTo(grid.left, 1));
    expect(right.right, closeTo(grid.right, 1));
  });

  testWidgets('panels in a row share a height', (tester) async {
    final rows = packHomeRows([
      HomePanelType.latestProfile,
      HomePanelType.recentDives,
    ], HomeWidthTier.desktop);
    await _pump(tester, rows);
    final a = tester.getSize(find.text('latestProfile'));
    final b = tester.getSize(find.text('recentDives'));
    expect(a.height, 180);
    expect(b.height, a.height);
  });

  testWidgets('a row arriving above does not rebuild the rows below', (
    tester,
  ) async {
    final without = packHomeRows([
      HomePanelType.keyNumbers,
      HomePanelType.recentDives,
    ], HomeWidthTier.desktop);
    final withConditional = packHomeRows([
      HomePanelType.keyNumbers,
      HomePanelType.onThisDay,
      HomePanelType.recentDives,
    ], HomeWidthTier.desktop);
    _Probe.created = 0;
    await _pump(tester, without);
    expect(_Probe.created, 2);
    await _pump(tester, withConditional);
    expect(_Probe.created, 3, reason: 'only the new panel is created');
  });

  testWidgets('leading renders as the second row', (tester) async {
    final rows = packHomeRows([
      HomePanelType.keyNumbers,
      HomePanelType.recentDives,
    ], HomeWidthTier.desktop);
    await _pump(tester, rows, leading: const Text('first dive'));
    final key = tester.getRect(find.text('keyNumbers'));
    final lead = tester.getRect(find.text('first dive'));
    final dives = tester.getRect(find.text('recentDives'));
    expect(lead.top, greaterThan(key.top));
    expect(dives.top, greaterThan(lead.top));
  });

  testWidgets('no rows renders nothing', (tester) async {
    await _pump(tester, const []);
    expect(find.byType(_Probe), findsNothing);
  });
}
