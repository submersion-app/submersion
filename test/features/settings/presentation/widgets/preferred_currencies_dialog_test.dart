import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/core/providers/provider.dart';
import 'package:submersion/core/utils/currency.dart';
import 'package:submersion/features/settings/presentation/providers/settings_providers.dart';
import 'package:submersion/features/settings/presentation/widgets/preferred_currencies_dialog.dart';
import 'package:submersion/l10n/arb/app_localizations.dart';

import '../../../../helpers/mock_providers.dart';

/// Choosing the currencies every picker lists first (issue #4997).
void main() {
  late ProviderContainer container;

  setUp(() {
    container = ProviderContainer(
      overrides: [
        settingsProvider.overrideWith(
          (ref) => MockSettingsNotifier(
            const AppSettings(preferredCurrencyCodes: ['EUR', 'USD']),
          ),
        ),
      ],
    );
    addTearDown(container.dispose);
  });

  Future<void> open(WidgetTester tester) async {
    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: MaterialApp(
          locale: const Locale('en'),
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: Scaffold(
            body: Consumer(
              builder: (context, ref, _) => TextButton(
                onPressed: () => showPreferredCurrenciesDialog(context, ref),
                child: const Text('open'),
              ),
            ),
          ),
        ),
      ),
    );
    await tester.tap(find.text('open'));
    await tester.pumpAndSettle();
  }

  List<String> saved() => container.read(preferredCurrencyCodesProvider);

  Future<void> search(WidgetTester tester, String query) async {
    await tester.enterText(
      find.byKey(const Key('preferred-currencies-search')),
      query,
    );
    await tester.pumpAndSettle();
  }

  Future<void> tapCode(WidgetTester tester, String code) async {
    await tester.tap(find.byKey(Key('preferred-currency-$code')));
    await tester.pumpAndSettle();
  }

  testWidgets('the chosen currencies open ticked and lead the list', (
    tester,
  ) async {
    await open(tester);
    final eur = find.byKey(const Key('preferred-currency-EUR'));
    final checkbox = tester.widget<Checkbox>(
      find.descendant(of: eur, matching: find.byType(Checkbox)),
    );
    expect(checkbox.value, isTrue);
    expect(
      tester.getTopLeft(eur).dy,
      lessThan(
        tester.getTopLeft(find.byKey(const Key('preferred-currency-AED'))).dy,
      ),
    );
  });

  testWidgets('ticking a found currency appends it, and saving stores it', (
    tester,
  ) async {
    await open(tester);
    await search(tester, 'real');
    await tapCode(tester, 'BRL');
    await tester.tap(find.text('Save'));
    await tester.pumpAndSettle();
    expect(saved(), ['EUR', 'USD', 'BRL']);
  });

  testWidgets('unticking removes a currency', (tester) async {
    await open(tester);
    await tapCode(tester, 'EUR');
    await tester.tap(find.text('Save'));
    await tester.pumpAndSettle();
    expect(saved(), ['USD']);
  });

  testWidgets('reset restores the built-in list', (tester) async {
    await open(tester);
    await tester.tap(find.byTooltip('Reset to defaults'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Save'));
    await tester.pumpAndSettle();
    expect(saved(), kDefaultPreferredCurrencyCodes);
  });

  testWidgets('cancel keeps the stored choice', (tester) async {
    await open(tester);
    await tapCode(tester, 'EUR');
    await tester.tap(find.text('Cancel'));
    await tester.pumpAndSettle();
    expect(saved(), ['EUR', 'USD']);
  });
}
