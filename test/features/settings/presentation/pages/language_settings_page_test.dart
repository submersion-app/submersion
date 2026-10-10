import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/core/providers/provider.dart';
import 'package:submersion/features/dive_sites/domain/entities/dive_site.dart';
import 'package:submersion/features/dive_sites/domain/services/site_location_backfill_service.dart';
import 'package:submersion/features/dive_sites/presentation/providers/site_location_backfill_provider.dart';
import 'package:submersion/features/settings/presentation/pages/language_settings_page.dart';
import 'package:submersion/features/settings/presentation/providers/settings_providers.dart';
import 'package:submersion/l10n/arb/app_localizations.dart';

import '../../../../helpers/mock_providers.dart';

/// Records the lookup the place name offer starts and answers "no
/// candidates", which ends the flow at its snackbar without a database.
class _RecordingBackfill extends StateNotifier<BackfillState>
    implements SiteLocationBackfillNotifier {
  _RecordingBackfill() : super(const BackfillIdle());

  final List<SiteLocationLookupMode> counted = [];

  @override
  Future<List<DiveSite>> findCandidates(SiteLocationLookupMode mode) async {
    counted.add(mode);
    return const [];
  }

  @override
  void reset() => state = const BackfillIdle();

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

/// Holds every app language save until [release], as a slow database write
/// would, so a second tap can land before the first offer appears.
class _SlowSaveSettingsNotifier extends MockSettingsNotifier {
  _SlowSaveSettingsNotifier(super.initial);

  final _saved = Completer<void>();

  void release() => _saved.complete();

  @override
  Future<void> setLocale(String locale) async {
    state = state.copyWith(locale: locale);
    await _saved.future;
  }
}

Future<MockSettingsNotifier> _pumpPage(
  WidgetTester tester, {
  AppSettings settings = const AppSettings(),
  _RecordingBackfill? backfill,
  MockSettingsNotifier? notifier,
}) async {
  await tester.binding.setSurfaceSize(const Size(400, 2000));
  addTearDown(() => tester.binding.setSurfaceSize(null));

  notifier ??= MockSettingsNotifier(settings);

  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        settingsProvider.overrideWith((ref) => notifier!),
        siteLocationBackfillProvider.overrideWith(
          (_) => backfill ?? _RecordingBackfill(),
        ),
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

    expect(
      find.byType(ListTile),
      findsNWidgets(LanguageSettingsPage.supportedLocales.length),
    );
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

  // Semantics(selected) already announces the row; a label on the check mark
  // said "selected" a second time, as the light/dark rows did.
  testWidgets('the selected language is announced once', (tester) async {
    await _pumpPage(tester, settings: const AppSettings(locale: 'de'));

    final check = tester.widget<Icon>(find.byIcon(Icons.check));
    expect(check.semanticLabel, isNull);
  });

  testWidgets('tapping a language saves it', (tester) async {
    final notifier = await _pumpPage(tester);

    await tester.tap(find.text('Français'));
    await tester.pumpAndSettle();

    expect(notifier.state.locale, 'fr');
  });

  // Issue #3111: changing the app language leaves place names in the old
  // language unless the diver is offered the switch.
  group('place name offer', () {
    late _RecordingBackfill backfill;

    setUp(() => backfill = _RecordingBackfill());

    Finder offer() => find.byType(AlertDialog);

    testWidgets('a new app language offers to switch place names to it', (
      tester,
    ) async {
      final notifier = await _pumpPage(tester, backfill: backfill);

      await tester.tap(find.text('Deutsch'));
      await tester.pumpAndSettle();

      expect(offer(), findsOneWidget);
      expect(find.text('Store place names in Deutsch?'), findsOneWidget);
      expect(find.text('Keep English'), findsOneWidget);

      await tester.tap(find.text('Switch'));
      await tester.pumpAndSettle();

      expect(notifier.state.locale, 'de');
      expect(notifier.state.placeNameLanguage, 'de');
      // The sites already stored are offered the same repair as a change
      // made in the place name setting itself (#1187).
      expect(backfill.counted, [SiteLocationLookupMode.refreshAll]);
    });

    testWidgets('keeping the old language changes only the app language', (
      tester,
    ) async {
      final notifier = await _pumpPage(tester, backfill: backfill);

      await tester.tap(find.text('Deutsch'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Keep English'));
      await tester.pumpAndSettle();

      expect(notifier.state.locale, 'de');
      expect(notifier.state.placeNameLanguage, 'en');
      expect(backfill.counted, isEmpty);
    });

    testWidgets('no offer when place names are already in that language', (
      tester,
    ) async {
      final notifier = await _pumpPage(
        tester,
        settings: const AppSettings(placeNameLanguage: 'de'),
        backfill: backfill,
      );

      await tester.tap(find.text('Deutsch'));
      await tester.pumpAndSettle();

      expect(offer(), findsNothing);
      expect(notifier.state.locale, 'de');
    });

    testWidgets('no offer when the same app language is picked again', (
      tester,
    ) async {
      await _pumpPage(
        tester,
        settings: const AppSettings(locale: 'de'),
        backfill: backfill,
      );

      await tester.tap(find.text('Deutsch'));
      await tester.pumpAndSettle();

      expect(offer(), findsNothing);
    });

    // Two taps before the first offer appears must not run two flows: the
    // later offer could otherwise leave place names in the earlier language.
    testWidgets('a second tap while a selection runs is ignored', (
      tester,
    ) async {
      final notifier = _SlowSaveSettingsNotifier(const AppSettings());
      await _pumpPage(tester, backfill: backfill, notifier: notifier);

      await tester.tap(find.text('Deutsch'));
      await tester.pump();
      await tester.tap(find.text('Français'));
      await tester.pump();
      notifier.release();
      await tester.pumpAndSettle();

      expect(offer(), findsOneWidget);
      expect(notifier.state.locale, 'de');
    });

    testWidgets('System Default offers the device language', (tester) async {
      tester.binding.platformDispatcher.localesTestValue = const [
        Locale('fr', 'FR'),
      ];
      addTearDown(tester.binding.platformDispatcher.clearLocalesTestValue);
      final notifier = await _pumpPage(
        tester,
        settings: const AppSettings(locale: 'en'),
        backfill: backfill,
      );

      await tester.tap(find.text('System Default'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Switch'));
      await tester.pumpAndSettle();

      expect(notifier.state.locale, 'system');
      expect(notifier.state.placeNameLanguage, 'fr');
    });
  });
}
