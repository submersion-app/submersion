import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:submersion/core/providers/provider.dart';
import 'package:submersion/features/settings/presentation/providers/settings_providers.dart';
import 'package:submersion/l10n/arb/app_localizations.dart';

void main() {
  group('AppLocalizations delegate', () {
    test('loads all 10 supported locales without error', () async {
      for (final locale in AppLocalizations.supportedLocales) {
        final l10n = await AppLocalizations.delegate.load(locale);
        expect(l10n, isNotNull);
        expect(l10n.localeName, locale.languageCode);
      }
    });

    test('supports exactly 10 locales', () {
      expect(AppLocalizations.supportedLocales.length, 10);
      final codes = AppLocalizations.supportedLocales
          .map((l) => l.languageCode)
          .toSet();
      expect(
        codes,
        containsAll([
          'en',
          'es',
          'fr',
          'de',
          'it',
          'nl',
          'pt',
          'ar',
          'he',
          'hu',
        ]),
      );
    });
  });

  group('English baseline strings', () {
    late AppLocalizations l10n;

    setUpAll(() async {
      l10n = await AppLocalizations.delegate.load(const Locale('en'));
    });

    test('common actions are English', () {
      expect(l10n.common_action_save, 'Save');
      expect(l10n.common_action_cancel, 'Cancel');
      expect(l10n.common_action_delete, 'Delete');
      expect(l10n.common_action_close, 'Close');
    });

    test('formatter connectors are English', () {
      expect(l10n.formatter_connector_at, 'at');
      expect(l10n.formatter_connector_from, 'From');
      expect(l10n.formatter_connector_until, 'Until');
    });
  });

  group('Translated strings differ from English', () {
    late AppLocalizations en;

    setUpAll(() async {
      en = await AppLocalizations.delegate.load(const Locale('en'));
    });

    for (final code in ['es', 'fr', 'de', 'it', 'nl', 'pt', 'ar', 'he', 'hu']) {
      test('$code has translated common_action_save', () async {
        final l10n = await AppLocalizations.delegate.load(Locale(code));
        // At least one of the common actions should differ from English
        final hasTranslation =
            l10n.common_action_save != en.common_action_save ||
            l10n.common_action_cancel != en.common_action_cancel ||
            l10n.common_action_delete != en.common_action_delete;
        expect(
          hasTranslation,
          isTrue,
          reason: '$code should have at least one translated common action',
        );
      });
    }
  });

  group('Connector word translations', () {
    test('Spanish connector "at" is translated', () async {
      final l10n = await AppLocalizations.delegate.load(const Locale('es'));
      expect(l10n.formatter_connector_at, isNot('at'));
    });

    test('French connector "at" is translated', () async {
      final l10n = await AppLocalizations.delegate.load(const Locale('fr'));
      expect(l10n.formatter_connector_at, isNot('at'));
    });

    test('German connector "at" is translated', () async {
      final l10n = await AppLocalizations.delegate.load(const Locale('de'));
      expect(l10n.formatter_connector_at, isNot('at'));
    });

    test('Arabic connector "at" is translated', () async {
      final l10n = await AppLocalizations.delegate.load(const Locale('ar'));
      expect(l10n.formatter_connector_at, isNot('at'));
    });

    test('Hebrew connector "at" is translated', () async {
      final l10n = await AppLocalizations.delegate.load(const Locale('he'));
      expect(l10n.formatter_connector_at, isNot('at'));
    });
  });

  group('Locale switching via widget', () {
    testWidgets('renders English strings with en locale', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          locale: Locale('en'),
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: _LocaleTestWidget(),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('Save'), findsOneWidget);
    });

    testWidgets('renders Spanish strings with es locale', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          locale: Locale('es'),
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: _LocaleTestWidget(),
        ),
      );
      await tester.pumpAndSettle();

      // Should NOT be English
      expect(find.text('Save'), findsNothing);
    });

    testWidgets('renders Arabic strings with ar locale', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          locale: Locale('ar'),
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: _LocaleTestWidget(),
        ),
      );
      await tester.pumpAndSettle();

      // Should NOT be English
      expect(find.text('Save'), findsNothing);
    });
  });

  group('Locale provider integration', () {
    testWidgets('localeProvider defaults to system', (tester) async {
      SharedPreferences.setMockInitialValues({});
      final prefs = await SharedPreferences.getInstance();

      late String localeValue;

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            sharedPreferencesProvider.overrideWithValue(prefs),
            settingsProvider.overrideWith((ref) => _TestSettingsNotifier()),
          ],
          child: Consumer(
            builder: (context, ref, _) {
              localeValue = ref.watch(localeProvider);
              return const SizedBox.shrink();
            },
          ),
        ),
      );

      expect(localeValue, 'system');
    });
  });

  group('RTL text direction', () {
    testWidgets('Arabic locale uses RTL direction', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          locale: Locale('ar'),
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: _DirectionTestWidget(),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('rtl'), findsOneWidget);
    });

    testWidgets('Hebrew locale uses RTL direction', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          locale: Locale('he'),
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: _DirectionTestWidget(),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('rtl'), findsOneWidget);
    });

    testWidgets('English locale uses LTR direction', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          locale: Locale('en'),
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: _DirectionTestWidget(),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('ltr'), findsOneWidget);
    });
  });
}

/// Test widget that displays a localized string
class _LocaleTestWidget extends StatelessWidget {
  const _LocaleTestWidget();

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return Scaffold(body: Text(l10n.common_action_save));
  }
}

/// Test widget that displays the current text direction
class _DirectionTestWidget extends StatelessWidget {
  const _DirectionTestWidget();

  @override
  Widget build(BuildContext context) {
    final direction = Directionality.of(context);
    return Scaffold(body: Text(direction == TextDirection.rtl ? 'rtl' : 'ltr'));
  }
}

/// Minimal mock SettingsNotifier for provider tests
class _TestSettingsNotifier extends StateNotifier<AppSettings>
    implements SettingsNotifier {
  _TestSettingsNotifier() : super(const AppSettings());

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}
