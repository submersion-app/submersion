import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/features/dive_log/presentation/widgets/pickers/sighting_abundance_picker.dart';
import 'package:submersion/features/marine_life/domain/entities/sighting_abundance.dart';
import 'package:submersion/l10n/arb/app_localizations.dart';

/// Hosts the picker the way the add dialog and the edit sheet do: the
/// parent keeps the value and rebuilds the picker with it.
class _Host extends StatefulWidget {
  final SightingAmount initial;
  final ValueChanged<SightingAmount> onChanged;

  const _Host({required this.initial, required this.onChanged});

  @override
  State<_Host> createState() => _HostState();
}

class _HostState extends State<_Host> {
  late SightingAmount _value = widget.initial;

  @override
  Widget build(BuildContext context) => SightingAbundancePicker(
    value: _value,
    onChanged: (v) {
      setState(() => _value = v);
      widget.onChanged(v);
    },
  );
}

Future<List<SightingAmount>> _pump(
  WidgetTester tester, {
  SightingAmount initial = (abundance: SightingAbundance.seen, count: 1),
}) async {
  final changes = <SightingAmount>[];
  await tester.pumpWidget(
    MaterialApp(
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      locale: const Locale('en'),
      home: Scaffold(
        body: _Host(initial: initial, onChanged: changes.add),
      ),
    ),
  );
  return changes;
}

bool _selected(WidgetTester tester, String label) =>
    tester.widget<ChoiceChip>(find.widgetWithText(ChoiceChip, label)).selected;

void main() {
  testWidgets('shows the label, six chips in order and the ranges', (
    tester,
  ) async {
    await _pump(tester);

    expect(find.text('How many'), findsOneWidget);
    final labels = tester
        .widgetList<ChoiceChip>(find.byType(ChoiceChip))
        .map((c) => ((c.label as Text).data))
        .toList();
    expect(labels, ['Seen', 'Single', 'Few', 'Many', 'Abundant', 'Exact']);
    expect(
      find.text('Few 2 to 10, Many 11 to 100, Abundant over 100'),
      findsOneWidget,
    );
  });

  testWidgets('Seen starts selected with no stepper', (tester) async {
    await _pump(tester);

    expect(_selected(tester, 'Seen'), isTrue);
    expect(find.byIcon(Icons.add_circle_outline), findsNothing);
  });

  testWidgets('Exact shows the stepper starting at 1', (tester) async {
    final changes = await _pump(tester);

    await tester.tap(find.text('Exact'));
    await tester.pump();

    expect(find.byIcon(Icons.add_circle_outline), findsOneWidget);
    expect(find.text('1'), findsOneWidget);
    expect(changes.last, (abundance: SightingAbundance.exact, count: 1));
  });

  testWidgets('a group is reported with count 1 and hides the stepper', (
    tester,
  ) async {
    final changes = await _pump(
      tester,
      initial: (abundance: SightingAbundance.exact, count: 7),
    );

    await tester.tap(find.text('Few'));
    await tester.pump();

    expect(changes.last, (abundance: SightingAbundance.few, count: 1));
    expect(find.byIcon(Icons.add_circle_outline), findsNothing);
  });

  testWidgets('Exact 7, then Few, then Exact restores 7', (tester) async {
    final changes = await _pump(
      tester,
      initial: (abundance: SightingAbundance.exact, count: 7),
    );

    await tester.tap(find.text('Few'));
    await tester.pump();
    await tester.tap(find.text('Exact'));
    await tester.pump();

    expect(find.text('7'), findsOneWidget);
    expect(changes.last, (abundance: SightingAbundance.exact, count: 7));
  });

  testWidgets('the stepper counts up and stops at 1 going down', (
    tester,
  ) async {
    final changes = await _pump(
      tester,
      initial: (abundance: SightingAbundance.exact, count: 1),
    );

    final minus = find.byIcon(Icons.remove_circle_outline);
    expect(
      tester
          .widget<IconButton>(
            find.widgetWithIcon(IconButton, Icons.remove_circle_outline),
          )
          .onPressed,
      isNull,
    );
    await tester.tap(find.byIcon(Icons.add_circle_outline));
    await tester.pump();
    await tester.tap(find.byIcon(Icons.add_circle_outline));
    await tester.pump();
    expect(find.text('3'), findsOneWidget);
    await tester.tap(minus);
    await tester.pump();

    expect(changes.last, (abundance: SightingAbundance.exact, count: 2));
  });
}
