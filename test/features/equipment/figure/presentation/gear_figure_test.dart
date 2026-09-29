import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/core/constants/enums.dart';
import 'package:submersion/features/equipment/figure/domain/figure_composer.dart';
import 'package:submersion/features/equipment/figure/domain/figure_model.dart';
import 'package:submersion/features/equipment/figure/presentation/diver_figure.dart';
import 'package:submersion/features/equipment/figure/presentation/gear_figure.dart';
import 'package:submersion/l10n/arb/app_localizations.dart';

void main() {
  testWidgets('names the picture and each item in the app language', (
    tester,
  ) async {
    final model = composeFigure(const [
      FigureItemInput(id: 'b', type: EquipmentType.bcd, name: 'Hollis SMS75'),
      FigureItemInput(id: 't', type: EquipmentType.tool, name: 'Wrench'),
    ]);
    PlacedItem? tapped;
    tester.view.physicalSize = const Size(900, 1600);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(
      MaterialApp(
        locale: const Locale('en'),
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: Scaffold(
          body: SingleChildScrollView(
            child: GearFigure(
              model: model,
              title: 'Reef set',
              onItemTap: (p) => tapped = p,
            ),
          ),
        ),
      ),
    );
    expect(find.byType(DiverFigure), findsOneWidget);
    expect(find.bySemanticsLabel('Reef set, 2 items'), findsOneWidget);
    expect(find.bySemanticsLabel('1, BCD, Hollis SMS75'), findsOneWidget);
    expect(find.text('Also carried'), findsOneWidget);
    await tester.tap(find.byKey(const ValueKey('figure-label-b')));
    expect(tapped?.item.id, 'b');
  });
}
