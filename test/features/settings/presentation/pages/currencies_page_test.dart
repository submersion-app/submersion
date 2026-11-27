import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/core/providers/provider.dart';
import 'package:submersion/core/utils/currency.dart';
import 'package:submersion/core/utils/currency_catalog.dart';
import 'package:submersion/features/settings/presentation/pages/currencies_page.dart';
import 'package:submersion/features/settings/presentation/providers/settings_providers.dart';
import 'package:submersion/l10n/arb/app_localizations.dart';

import '../../../../helpers/mock_providers.dart';

/// The one place a diver manages currencies (issue #4997): the enabled ones
/// every picker lists first, their order, and the default.
void main() {
  late MockSettingsNotifier notifier;

  Future<void> pump(WidgetTester tester, AppSettings settings) async {
    notifier = MockSettingsNotifier(settings);
    await tester.pumpWidget(
      ProviderScope(
        overrides: [settingsProvider.overrideWith((ref) => notifier)],
        child: const MaterialApp(
          locale: Locale('en'),
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: CurrenciesPage(),
        ),
      ),
    );
    await tester.pumpAndSettle();
  }

  Finder enabledRow(String code) =>
      find.byKey(ValueKey('currency-enabled-$code'));
  Finder otherRow(String code) => find.byKey(ValueKey('currency-other-$code'));

  Switch switchOf(WidgetTester tester, String code) =>
      tester.widget<Switch>(find.byKey(Key('currency-switch-$code')));

  testWidgets('enabled currencies lead in order, the default starred and '
      'locked on', (tester) async {
    await pump(
      tester,
      const AppSettings(
        defaultCurrency: 'EUR',
        preferredCurrencyCodes: ['USD', 'EUR', 'BRL'],
      ),
    );

    final ys = [
      for (final code in ['USD', 'EUR', 'BRL'])
        tester.getTopLeft(enabledRow(code)).dy,
    ];
    expect(ys, orderedEquals([...ys]..sort()));
    expect(
      find.descendant(of: enabledRow('EUR'), matching: find.byIcon(Icons.star)),
      findsOneWidget,
    );
    expect(
      find.descendant(
        of: enabledRow('EUR'),
        matching: find.text('Default · Euro'),
      ),
      findsOneWidget,
    );
    expect(switchOf(tester, 'EUR').onChanged, isNull);
    expect(switchOf(tester, 'USD').onChanged, isNotNull);
    // An enabled currency is not repeated among the others.
    expect(otherRow('USD'), findsNothing);
  });

  testWidgets('the star makes a currency the default', (tester) async {
    await pump(
      tester,
      const AppSettings(
        defaultCurrency: 'USD',
        preferredCurrencyCodes: ['USD', 'EUR'],
      ),
    );

    await tester.tap(find.byKey(const Key('currency-default-EUR')));
    await tester.pumpAndSettle();

    expect(notifier.state.defaultCurrency, 'EUR');
    expect(switchOf(tester, 'EUR').onChanged, isNull);
    expect(switchOf(tester, 'USD').onChanged, isNotNull);
  });

  testWidgets('switching a currency off moves it to the others', (
    tester,
  ) async {
    await pump(
      tester,
      const AppSettings(
        defaultCurrency: 'USD',
        preferredCurrencyCodes: ['USD', 'EUR', 'AED'],
      ),
    );

    await tester.tap(find.byKey(const Key('currency-switch-AED')));
    await tester.pumpAndSettle();

    expect(notifier.state.preferredCurrencyCodes, ['USD', 'EUR']);
    expect(enabledRow('AED'), findsNothing);
    expect(otherRow('AED'), findsOneWidget);
  });

  testWidgets('any ISO currency can be found and enabled (issue #4997)', (
    tester,
  ) async {
    await pump(
      tester,
      const AppSettings(
        defaultCurrency: 'USD',
        preferredCurrencyCodes: ['USD', 'EUR'],
      ),
    );

    await tester.enterText(
      find.byKey(const Key('currencies-search')),
      'brazil',
    );
    await tester.pumpAndSettle();
    expect(otherRow('BRL'), findsOneWidget);
    expect(otherRow('AED'), findsNothing);

    await tester.tap(
      find.descendant(of: otherRow('BRL'), matching: find.byType(Switch)),
    );
    await tester.pumpAndSettle();

    expect(notifier.state.preferredCurrencyCodes, ['USD', 'EUR', 'BRL']);
    expect(enabledRow('BRL'), findsOneWidget);
  });

  testWidgets('tapping another currency\'s row enables it too', (tester) async {
    await pump(
      tester,
      const AppSettings(
        defaultCurrency: 'USD',
        preferredCurrencyCodes: ['USD'],
      ),
    );

    await tester.enterText(find.byKey(const Key('currencies-search')), 'zloty');
    await tester.pumpAndSettle();
    await tester.tap(otherRow('PLN'));
    await tester.pumpAndSettle();

    expect(notifier.state.preferredCurrencyCodes, ['USD', 'PLN']);
  });

  testWidgets('a search with no match says so', (tester) async {
    await pump(
      tester,
      const AppSettings(
        defaultCurrency: 'USD',
        preferredCurrencyCodes: ['USD'],
      ),
    );

    await tester.enterText(find.byKey(const Key('currencies-search')), 'qqq');
    await tester.pumpAndSettle();

    expect(find.text('No currency matches'), findsOneWidget);
  });

  testWidgets('dragging a handle reorders the enabled currencies', (
    tester,
  ) async {
    await pump(
      tester,
      const AppSettings(
        defaultCurrency: 'USD',
        preferredCurrencyCodes: ['USD', 'EUR', 'GBP'],
      ),
    );

    final handle = find.descendant(
      of: enabledRow('GBP'),
      matching: find.byIcon(Icons.drag_handle),
    );
    final gesture = await tester.startGesture(tester.getCenter(handle));
    await tester.pump();
    for (var i = 0; i < 8; i++) {
      await gesture.moveBy(const Offset(0, -20));
      await tester.pump(const Duration(milliseconds: 50));
    }
    await gesture.up();
    await tester.pumpAndSettle();

    expect(notifier.state.preferredCurrencyCodes, ['GBP', 'USD', 'EUR']);
  });

  testWidgets('reset restores the built-in list', (tester) async {
    await pump(
      tester,
      const AppSettings(
        defaultCurrency: 'USD',
        preferredCurrencyCodes: ['USD', 'BRL'],
      ),
    );

    await tester.tap(find.byKey(const Key('currencies-reset')));
    await tester.pumpAndSettle();

    expect(
      notifier.state.preferredCurrencyCodes,
      kDefaultPreferredCurrencyCodes,
    );
  });

  testWidgets('a default outside the stored list is shown enabled and kept '
      'when the list changes', (tester) async {
    await pump(
      tester,
      const AppSettings(
        defaultCurrency: 'BRL',
        preferredCurrencyCodes: ['EUR', 'USD'],
      ),
    );

    expect(enabledRow('BRL'), findsOneWidget);
    expect(otherRow('BRL'), findsNothing);

    await tester.tap(find.byKey(const Key('currency-switch-EUR')));
    await tester.pumpAndSettle();

    expect(notifier.state.preferredCurrencyCodes, ['BRL', 'USD']);
  });

  for (final (label, size) in [
    ('phone', const Size(375, 812)),
    ('desktop', const Size(1280, 900)),
  ]) {
    testWidgets('every currency enabled lays out on a $label', (tester) async {
      tester.view.physicalSize = size;
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);

      await pump(
        tester,
        AppSettings(
          defaultCurrency: 'AED',
          preferredCurrencyCodes: [for (final c in kIsoCurrencies) c.code],
        ),
      );

      expect(tester.takeException(), isNull);
      expect(enabledRow('AED'), findsOneWidget);
      await tester.scrollUntilVisible(
        find.text('No currency matches'),
        2000,
        scrollable: find.byType(Scrollable).first,
      );
      expect(tester.takeException(), isNull);
    });
  }
}
