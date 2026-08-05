import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/features/dive_log/presentation/widgets/edit_sections/gas_gear_section.dart';
import 'package:submersion/l10n/arb/app_localizations.dart';

Widget _host(Widget child) => MaterialApp(
  localizationsDelegates: AppLocalizations.localizationsDelegates,
  supportedLocales: AppLocalizations.supportedLocales,
  home: Scaffold(body: SingleChildScrollView(child: child)),
);

GasGearSection _section({required bool showTankControls}) => GasGearSection(
  expanded: true,
  onToggle: () {},
  summary: 'summary',
  modeChild: const Text('MODE'),
  tanks: const [Text('TANK-ROW')],
  onAddTank: () {},
  addTankLabel: 'Add tank',
  equipmentChild: const Text('EQUIP'),
  weightChild: const Text('WEIGHTS'),
  showTankControls: showTankControls,
);

void main() {
  testWidgets(
    'hides tank rows and add-tank row when showTankControls is false',
    (tester) async {
      await tester.pumpWidget(_host(_section(showTankControls: false)));
      await tester.pumpAndSettle();

      expect(find.text('TANK-ROW'), findsNothing);
      expect(find.text('Add tank'), findsNothing);
      expect(find.text('TANKS'), findsNothing);
      // Mode row, equipment, and weights still render for gauge dives.
      expect(find.text('MODE'), findsOneWidget);
      expect(find.text('EQUIP'), findsOneWidget);
      expect(find.text('WEIGHTS'), findsOneWidget);
    },
  );

  testWidgets('shows tank rows when showTankControls is true (default)', (
    tester,
  ) async {
    await tester.pumpWidget(_host(_section(showTankControls: true)));
    await tester.pumpAndSettle();

    expect(find.text('TANK-ROW'), findsOneWidget);
    expect(find.text('TANKS'), findsOneWidget);
    expect(find.text('Add tank'), findsOneWidget);
  });
}
