import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:submersion/core/constants/enums.dart';
import 'package:submersion/core/providers/provider.dart';
import 'package:submersion/features/dive_log/domain/entities/dive.dart';
import 'package:submersion/features/dive_log/presentation/pages/dive_detail_page.dart';
import 'package:submersion/features/dive_log/presentation/providers/dive_providers.dart';
import 'package:submersion/features/dive_log/presentation/widgets/dive_detail_row.dart';
import 'package:submersion/features/dive_log/presentation/widgets/environment_enum_display.dart';
import 'package:submersion/features/dive_sites/domain/entities/dive_site.dart';
import 'package:submersion/features/divers/presentation/providers/diver_providers.dart';
import 'package:submersion/features/settings/presentation/providers/settings_providers.dart';
import 'package:submersion/l10n/arb/app_localizations.dart';

import '../../../../helpers/mock_providers.dart';

/// Issue #1427: a dive that never recorded a water type or entry method of its
/// own shows the ones its site carries, so the value the statistics now count
/// is the same one the diver can see on the dive.
void main() {
  DiveSite siteWith({WaterType? waterType, EntryMethod? entryMethod}) =>
      DiveSite(
        id: 'site-1',
        name: 'Blue Hole',
        waterType: waterType,
        entryMethods: [?entryMethod],
      );

  Dive diveWith({
    WaterType? waterType,
    EntryMethod? entryMethod,
    DiveSite? site,
  }) => createTestDiveWithBottomTime().copyWith(
    waterType: waterType,
    entryMethod: entryMethod,
    site: site,
  );

  /// The detail page renders a profile chart that can overflow an
  /// unconstrained test viewport. Ignore only that, and forward everything
  /// else, so a real rendering failure still fails the test.
  void ignoreOverflowErrors() {
    final originalOnError = FlutterError.onError;
    addTearDown(() => FlutterError.onError = originalOnError);
    FlutterError.onError = (details) {
      if (details.toString().contains('overflowed')) return;
      originalOnError?.call(details);
    };
  }

  Future<void> pumpWith(WidgetTester tester, Dive dive) async {
    SharedPreferences.setMockInitialValues({});
    final prefs = await SharedPreferences.getInstance();

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          sharedPreferencesProvider.overrideWithValue(prefs),
          settingsProvider.overrideWith(
            (ref) => MockSettingsNotifier(const AppSettings()),
          ),
          currentDiverIdProvider.overrideWith(
            (ref) => MockCurrentDiverIdNotifier(),
          ),
          diveProvider(dive.id).overrideWith((ref) async => dive),
        ],
        child: MaterialApp(
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: DiveDetailPage(diveId: dive.id, embedded: true),
        ),
      ),
    );

    ignoreOverflowErrors();
    await tester.pump();
    await tester.pump(const Duration(seconds: 1));
  }

  AppLocalizations l10nOf(WidgetTester tester) =>
      AppLocalizations.of(tester.element(find.byType(DiveDetailPage)));

  Finder rowValued(String value) => find.widgetWithText(DiveDetailRow, value);

  testWidgets('water type falls back to the site', (tester) async {
    await pumpWith(tester, diveWith(site: siteWith(waterType: WaterType.salt)));

    expect(rowValued(WaterType.salt.displayName), findsOneWidget);
  });

  testWidgets("water type prefers the dive's own value", (tester) async {
    await pumpWith(
      tester,
      diveWith(
        waterType: WaterType.fresh,
        site: siteWith(waterType: WaterType.salt),
      ),
    );

    expect(rowValued(WaterType.fresh.displayName), findsOneWidget);
    expect(rowValued(WaterType.salt.displayName), findsNothing);
  });

  testWidgets('no water type anywhere shows no water type row', (tester) async {
    await pumpWith(tester, diveWith(site: siteWith()));

    final label = l10nOf(tester).diveLog_detail_label_waterType;
    expect(find.widgetWithText(DiveDetailRow, label), findsNothing);
  });

  testWidgets('entry method falls back to the site', (tester) async {
    // Also proves the section gate opens: the environment section is hidden
    // unless something in it has a value, so an inherited-only entry method
    // needs the gate to read the effective value too.
    await pumpWith(
      tester,
      diveWith(site: siteWith(entryMethod: EntryMethod.shore)),
    );

    final l10n = l10nOf(tester);
    expect(
      find.widgetWithText(DiveDetailRow, EntryMethod.shore.localizedName(l10n)),
      findsOneWidget,
    );
  });

  testWidgets("entry method prefers the dive's own value", (tester) async {
    await pumpWith(
      tester,
      diveWith(
        entryMethod: EntryMethod.boat,
        site: siteWith(entryMethod: EntryMethod.shore),
      ),
    );

    final l10n = l10nOf(tester);
    expect(
      find.widgetWithText(DiveDetailRow, EntryMethod.boat.localizedName(l10n)),
      findsOneWidget,
    );
    expect(
      find.widgetWithText(DiveDetailRow, EntryMethod.shore.localizedName(l10n)),
      findsNothing,
    );
  });

  testWidgets('exit method is not inherited from the site', (tester) async {
    // Its snap-on-assign rule depends on the exit/entry link flag, which is
    // form state and never persisted, so there is nothing to derive from.
    await pumpWith(
      tester,
      diveWith(site: siteWith(entryMethod: EntryMethod.shore)),
    );

    final label = l10nOf(tester).diveLog_detail_label_exitMethod;
    expect(find.widgetWithText(DiveDetailRow, label), findsNothing);
  });
}
