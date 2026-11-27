import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/core/providers/provider.dart';
import 'package:submersion/core/utils/currency_catalog.dart';
import 'package:submersion/features/settings/presentation/providers/settings_providers.dart';
import 'package:submersion/features/settings/presentation/widgets/currency_picker.dart';
import 'package:submersion/l10n/arb/app_localizations.dart';

import '../../../../helpers/mock_providers.dart';

/// The searchable currency picker over the whole ISO 4217 catalog (issue
/// #4997).
void main() {
  Widget host(Widget child, {List<String>? preferred}) => ProviderScope(
    overrides: [
      settingsProvider.overrideWith(
        (ref) => MockSettingsNotifier(
          preferred == null
              ? const AppSettings()
              : AppSettings(preferredCurrencyCodes: preferred),
        ),
      ),
    ],
    child: MaterialApp(
      locale: const Locale('en'),
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      home: Scaffold(body: child),
    ),
  );

  /// Opens [showCurrencyPicker] and records what it returns.
  Future<List<CurrencyChoice?>> open(
    WidgetTester tester, {
    String? current,
    List<String> preferred = const ['EUR', 'USD'],
    String? inheritLabel,
  }) async {
    final results = <CurrencyChoice?>[];
    await tester.pumpWidget(
      host(
        Builder(
          builder: (context) => TextButton(
            onPressed: () async => results.add(
              await showCurrencyPicker(
                context,
                title: 'Currency',
                current: current,
                preferred: preferred,
                inheritLabel: inheritLabel,
              ),
            ),
            child: const Text('open'),
          ),
        ),
      ),
    );
    await tester.tap(find.text('open'));
    await tester.pumpAndSettle();
    return results;
  }

  Future<void> search(WidgetTester tester, String query) async {
    await tester.enterText(
      find.byKey(const Key('currency-picker-search')),
      query,
    );
    await tester.pumpAndSettle();
  }

  testWidgets('lists the preferred currencies first, then the catalog', (
    tester,
  ) async {
    await open(tester);

    expect(find.text('Preferred'), findsOneWidget);
    expect(find.text('All currencies'), findsOneWidget);
    final eur = tester.getTopLeft(find.byKey(const Key('currency-picker-EUR')));
    final usd = tester.getTopLeft(find.byKey(const Key('currency-picker-USD')));
    final all = tester.getTopLeft(find.text('All currencies'));
    expect(eur.dy, lessThan(usd.dy));
    expect(usd.dy, lessThan(all.dy));
    // The catalog follows: AED is its first code.
    expect(find.byKey(const Key('currency-picker-AED')), findsOneWidget);
  });

  testWidgets('a search by name finds the Brazilian real and picks it', (
    tester,
  ) async {
    final results = await open(tester);

    await search(tester, 'brazil');
    expect(find.text('Brazilian real'), findsOneWidget);
    expect(find.text('Preferred'), findsNothing);

    await tester.tap(find.byKey(const Key('currency-picker-BRL')));
    await tester.pumpAndSettle();
    expect(results.single?.code, 'BRL');
  });

  testWidgets('a search that matches nothing says so', (tester) async {
    await open(tester);
    await search(tester, 'qqqq');
    expect(find.text('No currency matches'), findsOneWidget);
  });

  testWidgets('a current code outside the catalog stays listed and checked', (
    tester,
  ) async {
    await open(tester, current: 'xau');
    final tile = find.byKey(const Key('currency-picker-XAU'));
    expect(tile, findsOneWidget);
    expect(
      find.descendant(of: tile, matching: find.byIcon(Icons.check)),
      findsOneWidget,
    );
  });

  testWidgets('the inherit entry picks null', (tester) async {
    final results = await open(
      tester,
      current: 'EUR',
      inheritLabel: 'Use default currency',
    );
    await tester.tap(find.byKey(const Key('currency-picker-inherit')));
    await tester.pumpAndSettle();
    expect(results.single, isNotNull);
    expect(results.single!.code, isNull);
  });

  testWidgets('cancel returns null', (tester) async {
    final results = await open(tester);
    await tester.tap(find.text('Cancel'));
    await tester.pumpAndSettle();
    expect(results.single, isNull);
  });

  testWidgets('every catalog currency is reachable by searching its code', (
    tester,
  ) async {
    await open(tester, preferred: const []);
    for (final currency in kIsoCurrencies.take(5)) {
      await search(tester, currency.code);
      expect(
        find.byKey(Key('currency-picker-${currency.code}')),
        findsOneWidget,
      );
    }
  });

  group('CurrencyPickerField', () {
    testWidgets('shows the code, and the diver preferred list in its picker', (
      tester,
    ) async {
      String? value = 'EUR';
      await tester.pumpWidget(
        host(
          preferred: const ['BRL'],
          StatefulBuilder(
            builder: (context, setState) => CurrencyPickerField(
              value: value,
              label: 'Currency',
              onChanged: (v) => setState(() => value = v),
            ),
          ),
        ),
      );
      expect(find.text('EUR'), findsOneWidget);

      await tester.tap(find.byType(CurrencyPickerField));
      await tester.pumpAndSettle();
      final brl = tester.getTopLeft(
        find.byKey(const Key('currency-picker-BRL')),
      );
      expect(
        brl.dy,
        lessThan(tester.getTopLeft(find.text('All currencies')).dy),
      );

      await tester.tap(find.byKey(const Key('currency-picker-BRL')));
      await tester.pumpAndSettle();
      expect(value, 'BRL');
      expect(find.text('BRL'), findsOneWidget);
    });

    testWidgets('a null value shows the inherit label', (tester) async {
      await tester.pumpWidget(
        host(
          CurrencyPickerField(
            value: null,
            label: 'Currency',
            inheritLabel: 'Use default currency',
            onChanged: (_) {},
          ),
        ),
      );
      expect(find.text('Use default currency'), findsOneWidget);
    });

    testWidgets('dismissing the picker leaves the value alone', (tester) async {
      final changes = <String?>[];
      await tester.pumpWidget(
        host(
          CurrencyPickerField(
            value: 'EUR',
            label: 'Currency',
            onChanged: changes.add,
          ),
        ),
      );
      await tester.tap(find.byType(CurrencyPickerField));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Cancel'));
      await tester.pumpAndSettle();
      expect(changes, isEmpty);
    });
  });

  group('currency menu entries', () {
    test('filter by code or name', () {
      final entries = currencyMenuEntries(const ['BRL', 'EUR', 'USD']);
      expect(filterCurrencyMenuEntries(entries, 'real').map((e) => e.value), [
        'BRL',
      ]);
      expect(filterCurrencyMenuEntries(entries, 'us').map((e) => e.value), [
        'USD',
      ]);
      expect(filterCurrencyMenuEntries(entries, ''), hasLength(3));
    });
  });
}
