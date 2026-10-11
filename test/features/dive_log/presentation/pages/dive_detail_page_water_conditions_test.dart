import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:intl/intl.dart' show Intl;
// ignore: implementation_imports
import 'package:riverpod/src/framework.dart' as riverpod show Override;
import 'package:shared_preferences/shared_preferences.dart';
import 'package:submersion/core/constants/dive_detail_sections.dart';
import 'package:submersion/core/constants/enums.dart';
import 'package:submersion/core/providers/provider.dart';
import 'package:submersion/features/buddies/presentation/providers/buddy_providers.dart';
import 'package:submersion/features/dive_log/domain/entities/dive.dart';
import 'package:submersion/features/dive_log/domain/entities/dive_data_source.dart';
import 'package:submersion/features/dive_log/presentation/pages/dive_detail_page.dart';
import 'package:submersion/features/dive_log/presentation/providers/dive_providers.dart';
import 'package:submersion/features/dive_log/presentation/widgets/responsive_section_pair.dart';
import 'package:submersion/features/dive_sites/domain/entities/dive_site.dart';
import 'package:submersion/features/marine_life/domain/entities/species.dart';
import 'package:submersion/features/marine_life/presentation/providers/species_providers.dart';
import 'package:submersion/features/reef/domain/entities/reef_data_status.dart';
import 'package:submersion/features/reef/domain/entities/reef_habitat.dart';
import 'package:submersion/features/reef/domain/entities/reef_health.dart';
import 'package:submersion/features/reef/domain/services/bleaching_alert_level.dart';
import 'package:submersion/features/reef/presentation/providers/reef_providers.dart';
import 'package:submersion/features/reef/presentation/widgets/water_conditions_card.dart';
import 'package:submersion/features/settings/presentation/providers/settings_providers.dart';
import 'package:submersion/features/signatures/domain/entities/signature.dart';
import 'package:submersion/features/signatures/presentation/providers/signature_providers.dart';
import 'package:submersion/l10n/arb/app_localizations.dart';

import '../../../../helpers/mock_providers.dart';

typedef Override = riverpod.Override;

const _heading = 'Water conditions';
const _seaSurface = 'Sea surface 30.1°C';

final _health = ReefHealth(
  sst: 30.1,
  sstAnomaly: 0.8,
  degreeHeatingWeeks: 4.2,
  alertLevel: BleachingAlertLevel.watch,
  observedAt: DateTime.utc(2023, 9, 1, 12),
);

DiveSite _site({WaterType? waterType = WaterType.salt}) => DiveSite(
  id: 'site-reef',
  name: 'Coral Garden',
  location: const GeoPoint(-16.5, 145.8),
  waterType: waterType,
);

/// A dive at a reef site with no logged weather or conditions, so any
/// Environment card it gets comes from satellite data alone.
Dive _satelliteOnlyDive(String id, {DiveSite? site}) =>
    Dive(id: id, dateTime: DateTime(2023, 9, 1, 10), site: site ?? _site());

/// The same dive with logged air temperature and current.
Dive _loggedDive(String id) => _satelliteOnlyDive(
  id,
).copyWith(airTemp: 29.0, currentStrength: CurrentStrength.moderate);

AppSettings _settingsShowing(List<DiveDetailSectionId> visible) => AppSettings(
  diveDetailSections: [
    for (final id in DiveDetailSectionId.values)
      DiveDetailSectionConfig(id: id, visible: visible.contains(id)),
  ],
);

Widget _page({
  required Dive dive,
  required SharedPreferences prefs,
  ReefPart<ReefHealth>? health,
  ReefPart<ReefHabitat> habitat = const ReefPart.ok(ReefHabitat(onReef: true)),
  List<DiveDetailSectionId> visible = const [DiveDetailSectionId.environment],
}) {
  return ProviderScope(
    overrides: [
      diveProvider(dive.id).overrideWith((ref) async => dive),
      diveDataSourcesProvider(
        dive.id,
      ).overrideWith((ref) async => <DiveDataSource>[]),
      settingsProvider.overrideWith(
        (ref) => MockSettingsNotifier(_settingsShowing(visible)),
      ),
      sharedPreferencesProvider.overrideWithValue(prefs),
      buddiesForDiveProvider(dive.id).overrideWith((ref) async => []),
      diveSightingsProvider(dive.id).overrideWith((ref) async => <Sighting>[]),
      buddySignaturesForDiveProvider(
        dive.id,
      ).overrideWith((ref) async => <Signature>[]),
      surfaceIntervalProvider(dive.id).overrideWith((ref) async => null),
      reefHealthForDiveProvider.overrideWith(
        (ref, request) async => health ?? ReefPart.ok(_health),
      ),
      reefHabitatProvider.overrideWith((ref, location) async => habitat),
    ],
    child: MaterialApp(
      // The assertions are English strings; say so rather than lean on the
      // test binding's default locale.
      locale: const Locale('en'),
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      home: DiveDetailPage(diveId: dive.id),
    ),
  );
}

/// The innermost card holding [text].
Card _cardOf(WidgetTester tester, String text) => tester.widget<Card>(
  find.ancestor(of: find.text(text), matching: find.byType(Card)).first,
);

void main() {
  late SharedPreferences prefs;
  String? previousLocale;

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    prefs = await SharedPreferences.getInstance();
    previousLocale = Intl.defaultLocale;
    Intl.defaultLocale = 'en_US';
  });

  tearDown(() {
    Intl.defaultLocale = previousLocale;
  });

  Future<void> pump(WidgetTester tester, Widget page) async {
    await tester.binding.setSurfaceSize(const Size(1000, 3000));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    await tester.pumpWidget(page);
    await tester.pumpAndSettle();
  }

  group('satellite water conditions in the Environment card', () {
    testWidgets('sit inside the Environment card, after the logged ones', (
      tester,
    ) async {
      await pump(tester, _page(dive: _loggedDive('merged'), prefs: prefs));

      expect(find.text(_heading), findsOneWidget);
      expect(_cardOf(tester, _heading), same(_cardOf(tester, 'Environment')));
      expect(find.text(_seaSurface), findsOneWidget);
      expect(find.text('Anomaly +0.8°C'), findsOneWidget);
      expect(find.text('Bleaching watch'), findsOneWidget);
      expect(find.text('As of Sep 1, 2023'), findsOneWidget);
      // Last: below both of the logged subsections.
      final headingTop = tester.getTopLeft(find.text(_heading)).dy;
      expect(
        headingTop,
        greaterThan(tester.getTopLeft(find.text('Dive Conditions')).dy),
      );
      expect(
        headingTop,
        greaterThan(tester.getTopLeft(find.text('Weather')).dy),
      );
    });

    testWidgets('no longer get a card of their own', (tester) async {
      await pump(tester, _page(dive: _loggedDive('no-own-card'), prefs: prefs));

      expect(find.byType(WaterConditionsCard), findsNothing);
      expect(
        find.ancestor(of: find.text(_seaSurface), matching: find.byType(Card)),
        findsOneWidget,
      );
    });

    testWidgets('give a dive with nothing logged an Environment card', (
      tester,
    ) async {
      await pump(
        tester,
        _page(dive: _satelliteOnlyDive('satellite-only'), prefs: prefs),
      );

      expect(find.text('Environment'), findsOneWidget);
      expect(_cardOf(tester, _heading), same(_cardOf(tester, 'Environment')));
      expect(find.text('Weather'), findsNothing);
      expect(find.text('Dive Conditions'), findsNothing);
    });

    testWidgets('leave out the coral framing where there is no reef', (
      tester,
    ) async {
      await pump(
        tester,
        _page(
          dive: _loggedDive('no-reef'),
          prefs: prefs,
          habitat: const ReefPart.empty(),
        ),
      );

      expect(find.text(_seaSurface), findsOneWidget);
      expect(find.text('Bleaching watch'), findsNothing);
    });

    testWidgets('follow the Environment card when the diver hides it', (
      tester,
    ) async {
      await pump(
        tester,
        _page(
          dive: _loggedDive('hidden'),
          prefs: prefs,
          visible: const [DiveDetailSectionId.details],
        ),
      );

      expect(find.text('Environment'), findsNothing);
      expect(find.text(_heading), findsNothing);
    });
  });

  group('without satellite data', () {
    for (final (name, part) in [
      ('unavailable', const ReefPart<ReefHealth>.unavailable()),
      ('empty', const ReefPart<ReefHealth>.empty()),
    ]) {
      testWidgets('$name: shows the logged conditions only', (tester) async {
        await pump(
          tester,
          _page(dive: _loggedDive('logged-$name'), prefs: prefs, health: part),
        );

        expect(find.text('Environment'), findsOneWidget);
        expect(find.text(_heading), findsNothing);
        expect(find.textContaining('water conditions right now'), findsNothing);
        expect(find.textContaining('No satellite water data'), findsNothing);
      });

      testWidgets('$name: no Environment card for a dive with nothing logged', (
        tester,
      ) async {
        await pump(
          tester,
          _page(
            dive: _satelliteOnlyDive('bare-$name'),
            prefs: prefs,
            health: part,
          ),
        );

        expect(find.text('Environment'), findsNothing);
        expect(find.text(_heading), findsNothing);
      });
    }

    testWidgets('an observation with no readings: nothing', (tester) async {
      await pump(
        tester,
        _page(
          dive: _satelliteOnlyDive('no-readings'),
          prefs: prefs,
          health: ReefPart.ok(
            ReefHealth(observedAt: DateTime.utc(2023, 9, 1, 12)),
          ),
        ),
      );

      // A heading over a bare "As of" date says nothing.
      expect(find.text('Environment'), findsNothing);
      expect(find.text(_heading), findsNothing);
    });

    testWidgets('freshwater: nothing, whatever the lookup says', (
      tester,
    ) async {
      await pump(
        tester,
        _page(
          dive: _satelliteOnlyDive(
            'fresh',
            site: _site(waterType: WaterType.fresh),
          ),
          prefs: prefs,
        ),
      );

      expect(find.text('Environment'), findsNothing);
      expect(find.text(_heading), findsNothing);
    });

    testWidgets('a dive logged in fresh water at a sea site: nothing', (
      tester,
    ) async {
      // The dive's own water type wins over its site's, as everywhere else.
      final dive = _satelliteOnlyDive(
        'fresh-dive',
      ).copyWith(waterType: WaterType.fresh);
      await pump(tester, _page(dive: dive, prefs: prefs));

      expect(find.text('Environment'), findsNothing);
      expect(find.text(_heading), findsNothing);
    });

    testWidgets('a dive without a site: nothing', (tester) async {
      final dive = Dive(id: 'no-site', dateTime: DateTime(2023, 9, 1, 10));
      await pump(tester, _page(dive: dive, prefs: prefs));

      expect(find.text('Environment'), findsNothing);
      expect(find.text(_heading), findsNothing);
    });
  });

  testWidgets('satellite data alone pairs Environment with Details', (
    tester,
  ) async {
    await pump(
      tester,
      _page(
        dive: _satelliteOnlyDive('pair'),
        prefs: prefs,
        visible: const [
          DiveDetailSectionId.details,
          DiveDetailSectionId.environment,
        ],
      ),
    );

    final pair = find.byType(ResponsiveSectionPair);
    expect(pair, findsOneWidget);
    expect(
      find.descendant(of: pair, matching: find.text('Details')),
      findsOneWidget,
    );
    expect(
      find.descendant(of: pair, matching: find.text(_heading)),
      findsOneWidget,
    );
  });
}
