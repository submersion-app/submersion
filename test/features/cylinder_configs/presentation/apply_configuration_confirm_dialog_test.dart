import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:submersion/core/constants/enums.dart';
import 'package:submersion/core/constants/units.dart';
import 'package:submersion/core/utils/unit_formatter.dart';
import 'package:submersion/features/cylinder_configs/domain/services/cylinder_config_applier.dart';
import 'package:submersion/features/cylinder_configs/presentation/widgets/apply_configuration_confirm_dialog.dart';
import 'package:submersion/features/dive_log/domain/entities/dive.dart';
import 'package:submersion/features/settings/presentation/providers/settings_providers.dart';
import 'package:submersion/l10n/arb/app_localizations.dart';

/// The prompt a diver sees before a configuration replaces cylinder specs
/// already on a dive (issue #2563).
void main() {
  const tanks = [
    DiveTank(id: 't1', role: TankRole.diluent, workingPressure: 232),
    DiveTank(id: 't2', role: TankRole.bailout, workingPressure: 207),
    DiveTank(id: 't3', role: TankRole.bailout, workingPressure: 207),
  ];

  // What the dialog resolved to, captured once it closes.
  bool? confirmed;
  setUp(() => confirmed = null);

  Future<void> show(
    WidgetTester tester, {
    required List<OverwriteTank> overwrites,
    UnitFormatter units = const UnitFormatter(AppSettings()),
  }) async {
    await tester.pumpWidget(
      MaterialApp(
        locale: const Locale('en'),
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: Builder(
          builder: (context) => TextButton(
            onPressed: () async {
              confirmed = await confirmCylinderOverwrites(
                context,
                configName: 'JJ trimix',
                overwrites: overwrites,
                tanks: tanks,
                units: units,
              );
            },
            child: const Text('open'),
          ),
        ),
      ),
    );
    await tester.tap(find.text('open'));
    await tester.pumpAndSettle();
  }

  testWidgets('lists each change under the tank number the page shows', (
    tester,
  ) async {
    await show(
      tester,
      overwrites: const [
        OverwriteTank(
          tankId: 't3',
          tankRole: TankRole.bailout,
          tankMaterial: SpecChange(TankMaterial.steel, TankMaterial.aluminum),
          tankName: SpecChange('Old', 'Bailout 2'),
        ),
      ],
    );

    expect(
      find.text('Applying JJ trimix changes cylinders already on this dive:'),
      findsOneWidget,
    );
    // Two bailouts: only the number tells the diver which one changes.
    expect(find.text('Tank 3 · Bailout'), findsOneWidget);
    expect(find.text('Material: Steel → Aluminum'), findsOneWidget);
    expect(find.text('Label: Old → Bailout 2'), findsOneWidget);
    expect(
      find.text('Gas mixes and start pressures already on the dive are kept.'),
      findsOneWidget,
    );
  });

  testWidgets('pressures are shown in the diver\'s units', (tester) async {
    await show(
      tester,
      units: const UnitFormatter(AppSettings(pressureUnit: PressureUnit.psi)),
      overwrites: const [
        OverwriteTank(
          tankId: 't1',
          tankRole: TankRole.diluent,
          workingPressureBar: SpecChange(200, 232),
        ),
      ],
    );

    expect(find.text('Working pressure: 2901 psi → 3365 psi'), findsOneWidget);
  });

  for (final (button, expected) in const [
    ('Replace', true),
    ('Cancel', false),
  ]) {
    testWidgets('$button resolves $expected', (tester) async {
      await show(
        tester,
        overwrites: const [
          OverwriteTank(
            tankId: 't1',
            tankRole: TankRole.diluent,
            volumeL: SpecChange(3, 2),
          ),
        ],
      );

      await tester.tap(find.text(button));
      await tester.pumpAndSettle();

      expect(confirmed, expected);
      expect(find.byType(AlertDialog), findsNothing);
    });
  }
}
