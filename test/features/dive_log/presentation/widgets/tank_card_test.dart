import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/core/providers/provider.dart';
import 'package:submersion/core/utils/unit_formatter.dart';
import 'package:submersion/features/dive_log/domain/entities/dive.dart';
import 'package:submersion/features/dive_log/presentation/widgets/edit_sections/tank_card.dart';
import 'package:submersion/features/dive_log/presentation/widgets/tank_editor.dart';
import 'package:submersion/features/settings/presentation/providers/settings_providers.dart';
import 'package:submersion/features/tank_presets/presentation/providers/tank_preset_providers.dart';
import 'package:submersion/l10n/arb/app_localizations.dart';

import '../../../../helpers/mock_providers.dart';

const _testTank = DiveTank(
  id: 'tank-1',
  volume: 11.1,
  workingPressure: 207,
  startPressure: 200,
  endPressure: 50,
  gasMix: GasMix(o2: 32),
);

Future<void> _pump(WidgetTester tester) async {
  final overrides = await getBaseOverrides();
  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        ...overrides.cast<Override>(),
        customTankPresetsProvider.overrideWith((ref) async => []),
      ],
      child: MaterialApp(
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: Scaffold(
          body: SingleChildScrollView(
            child: TankCard(
              tank: _testTank,
              tankNumber: 1,
              units: const UnitFormatter(AppSettings()),
              onChanged: (_) {},
              canRemove: false,
            ),
          ),
        ),
      ),
    ),
  );
  await tester.pumpAndSettle();
}

void main() {
  testWidgets('collapsed card shows pressure, mix, volume and caption', (
    tester,
  ) async {
    await _pump(tester);
    expect(find.textContaining('200'), findsOneWidget);
    expect(find.text('EAN32'), findsOneWidget);
    expect(find.textContaining('Tank 1'), findsOneWidget);
    expect(find.byType(TankEditor), findsNothing);
  });

  testWidgets('Edit expands inline TankEditor; Done collapses', (tester) async {
    await _pump(tester);
    await tester.tap(find.text('Edit'));
    await tester.pumpAndSettle();
    expect(find.byType(TankEditor), findsOneWidget);
    await tester.tap(find.text('Done'));
    await tester.pumpAndSettle();
    expect(find.byType(TankEditor), findsNothing);
  });

  testWidgets('pressure range scales to fit a phone-width cell', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(360, 800);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);
    await _pump(tester);

    // The full pressure range renders rather than being clipped/abbreviated.
    final pressure = find.text('200→50');
    expect(pressure, findsOneWidget);
    final paragraph = tester.renderObject<RenderParagraph>(pressure);
    expect(paragraph.didExceedMaxLines, isFalse);
    // It stays whole because the dense cell scales it down to fit.
    expect(
      find.ancestor(of: pressure, matching: find.byType(FittedBox)),
      findsOneWidget,
    );
  });
}
