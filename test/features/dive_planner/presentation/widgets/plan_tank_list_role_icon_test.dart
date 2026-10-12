import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/core/icons/submersion_icons.dart';
import 'package:submersion/core/providers/provider.dart';
import 'package:submersion/features/dive_log/domain/entities/dive.dart';
import 'package:submersion/features/dive_planner/presentation/providers/dive_planner_providers.dart';
import 'package:submersion/features/dive_planner/presentation/widgets/plan_tank_list.dart';
import 'package:submersion/features/planner/domain/entities/dive_plan.dart'
    show PlanMode;
import 'package:submersion/features/settings/presentation/providers/settings_providers.dart';

import '../../../../helpers/mock_providers.dart';
import '../../../../helpers/test_app.dart';

/// Each planner tank chip leads with the glyph of the role the plan derives
/// for that cylinder (issue #2901). The planner never stores a role, so the
/// glyph follows the gas: an EAN50 richer than the bottom mix is a deco
/// bottle the moment it is added.
void main() {
  Future<ProviderContainer> pumpList(WidgetTester tester) async {
    await tester.pumpWidget(
      testApp(
        locale: const Locale('en'),
        overrides: [
          settingsProvider.overrideWith((ref) => MockSettingsNotifier()),
        ],
        child: const SingleChildScrollView(child: PlanTankList()),
      ),
    );
    await tester.pumpAndSettle();
    return ProviderScope.containerOf(tester.element(find.byType(PlanTankList)));
  }

  Finder chipIcon(String chipLabel, IconData icon) => find.descendant(
    of: find.widgetWithText(InputChip, chipLabel),
    matching: find.byIcon(icon),
  );

  const deco = DiveTank(
    id: 'deco',
    name: 'Deco',
    volume: 7,
    startPressure: 200,
    gasMix: GasMix(o2: 50),
  );

  testWidgets('the bottom tank shows back gas and a richer mix shows slung', (
    tester,
  ) async {
    final container = await pumpList(tester);
    container.read(divePlanNotifierProvider.notifier).addTank(deco);
    await tester.pumpAndSettle();

    final bottomName = container.read(divePlanNotifierProvider).tanks.first;
    expect(
      chipIcon(
        bottomName.name ?? bottomName.gasMix.name,
        SubmersionIcons.tankBackGas,
      ),
      findsOneWidget,
    );
    expect(chipIcon('Deco', SubmersionIcons.tankSlung), findsOneWidget);
  });

  testWidgets('a named chip keeps the gas on its second line', (tester) async {
    final container = await pumpList(tester);
    container.read(divePlanNotifierProvider.notifier).addTank(deco);
    await tester.pumpAndSettle();

    // The avatar no longer carries the gas initial, so a named cylinder
    // names its gas beside the pressure and size.
    expect(
      find.descendant(
        of: find.widgetWithText(InputChip, 'Deco'),
        matching: find.textContaining('EAN50'),
      ),
      findsOneWidget,
    );
  });

  testWidgets('the screen-reader label names the role', (tester) async {
    final container = await pumpList(tester);
    container.read(divePlanNotifierProvider.notifier).addTank(deco);
    await tester.pumpAndSettle();

    // The chip's label merges into the card's node, read in tank order.
    expect(
      find.bySemanticsLabel(RegExp('Deco, Deco, EAN50, 200 bar, 7 L')),
      findsOneWidget,
    );
  });

  testWidgets('a loop plan shows its oxygen cylinder with the CCR glyph', (
    tester,
  ) async {
    final container = await pumpList(tester);
    final notifier = container.read(divePlanNotifierProvider.notifier);
    notifier.updateMode(PlanMode.ccr);
    notifier.addTank(
      const DiveTank(
        id: 'o2',
        name: 'O2',
        volume: 3,
        startPressure: 200,
        gasMix: GasMix(o2: 100),
      ),
    );
    await tester.pumpAndSettle();

    expect(chipIcon('O2', SubmersionIcons.tankRebreather), findsOneWidget);
  });
}
