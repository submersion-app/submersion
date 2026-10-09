import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:submersion/core/providers/provider.dart';
import 'package:submersion/features/settings/presentation/pages/language_settings_page.dart';
import 'package:submersion/features/settings/presentation/providers/settings_providers.dart';
import 'package:submersion/l10n/arb/app_localizations.dart';

import '../../../../helpers/mock_providers.dart';

Future<MockSettingsNotifier> _pumpPage(
  WidgetTester tester, {
  AppSettings settings = const AppSettings(),
}) async {
  await tester.binding.setSurfaceSize(const Size(400, 2000));
  addTearDown(() => tester.binding.setSurfaceSize(null));

  SharedPreferences.setMockInitialValues({});
  final prefs = await SharedPreferences.getInstance();
  final notifier = MockSettingsNotifier(settings);

  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        settingsProvider.overrideWith((ref) => notifier),
        sharedPreferencesProvider.overrideWithValue(prefs),
      ],
      child: const MaterialApp(
        locale: Locale('en'),
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: LanguageSettingsPage(),
      ),
    ),
  );
  await tester.pumpAndSettle();
  return notifier;
}

Finder _selectedRowOf(String title) => find.ancestor(
  of: find.text(title),
  matching: find.byWidgetPredicate(
    (w) => w is Semantics && w.properties.selected == true,
  ),
);

void main() {
  testWidgets('lists System Default and every supported language', (
    tester,
  ) async {
    await _pumpPage(tester);

    expect(find.byType(ListTile), findsNWidgets(12));
    expect(find.text('System Default'), findsOneWidget);
    expect(find.text('Deutsch'), findsOneWidget);
    expect(find.text('German'), findsOneWidget);
  });

  testWidgets('marks only the current language as selected', (tester) async {
    await _pumpPage(tester, settings: const AppSettings(locale: 'de'));

    expect(_selectedRowOf('Deutsch'), findsOneWidget);
    expect(_selectedRowOf('English'), findsNothing);
    expect(find.byIcon(Icons.check), findsOneWidget);
  });

  testWidgets('tapping a language saves it', (tester) async {
    final notifier = await _pumpPage(tester);

    await tester.tap(find.text('Français'));
    await tester.pumpAndSettle();

    expect(notifier.state.locale, 'fr');
  });
}
