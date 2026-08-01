import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:submersion/core/providers/provider.dart';
import 'package:submersion/features/dive_log/domain/entities/dive.dart'
    show GasMix;
import 'package:submersion/features/gas_calculators/presentation/providers/gas_calculators_providers.dart';
import 'package:submersion/features/gas_calculators/presentation/widgets/gas_blender_calculator.dart';
import 'package:submersion/features/settings/presentation/providers/settings_providers.dart';
import 'package:submersion/l10n/arb/app_localizations.dart';

class _TestSettingsNotifier extends StateNotifier<AppSettings>
    implements SettingsNotifier {
  _TestSettingsNotifier(super.settings);

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

Future<WidgetRef> _pump(WidgetTester tester) async {
  late WidgetRef captured;
  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        settingsProvider.overrideWith(
          (ref) => _TestSettingsNotifier(const AppSettings()),
        ),
      ],
      child: MaterialApp(
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: Scaffold(
          body: Consumer(
            builder: (context, ref, _) {
              captured = ref;
              return const GasBlenderCalculator();
            },
          ),
        ),
      ),
    ),
  );
  await tester.pumpAndSettle();
  return captured;
}

void main() {
  testWidgets('default nitrox target shows the EAN32 fill procedure', (
    tester,
  ) async {
    await _pump(tester);

    // Procedure heading and the target nitrox both render.
    expect(find.text('Fill procedure'), findsOneWidget);
    expect(find.textContaining('EAN32'), findsWidgets);
  });

  testWidgets('a target pressure below the start shows an error', (
    tester,
  ) async {
    final ref = await _pump(tester);

    ref.read(blenderStartPressureProvider.notifier).state = 250;
    await tester.pumpAndSettle();

    expect(find.textContaining('higher than the starting'), findsOneWidget);
    expect(find.text('Fill procedure'), findsNothing);
  });

  testWidgets('a trimix target produces a TMX fill procedure', (tester) async {
    final ref = await _pump(tester);

    ref.read(blenderTargetMixProvider.notifier).state = const GasMix(
      o2: 18,
      he: 45,
    );
    ref.read(blenderFillGas2Provider.notifier).state = const GasMix(
      o2: 0,
      he: 100,
    );
    ref.read(blenderFillGas3Provider.notifier).state = const GasMix(o2: 21);
    await tester.pumpAndSettle();

    expect(find.text('Fill procedure'), findsOneWidget);
    expect(find.textContaining('TMX 18/45'), findsWidgets);
  });
}
