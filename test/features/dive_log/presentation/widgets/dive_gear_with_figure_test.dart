import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/core/constants/enums.dart';
import 'package:submersion/core/providers/provider.dart';
import 'package:submersion/features/dive_log/domain/entities/dive.dart';
import 'package:submersion/features/dive_log/presentation/widgets/dive_gear_tree_view.dart';
import 'package:submersion/features/dive_log/presentation/widgets/dive_gear_with_figure.dart';
import 'package:submersion/features/equipment/domain/entities/equipment_item.dart';
import 'package:submersion/features/equipment/domain/entities/gear_link.dart';
import 'package:submersion/features/equipment/domain/models/equipment_arrangement.dart';
import 'package:submersion/features/equipment/figure/domain/figure_zone.dart';
import 'package:submersion/features/equipment/figure/presentation/diver_figure.dart';
import 'package:submersion/features/equipment/figure/presentation/figure_number_badge.dart';
import 'package:submersion/features/equipment/presentation/providers/assembly_snapshot_providers.dart';
import 'package:submersion/features/equipment/presentation/providers/equipment_arrangement_provider.dart';
import 'package:submersion/features/equipment/presentation/providers/equipment_component_providers.dart';
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
  const tank = EquipmentItem(
    id: 'tank',
    name: 'Left AL80',
    type: EquipmentType.tank,
  );
  final dive = Dive(
    id: 'dive-1',
    diveNumber: 7,
    dateTime: DateTime(2026, 3, 28, 10),
    notes: '',
    gear: looseGear(const [mask, tank]),
    tanks: const [
      DiveTank(id: 't1', equipmentId: 'tank', role: TankRole.sidemountLeft),
    ],
  );

  ListTile row(WidgetTester tester, String id) =>
      tester.widget<ListTile>(find.byKey(ValueKey('gear-row-$id')));

  Future<void> pump(
    WidgetTester tester, {
    required bool showFigure,
    Dive? of,
  }) async {
    tester.view.physicalSize = const Size(900, 2400);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          equipmentArrangementProvider.overrideWithValue(
            EquipmentArrangement.defaults.copyWith(groupByType: false),
          ),
          equipmentSetsProvider.overrideWith((ref) async => const []),
          settingsProvider.overrideWith((ref) => MockSettingsNotifier()),
          equipmentComponentsIndexProvider.overrideWith(
            (ref) async => ComponentsIndex.empty,
          ),
          activeComponentIdsProvider.overrideWith((ref) async => <String>{}),
        ],
        child: MaterialApp(
          locale: const Locale('en'),
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: Scaffold(
            body: SingleChildScrollView(
              child: DiveGearWithFigure(
                dive: of ?? dive,
                showFigure: showFigure,
                showServiceStatus: false,
              ),
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
  }

  testWidgets('off, it is the tree alone', (tester) async {
    await pump(tester, showFigure: false);
    expect(find.byType(DiveGearTreeView), findsOneWidget);
    expect(find.byType(DiverFigure), findsNothing);
    expect(find.byType(FigureNumberBadge), findsNothing);
  });

  testWidgets('on, the figure sits above the tree and nothing is numbered', (
    tester,
  ) async {
    await pump(tester, showFigure: true);
    expect(find.byType(DiverFigure), findsOneWidget);
    expect(find.bySemanticsLabel('Gear on this dive, 2 items'), findsOneWidget);
    expect(
      tester.getTopLeft(find.byType(DiverFigure)).dy,
      lessThan(tester.getTopLeft(find.byType(DiveGearTreeView)).dy),
    );
    // The figure names every item, so neither it nor the rows carry a
    // number (issue #2774), and a label reads without one.
    expect(find.byType(FigureNumberBadge), findsNothing);
    expect(find.bySemanticsLabel('Mask, Cressi'), findsOneWidget);
  });

  testWidgets('a linked tank is drawn where its role puts it', (tester) async {
    await pump(tester, showFigure: true);
    // The dive tank's sidemountLeft role wins over the tank's default back
    // tank zone.
    final model = tester.widget<DiverFigure>(find.byType(DiverFigure)).model;
    expect(model.byId('tank')!.zone, FigureZone.sidemountLeft);
    // A sidemount tank labels on the back view; the wide layout shows both.
    expect(find.byKey(const ValueKey('figure-label-tank')), findsOneWidget);
  });

  testWidgets('a tap on a name flashes that row', (tester) async {
    await pump(tester, showFigure: true);
    await tester.tap(find.byKey(const ValueKey('figure-label-mask')));
    await tester.pump();
    expect(row(tester, 'mask').tileColor, isNotNull);
    expect(row(tester, 'tank').tileColor, isNull);
    await tester.pump(const Duration(milliseconds: 1300));
    await tester.pumpAndSettle();
  });

  testWidgets('hiding the figure mid-flash leaves no row highlighted', (
    tester,
  ) async {
    await pump(tester, showFigure: true);
    await tester.tap(find.byKey(const ValueKey('figure-label-mask')));
    await tester.pump();
    expect(row(tester, 'mask').tileColor, isNotNull);
    // The diver turns the figure off before the flash times out.
    await pump(tester, showFigure: false);
    expect(row(tester, 'mask').tileColor, isNull);
    await tester.pump(const Duration(milliseconds: 1300));
    await tester.pumpAndSettle();
  });

  testWidgets('on, a dive with no gear shows no figure and does not throw', (
    tester,
  ) async {
    await pump(
      tester,
      showFigure: true,
      of: Dive(
        id: 'empty',
        dateTime: DateTime(2026),
        notes: '',
        gear: const [],
      ),
    );
    expect(tester.takeException(), isNull);
    expect(find.byType(DiverFigure), findsNothing);
  });
}
