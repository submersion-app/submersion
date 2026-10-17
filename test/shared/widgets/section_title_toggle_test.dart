import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/core/providers/provider.dart';
import 'package:submersion/shared/widgets/app_bar_tab_metrics.dart';
import 'package:submersion/shared/widgets/section_title_toggle.dart';

class _Host extends StatefulWidget {
  const _Host({
    required this.labels,
    required this.onController,
    this.onAppBar = false,
  });

  final List<String> labels;
  final ValueChanged<TabController> onController;
  final bool onAppBar;

  @override
  State<_Host> createState() => _HostState();
}

class _HostState extends State<_Host> with SingleTickerProviderStateMixin {
  late final TabController _controller = TabController(length: 2, vsync: this);

  @override
  void initState() {
    super.initState();
    widget.onController(_controller);
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => SectionTitleToggle(
    controller: _controller,
    featureId: 'courses',
    labels: widget.labels,
    onAppBar: widget.onAppBar,
    tabBarKey: const ValueKey('test_toggle'),
  );
}

Future<TabController> _pump(
  WidgetTester tester,
  List<String> labels, {
  bool onAppBar = false,
  ThemeData? theme,
}) async {
  late TabController controller;
  await tester.pumpWidget(
    ProviderScope(
      child: MaterialApp(
        theme: theme,
        home: Scaffold(
          body: _Host(
            labels: labels,
            onAppBar: onAppBar,
            onController: (c) => controller = c,
          ),
        ),
      ),
    ),
  );
  return controller;
}

TabBar _bar(WidgetTester tester) =>
    tester.widget<TabBar>(find.byKey(const ValueKey('test_toggle')));

/// A theme whose app bar is coloured, unlike the page under it, as several
/// presets' are (Tropical).
final _colouredBarTheme = ThemeData(
  appBarTheme: const AppBarTheme(
    backgroundColor: Color(0xFF00897B),
    foregroundColor: Color(0xFFFFFFFF),
  ),
);

void main() {
  testWidgets('shows one tab per label', (tester) async {
    await _pump(tester, const ['Alpha', 'Beta']);

    expect(find.widgetWithText(Tab, 'Alpha'), findsOneWidget);
    expect(find.widgetWithText(Tab, 'Beta'), findsOneWidget);
    expect(find.byKey(const ValueKey('test_toggle')), findsOneWidget);
  });

  testWidgets('tapping the second label selects it', (tester) async {
    final controller = await _pump(tester, const ['Alpha', 'Beta']);

    await tester.tap(find.text('Beta'));
    await tester.pumpAndSettle();

    expect(controller.index, 1);
  });

  testWidgets('the selected name is underlined, as the Media tabs are', (
    tester,
  ) async {
    await _pump(tester, const ['Alpha', 'Beta'], theme: _colouredBarTheme);
    final theme = Theme.of(tester.element(find.byType(SectionTitleToggle)));
    // In a pane header, judged against the pane's own surface rather than
    // the coloured app bar it does not sit on.
    final colors = AppBarTabColors.on(
      theme,
      background: theme.colorScheme.surface,
      foreground: theme.colorScheme.onSurface,
    );
    final bar = _bar(tester);

    // The stock underline drawn in indicatorColor, not a filled pill.
    expect(bar.indicator, isNull);
    expect(bar.indicatorColor, colors.selected);
    expect(bar.labelColor, colors.selected);
    expect(bar.unselectedLabelColor, colors.unselected);
    expect(bar.overlayColor, isNotNull);
  });

  testWidgets('on an app bar it takes the bar\'s own tab colours', (
    tester,
  ) async {
    await _pump(
      tester,
      const ['Alpha', 'Beta'],
      onAppBar: true,
      theme: _colouredBarTheme,
    );
    final theme = Theme.of(tester.element(find.byType(SectionTitleToggle)));
    final colors = AppBarTabColors.of(theme);
    final bar = _bar(tester);

    expect(bar.indicator, isNull);
    expect(bar.indicatorColor, colors.selected);
    expect(bar.labelColor, colors.selected);
    expect(bar.unselectedLabelColor, colors.unselected);
  });

  testWidgets('naturalWidth grows with a longer label', (tester) async {
    await _pump(tester, const ['Alpha', 'Beta']);
    final context = tester.element(find.byType(SectionTitleToggle));
    const style = TextStyle(fontSize: 18);

    final short = SectionTitleToggle.naturalWidth(
      context,
      style,
      labels: const ['Alpha', 'Beta'],
      withAccentIcon: false,
    );
    final long = SectionTitleToggle.naturalWidth(
      context,
      style,
      labels: const ['Alpha', 'Beta with a much longer name'],
      withAccentIcon: false,
    );

    expect(long, greaterThan(short));
    expect(
      SectionTitleToggle.naturalWidth(
        context,
        style,
        labels: const ['Alpha', 'Beta'],
        withAccentIcon: true,
      ),
      greaterThan(short),
    );
  });
}
