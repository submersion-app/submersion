import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/core/providers/provider.dart';
import 'package:submersion/shared/widgets/section_title_toggle.dart';

class _Host extends StatefulWidget {
  const _Host({required this.labels, required this.onController});

  final List<String> labels;
  final ValueChanged<TabController> onController;

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
    tabBarKey: const ValueKey('test_toggle'),
  );
}

Future<TabController> _pump(WidgetTester tester, List<String> labels) async {
  late TabController controller;
  await tester.pumpWidget(
    ProviderScope(
      child: MaterialApp(
        home: Scaffold(
          body: _Host(labels: labels, onController: (c) => controller = c),
        ),
      ),
    ),
  );
  return controller;
}

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
