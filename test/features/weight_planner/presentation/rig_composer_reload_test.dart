import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/core/constants/enums.dart';
import 'package:submersion/core/constants/tank_presets.dart';
import 'package:submersion/core/providers/provider.dart';
import 'package:submersion/core/utils/unit_formatter.dart';
import 'package:submersion/features/settings/presentation/providers/settings_providers.dart';
import 'package:submersion/features/tank_presets/domain/entities/tank_preset_entity.dart';
import 'package:submersion/features/tank_presets/presentation/providers/tank_preset_providers.dart';
import 'package:submersion/features/weight_planner/presentation/widgets/rig_composer.dart';
import 'package:submersion/l10n/arb/app_localizations.dart';

/// Stands in for the settings change (a preset hidden or shown) that
/// tankPresetsProvider watches since issue #2305.
final _reloadTrigger = StateProvider<int>((ref) => 0);

void main() {
  testWidgets('keeps the presets while a settings change reloads them', (
    tester,
  ) async {
    final presets = TankPresets.all.map(TankPresetEntity.fromBuiltIn).toList();
    var next = Completer<List<TankPresetEntity>>()..complete(presets);
    final controllers = List.generate(4, (_) => TextEditingController());
    addTearDown(() {
      for (final c in controllers) {
        c.dispose();
      }
    });

    final container = ProviderContainer(
      overrides: [
        tankPresetsProvider.overrideWith((ref) {
          ref.watch(_reloadTrigger);
          return next.future;
        }),
      ],
    );
    addTearDown(container.dispose);

    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: MaterialApp(
          locale: const Locale('en'),
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: Scaffold(
            body: SingleChildScrollView(
              child: RigComposer(
                gear: const [],
                tanks: [presets.firstWhere((p) => p.name == 'al80')],
                waterType: WaterType.salt,
                bodyWeightController: controllers[0],
                heightCmController: controllers[1],
                heightFeetController: controllers[2],
                heightInchesController: controllers[3],
                units: const UnitFormatter(AppSettings()),
                showSaveBodyWeight: false,
                onGearAdded: (_) {},
                onGearSetAdded: (_, _) {},
                onGearRemoved: (_) {},
                onTankAdded: (_) {},
                onTankRemoved: (_) {},
                onTankChanged: (_, _) {},
                onWaterChanged: (_) {},
                onSaveBodyWeight: () {},
                onChanged: () {},
              ),
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    // TextButton.icon builds a TextButton subclass, so match by predicate.
    Finder addTank() => find.ancestor(
      of: find.text('Add tank'),
      matching: find.byWidgetPredicate((w) => w is TextButton),
    );
    expect(tester.widget<TextButton>(addTank()).onPressed, isNotNull);

    // A dependency-driven reload: the new list has not arrived yet.
    next = Completer<List<TankPresetEntity>>();
    container.read(_reloadTrigger.notifier).state++;
    await tester.pump();

    expect(container.read(tankPresetsProvider).isLoading, isTrue);
    expect(
      tester.widget<TextButton>(addTank()).onPressed,
      isNotNull,
      reason: 'the previous list stays usable until the reload lands',
    );
    expect(find.text('AL80'), findsOneWidget);

    next.complete(presets);
    await tester.pumpAndSettle();
  });
}
