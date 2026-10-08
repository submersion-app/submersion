import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/core/constants/enums.dart';
import 'package:submersion/core/providers/provider.dart';
import 'package:submersion/features/equipment/domain/entities/equipment_item.dart';
import 'package:submersion/features/equipment/domain/entities/equipment_set.dart';
import 'package:submersion/features/equipment/domain/models/equipment_arrangement.dart';
import 'package:submersion/features/equipment/figure/presentation/diver_figure.dart';
import 'package:submersion/features/equipment/figure/presentation/figure_number_badge.dart';
import 'package:submersion/features/equipment/presentation/pages/equipment_set_edit_page.dart';
import 'package:submersion/features/equipment/presentation/providers/equipment_arrangement_provider.dart';
import 'package:submersion/features/equipment/presentation/providers/equipment_component_providers.dart';
import 'package:submersion/features/equipment/presentation/providers/equipment_providers.dart';
import 'package:submersion/features/equipment/presentation/providers/equipment_set_providers.dart';
import 'package:submersion/features/settings/presentation/providers/settings_providers.dart';
import 'package:submersion/l10n/arb/app_localizations.dart';

import '../../../../helpers/mock_providers.dart';

void main() {
  const mask = EquipmentItem(
    id: 'mask',
    name: 'Cressi',
    type: EquipmentType.mask,
  );
  const bcd = EquipmentItem(
    id: 'bcd',
    name: 'Hollis SMS75',
    type: EquipmentType.bcd,
  );
  const fins = EquipmentItem(
    id: 'fins',
    name: 'Jets',
    type: EquipmentType.fins,
  );
  const retired = EquipmentItem(
    id: 'old',
    name: 'Old light',
    type: EquipmentType.light,
  );

  EquipmentSet setWith({required bool showFigure}) => EquipmentSet(
    id: 'set-1',
    name: 'Reef set',
    // 'old' is a member but retired, so it has no checkbox row.
    equipmentIds: const ['mask', 'bcd', 'old'],
    items: const [mask, bcd, retired],
    showFigure: showFigure,
    createdAt: DateTime(2026),
    updatedAt: DateTime(2026),
  );

  Future<void> pumpPage(
    WidgetTester tester, {
    required bool showFigure,
    double textScale = 1,
  }) async {
    tester.view.physicalSize = const Size(1200, 3000);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          settingsProvider.overrideWith((ref) => MockSettingsNotifier()),
          equipmentSetProvider(
            'set-1',
          ).overrideWith((ref) async => setWith(showFigure: showFigure)),
          activeEquipmentProvider.overrideWith(
            (ref) async => const [mask, bcd, fins],
          ),
          allEquipmentProvider.overrideWith(
            (ref) async => const [mask, bcd, fins, retired],
          ),
          equipmentArrangementProvider.overrideWithValue(
            EquipmentArrangement.defaults.copyWith(groupByType: false),
          ),
          equipmentComponentsIndexProvider.overrideWithValue(
            const AsyncValue.data(ComponentsIndex.empty),
          ),
        ],
        child: MaterialApp(
          locale: const Locale('en'),
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          builder: (context, child) => MediaQuery(
            data: MediaQuery.of(
              context,
            ).copyWith(textScaler: TextScaler.linear(textScale)),
            child: child!,
          ),
          home: const EquipmentSetEditPage(setId: 'set-1'),
        ),
      ),
    );
    await tester.pumpAndSettle();
  }

  Finder rowOf(String name) => find.ancestor(
    of: find.text(name),
    matching: find.byType(CheckboxListTile),
  );

  testWidgets('with the switch off the page has no figure and no badges', (
    tester,
  ) async {
    await pumpPage(tester, showFigure: false);
    expect(find.byType(DiverFigure), findsNothing);
    expect(find.byType(FigureNumberBadge), findsNothing);
  });

  testWidgets('with the switch off the form stays a lazily built list', (
    tester,
  ) async {
    // Every row is built only while the figure shows (so a tap on it can
    // scroll to any row); off, a long inventory builds as it always did.
    await pumpPage(tester, showFigure: false);
    expect(find.byType(ListView), findsOneWidget);
    await tester.tap(find.widgetWithText(SwitchListTile, 'Show diver figure'));
    await tester.pumpAndSettle();
    expect(find.byType(ListView), findsNothing);
  });

  testWidgets('with it on the ticked items with a row are drawn and numbered', (
    tester,
  ) async {
    await pumpPage(tester, showFigure: true);
    expect(find.byType(DiverFigure), findsOneWidget);
    expect(find.bySemanticsLabel('Reef set, 2 items'), findsOneWidget);
    // Two ticked rows, two badges, numbered 1..2 with no gap for the
    // retired member.
    final numbers =
        tester
            .widgetList<FigureNumberBadge>(
              find.descendant(
                of: find.byType(CheckboxListTile),
                matching: find.byType(FigureNumberBadge),
              ),
            )
            .map((b) => b.number)
            .toList()
          ..sort();
    expect(numbers, [1, 2]);
    expect(find.byKey(const ValueKey('figure-label-old')), findsNothing);
  });

  testWidgets('with the figure on, ticked and unticked names line up', (
    tester,
  ) async {
    // Ticked rows lead with a number badge; an unticked row keeps the
    // badge's room so its name does not sit further left.
    await pumpPage(tester, showFigure: true);
    double nameX(String name) => tester
        .getTopLeft(find.descendant(of: rowOf(name), matching: find.text(name)))
        .dx;
    expect(nameX('Jets'), nameX('Hollis SMS75'));
  });

  testWidgets('with large text, ticked and unticked names still line up', (
    tester,
  ) async {
    // The badge grows with the diver's text size, so the room an unticked
    // row keeps must grow with it.
    await pumpPage(tester, showFigure: true, textScale: 3);
    double nameX(String name) => tester
        .getTopLeft(find.descendant(of: rowOf(name), matching: find.text(name)))
        .dx;
    expect(nameX('Jets'), nameX('Hollis SMS75'));
  });

  testWidgets('ticking an item redraws the figure at once', (tester) async {
    await pumpPage(tester, showFigure: true);
    await tester.tap(rowOf('Jets'));
    await tester.pumpAndSettle();
    expect(find.byKey(const ValueKey('figure-label-fins')), findsOneWidget);
    expect(find.bySemanticsLabel('Reef set, 3 items'), findsOneWidget);
    await tester.tap(rowOf('Cressi'));
    await tester.pumpAndSettle();
    expect(find.byKey(const ValueKey('figure-label-mask')), findsNothing);
  });

  testWidgets('the figure summary follows the name as it is typed', (
    tester,
  ) async {
    await pumpPage(tester, showFigure: true);
    final nameField = find.widgetWithText(TextFormField, 'Reef set');
    await tester.enterText(nameField, 'Wreck set');
    await tester.pump();
    expect(find.bySemanticsLabel('Wreck set, 2 items'), findsOneWidget);
    expect(find.bySemanticsLabel('Reef set, 2 items'), findsNothing);
  });

  testWidgets('a cleared name gives the figure the new set title', (
    tester,
  ) async {
    await pumpPage(tester, showFigure: true);
    await tester.enterText(
      find.widgetWithText(TextFormField, 'Reef set'),
      '  ',
    );
    await tester.pump();
    expect(find.bySemanticsLabel('New Equipment Set, 2 items'), findsOneWidget);
  });

  testWidgets('the switch shows and hides the figure', (tester) async {
    await pumpPage(tester, showFigure: false);
    await tester.tap(find.widgetWithText(SwitchListTile, 'Show diver figure'));
    await tester.pumpAndSettle();
    expect(find.byType(DiverFigure), findsOneWidget);
    await tester.tap(find.widgetWithText(SwitchListTile, 'Show diver figure'));
    await tester.pumpAndSettle();
    expect(find.byType(DiverFigure), findsNothing);
  });

  testWidgets('a tap on a name flashes that item\'s row', (tester) async {
    await pumpPage(tester, showFigure: true);
    await tester.tap(find.byKey(const ValueKey('figure-label-bcd')));
    await tester.pump();
    final badge = tester.widget<FigureNumberBadge>(
      find.descendant(
        of: rowOf('Hollis SMS75'),
        matching: find.byType(FigureNumberBadge),
      ),
    );
    expect(badge.selected, isTrue);
    await tester.pump(const Duration(milliseconds: 1300));
    await tester.pumpAndSettle();
  });

  testWidgets('no ticked items means no figure', (tester) async {
    await pumpPage(tester, showFigure: true);
    await tester.tap(rowOf('Cressi'));
    await tester.tap(rowOf('Hollis SMS75'));
    await tester.pumpAndSettle();
    expect(find.byType(DiverFigure), findsNothing);
  });
}
