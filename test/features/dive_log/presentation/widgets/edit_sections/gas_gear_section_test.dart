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
  modeSelector: const Text('MODE'),
  tankCards: const [Text('TANK-CARD')],
  onAddTank: () {},
  addTankLabel: 'Add tank',
  equipmentChild: const Text('EQUIP'),
  weightChild: const Text('WEIGHTS'),
  showTankControls: showTankControls,
);

void main() {
  testWidgets(
    'hides tank cards and add-tank row when showTankControls is false',
    (tester) async {
      await tester.pumpWidget(_host(_section(showTankControls: false)));
      await tester.pumpAndSettle();

      expect(find.text('TANK-CARD'), findsNothing);
      expect(find.text('+ Add tank'), findsNothing);
      // Mode selector, equipment, and weights still render for gauge dives.
      expect(find.text('MODE'), findsOneWidget);
      expect(find.text('EQUIP'), findsOneWidget);
      expect(find.text('WEIGHTS'), findsOneWidget);
    },
  );

  testWidgets('shows tank cards when showTankControls is true (default)', (
    tester,
  ) async {
    await tester.pumpWidget(_host(_section(showTankControls: true)));
    await tester.pumpAndSettle();

    expect(find.text('TANK-CARD'), findsOneWidget);
    expect(find.text('+ Add tank'), findsOneWidget);
  });
}
