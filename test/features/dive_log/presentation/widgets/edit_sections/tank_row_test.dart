import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/core/providers/provider.dart';
import 'package:submersion/core/utils/unit_formatter.dart';
import 'package:submersion/features/dive_log/domain/entities/dive.dart';
import 'package:submersion/features/dive_log/presentation/widgets/edit_sections/tank_row.dart';
import 'package:submersion/features/dive_log/presentation/widgets/tank_editor.dart';
import 'package:submersion/features/settings/presentation/providers/settings_providers.dart';
import 'package:submersion/features/tank_presets/presentation/providers/tank_preset_providers.dart';
import 'package:submersion/l10n/arb/app_localizations.dart';

import '../../../../../helpers/mock_providers.dart';

const _testTank = DiveTank(
  id: 'tank-1',
  volume: 11.1,
  workingPressure: 207,
  startPressure: 200,
  endPressure: 50,
  gasMix: GasMix(o2: 32),
);

Future<void> _pump(WidgetTester tester, {DiveTank tank = _testTank}) async {
  final overrides = await getBaseOverrides();
  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        ...overrides.cast<Override>(),
        customTankPresetsProvider.overrideWith((ref) async => []),
      ],
      child: MaterialApp(
        // Pinned: flutter_test forwards the host machine's locale list, so an
        // unpinned MaterialApp translates "Tank 1" and "Done" out from under
        // the finders on a non-English dev machine.
        locale: const Locale('en'),
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: Scaffold(
          body: SingleChildScrollView(
            child: Material(
              child: TankRow(
                tank: tank,
                tankNumber: 1,
                units: const UnitFormatter(AppSettings()),
                onChanged: (_) {},
                canRemove: false,
              ),
            ),
          ),
        ),
      ),
    ),
  );
  await tester.pumpAndSettle();
}

void main() {
  testWidgets('collapsed: identity-first two-line row with chevron', (
    tester,
  ) async {
    await _pump(tester);
    // Title leads with tank identity.
    expect(find.textContaining('Tank 1'), findsOneWidget);
    // Subtitle carries mix, volume, and pressure range on one muted line.
    expect(find.textContaining('EAN32'), findsOneWidget);
    expect(find.textContaining('200'), findsOneWidget);
    expect(find.byIcon(Icons.chevron_right), findsOneWidget);
    expect(find.byType(TankEditor), findsNothing);
    // The old hero cells are gone.
    expect(find.text('PRESSURE'), findsNothing);
    expect(find.text('Edit'), findsNothing);
  });

  testWidgets('collapsed: subtitle keeps a fractional tank size intact', (
    tester,
  ) async {
    // Regression for #955: a 1.5 L stage rendered as "2 L", which is
    // indistinguishable from the 2 L bottle many divers carry alongside it.
    await _pump(
      tester,
      tank: _testTank.copyWith(volume: 1.5, workingPressure: 200),
    );
    expect(find.textContaining('1.5 L'), findsOneWidget);
    expect(find.textContaining('2 L'), findsNothing);
  });

  testWidgets('collapsed: subtitle drops the trailing zero on whole sizes', (
    tester,
  ) async {
    await _pump(
      tester,
      tank: _testTank.copyWith(volume: 12, workingPressure: 232),
    );
    expect(find.textContaining('12 L'), findsOneWidget);
    expect(find.textContaining('12.0 L'), findsNothing);
  });

  testWidgets('tap expands inline editor; Done collapses', (tester) async {
    tester.view.physicalSize = const Size(900, 3200);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);
    await _pump(tester);
    await tester.tap(find.textContaining('Tank 1'));
    await tester.pumpAndSettle();
    expect(find.byType(TankEditor), findsOneWidget);
    await tester.tap(find.text('Done'));
    await tester.pumpAndSettle();
    expect(find.byType(TankEditor), findsNothing);
  });
}
