import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:submersion/core/constants/units.dart';
import 'package:submersion/core/providers/provider.dart';
import 'package:submersion/features/settings/presentation/providers/settings_providers.dart';
import 'package:submersion/features/tank_presets/presentation/widgets/default_start_pressure_tile.dart';
import 'package:submersion/l10n/arb/app_localizations.dart';

import '../../../../helpers/mock_providers.dart';

void main() {
  Future<MockSettingsNotifier> pump(
    WidgetTester tester, {
    PressureUnit pressureUnit = PressureUnit.bar,
  }) async {
    final settings = MockSettingsNotifier(
      AppSettings(pressureUnit: pressureUnit),
    );
    await tester.pumpWidget(
      ProviderScope(
        overrides: [settingsProvider.overrideWith((ref) => settings)],
        child: const MaterialApp(
          locale: Locale('en'),
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: Scaffold(body: DefaultStartPressureTile()),
        ),
      ),
    );
    await tester.pumpAndSettle();
    return settings;
  }

  Future<void> enter(WidgetTester tester, String text) async {
    await tester.tap(find.text('Default start pressure'));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextFormField), text);
    await tester.tap(find.text('Save'));
    await tester.pumpAndSettle();
  }

  testWidgets('shows the default in bar', (tester) async {
    await pump(tester);

    expect(find.text('Default start pressure'), findsOneWidget);
    expect(find.text('200 bar'), findsOneWidget);
  });

  testWidgets('shows the default in psi', (tester) async {
    await pump(tester, pressureUnit: PressureUnit.psi);

    expect(find.text('2901 psi'), findsOneWidget);
  });

  testWidgets('saves a value entered in bar', (tester) async {
    final settings = await pump(tester);

    await enter(tester, '232');

    expect(settings.state.defaultStartPressure, 232);
    expect(find.byType(AlertDialog), findsNothing);
  });

  testWidgets('keeps a value entered in psi exactly', (tester) async {
    final settings = await pump(tester, pressureUnit: PressureUnit.psi);

    await enter(tester, '3000');

    // 3000 psi is 206.84 bar. Stored as a decimal since v275, so it reads
    // back as 3000 psi rather than the 3002 psi whole bar would give.
    expect(settings.state.defaultStartPressure, closeTo(206.843, 0.001));
    expect(find.text('3000 psi'), findsOneWidget);
  });

  testWidgets('keeps a decimal entered in bar', (tester) async {
    final settings = await pump(tester);

    await enter(tester, '232.5');

    expect(settings.state.defaultStartPressure, 232.5);
  });

  testWidgets('saving without editing keeps the exact stored value', (
    tester,
  ) async {
    // 206.8428 bar (3000 psi) opens in bar as 206.8. Saving that text would
    // store 206.8 and read back as 2999 psi.
    final settings = MockSettingsNotifier(
      const AppSettings(defaultStartPressure: 206.8428),
    );
    await tester.pumpWidget(
      ProviderScope(
        overrides: [settingsProvider.overrideWith((ref) => settings)],
        child: const MaterialApp(
          locale: Locale('en'),
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: Scaffold(body: DefaultStartPressureTile()),
        ),
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.text('Default start pressure'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Save'));
    await tester.pumpAndSettle();

    expect(find.byType(AlertDialog), findsNothing);
    expect(settings.state.defaultStartPressure, 206.8428);
  });

  testWidgets('reopening shows the value as it was entered', (tester) async {
    await pump(tester, pressureUnit: PressureUnit.psi);
    await enter(tester, '3000');

    await tester.tap(find.text('Default start pressure'));
    await tester.pumpAndSettle();

    expect(
      tester.widget<TextFormField>(find.byType(TextFormField)).controller!.text,
      '3000',
    );
  });

  testWidgets('refuses zero and keeps the dialog open', (tester) async {
    final settings = await pump(tester);

    await enter(tester, '0');

    expect(find.byType(AlertDialog), findsOneWidget);
    expect(find.text('Enter a pressure from 1 bar to 400 bar'), findsOneWidget);
    expect(settings.state.defaultStartPressure, 200);
  });

  testWidgets('refuses a value that only rounds into the range', (
    tester,
  ) async {
    final settings = await pump(tester);

    await enter(tester, '0.5');

    expect(find.text('Enter a pressure from 1 bar to 400 bar'), findsOneWidget);
    expect(settings.state.defaultStartPressure, 200);
  });

  testWidgets('refuses a value just past the top of the range', (tester) async {
    final settings = await pump(tester);

    await enter(tester, '400.4');

    expect(find.byType(AlertDialog), findsOneWidget);
    expect(settings.state.defaultStartPressure, 200);
  });

  testWidgets('accepts both ends of the range as the message shows them', (
    tester,
  ) async {
    final settings = await pump(tester, pressureUnit: PressureUnit.psi);

    await enter(tester, '5802');
    expect(settings.state.defaultStartPressure, 400);

    await enter(tester, '15');
    expect(settings.state.defaultStartPressure, closeTo(1.034, 0.001));
  });

  testWidgets('refuses a pressure above the range', (tester) async {
    final settings = await pump(tester, pressureUnit: PressureUnit.psi);

    await enter(tester, '9000');

    expect(
      find.text('Enter a pressure from 15 psi to 5802 psi'),
      findsOneWidget,
    );
    expect(settings.state.defaultStartPressure, 200);
  });

  testWidgets('cancel changes nothing', (tester) async {
    final settings = await pump(tester);

    await tester.tap(find.text('Default start pressure'));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextFormField), '300');
    await tester.tap(find.text('Cancel'));
    await tester.pumpAndSettle();

    expect(find.byType(AlertDialog), findsNothing);
    expect(settings.state.defaultStartPressure, 200);
  });

  testWidgets('refuses unreadable text', (tester) async {
    final settings = await pump(tester);

    await enter(tester, 'abc');

    expect(find.byType(AlertDialog), findsOneWidget);
    expect(settings.state.defaultStartPressure, 200);
  });
}
