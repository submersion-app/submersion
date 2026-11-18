import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:intl/intl.dart';
import 'package:submersion/core/constants/dive_detail_sections.dart';
import 'package:submersion/core/constants/units.dart';
import 'package:submersion/core/deco/altitude_calculator.dart';
import 'package:submersion/core/utils/number_input.dart';
import 'package:submersion/core/utils/unit_formatter.dart';
import 'package:submersion/features/dive_log/domain/entities/dive.dart';
import 'package:submersion/features/dive_log/presentation/widgets/dive_detail/dive_detail_altitude_section.dart';
import 'package:submersion/features/dive_log/presentation/widgets/dive_detail/editing/dive_altitude_card_editor.dart';
import 'package:submersion/features/dive_log/presentation/widgets/dive_detail/editing/dive_altitude_fields.dart';
import 'package:submersion/features/dive_log/presentation/widgets/dive_detail/editing/dive_edit_cards.dart';
import 'package:submersion/features/dive_sites/data/repositories/site_repository_impl.dart';
import 'package:submersion/features/dive_sites/domain/entities/dive_site.dart';
import 'package:submersion/features/dive_sites/presentation/providers/site_providers.dart';
import 'package:submersion/features/settings/presentation/providers/settings_providers.dart';
import 'package:submersion/features/weather/data/services/elevation_service.dart';
import 'package:submersion/features/weather/presentation/providers/weather_providers.dart';
import 'package:submersion/l10n/arb/app_localizations.dart';
import 'package:submersion/shared/widgets/info_sheet/info_button.dart';
import 'package:submersion/shared/widgets/record_editing/record_card_frame.dart';
import 'package:submersion/shared/widgets/record_editing/record_card_header.dart';
import 'package:submersion/shared/widgets/record_editing/record_edit_controller.dart';

import '../../../../../../helpers/mock_providers.dart';
import '../../../../../../helpers/test_database.dart';

/// Answers elevation lookups from a fixed value, counts them, and can hold
/// one until released.
class _FakeElevation extends ElevationService {
  _FakeElevation({this.result, this.gate})
    : super(client: MockClient((_) async => http.Response('', 500)));

  final double? result;
  final Completer<void>? gate;
  int calls = 0;

  @override
  Future<double?> fetchElevation({
    required double latitude,
    required double longitude,
  }) async {
    calls++;
    await gate?.future;
    return result;
  }
}

/// Records the altitude written back to a site instead of storing it.
class _FakeSites extends SiteRepository {
  final wrote = <(String, double)>[];

  @override
  Future<bool> fillSiteAltitudeIfEmpty(
    String siteId,
    double altitudeMeters,
  ) async {
    wrote.add((siteId, altitudeMeters));
    return true;
  }
}

const _cardId = 'altitude';

/// The Altitude card of the dive page, edited in place (issue #4527).
void main() {
  final bare = Dive(id: 'dive', dateTime: DateTime(2024, 6, 1, 10));
  final high = bare.copyWith(altitude: 1200, surfacePressure: 0.87);

  // The ranges group digits by the process-wide Intl.defaultLocale, which
  // another test may have changed. Pin English so "2,953" keeps its comma.
  late String? previousLocale;
  setUp(() {
    previousLocale = Intl.defaultLocale;
    Intl.defaultLocale = 'en';
  });
  tearDown(() => Intl.defaultLocale = previousLocale);

  const lakeNoAltitude = DiveSite(
    id: 'site-1',
    name: 'Lake',
    location: GeoPoint(46.5, 8.6),
  );
  const lakeAt900 = DiveSite(
    id: 'site-1',
    name: 'Lake',
    location: GeoPoint(46.5, 8.6),
    altitude: 900,
  );

  group('the editor', () {
    setUp(setUpTestDatabase);
    tearDown(tearDownTestDatabase);

    Future<RecordEditController<Dive>> pumpEditor(
      WidgetTester tester,
      Dive dive, {
      AppSettings settings = const AppSettings(),
      ElevationService? elevation,
      SiteRepository? sites,
      bool showEditor = true,
      RecordEditController<Dive>? controller,
    }) async {
      final edit =
          controller ??
          (RecordEditController<Dive>(onSave: (_) async {})
            ..unlock(dive)
            ..openCard(_cardId));
      if (controller == null) addTearDown(edit.dispose);
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            ...await getBaseOverrides(
              settingsNotifier: MockSettingsNotifier(settings),
            ),
            elevationServiceProvider.overrideWithValue(
              elevation ?? _FakeElevation(),
            ),
            if (sites != null) siteRepositoryProvider.overrideWithValue(sites),
          ],
          child: MaterialApp(
            locale: const Locale('en'),
            localizationsDelegates: AppLocalizations.localizationsDelegates,
            supportedLocales: AppLocalizations.supportedLocales,
            home: Scaffold(
              body: SingleChildScrollView(
                child: RecordEditScope<Dive>(
                  controller: edit,
                  child: Column(
                    children: [
                      if (showEditor)
                        DiveAltitudeCardEditor(session: edit.session!),
                      const TextField(key: ValueKey('elsewhere')),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      );
      await tester.pump();
      await tester.pump();
      return edit;
    }

    const imperial = AppSettings(
      depthUnit: DepthUnit.feet,
      altitudeUnit: AltitudeUnit.feet,
    );

    Future<void> focusThenLeave(WidgetTester tester, String resting) async {
      await tester.tap(find.text(resting));
      await tester.pump();
      await tester.tap(find.byKey(const ValueKey('elsewhere')));
      await tester.pump();
    }

    testWidgets('metric: altitude in metres, pressure in mbar', (tester) async {
      final controller = await pumpEditor(tester, high);

      expect(find.text('1200 m'), findsOneWidget);
      expect(find.text('870 mbar'), findsOneWidget);
      expect(controller.isDirty, isFalse);
    });

    testWidgets('imperial: altitude in feet, pressure in inHg', (tester) async {
      final controller = await pumpEditor(tester, high, settings: imperial);

      expect(find.text('3937 ft'), findsOneWidget);
      expect(find.text('25.69 inHg'), findsOneWidget);
      expect(controller.isDirty, isFalse);
    });

    // 3937 ft reads back as 1,199.998 m and 25.69 inHg as 0.86996 bar.
    // Looking at a row must not turn either into a change.
    for (final (name, settings, altitude, pressure) in [
      ('metric', const AppSettings(), '1200 m', '870 mbar'),
      ('imperial', imperial, '3937 ft', '25.69 inHg'),
    ]) {
      testWidgets('$name: focusing each row leaves the sitting clean', (
        tester,
      ) async {
        final controller = await pumpEditor(tester, high, settings: settings);

        await focusThenLeave(tester, altitude);
        await focusThenLeave(tester, pressure);

        expect(controller.isDirty, isFalse);
        expect(controller.session!.working, high);
      });
    }

    testWidgets('typing an altitude in feet stores metres', (tester) async {
      final controller = await pumpEditor(tester, high, settings: imperial);

      await tester.tap(find.text('3937 ft'));
      await tester.pump();
      await tester.enterText(find.byType(TextFormField), '1000');
      await tester.pump();

      expect(
        controller.session!.valueOf(diveAltitudeField),
        closeTo(304.8, 0.001),
      );
      expect(controller.session!.changedCardIds, {_cardId});
    });

    testWidgets('typing a pressure in inHg stores bar', (tester) async {
      final controller = await pumpEditor(tester, high, settings: imperial);

      await tester.tap(find.text('25.69 inHg'));
      await tester.pump();
      await tester.enterText(find.byType(TextFormField), '29.53');
      await tester.pump();

      expect(
        controller.session!.valueOf(diveSurfacePressureField),
        closeTo(1.0, 0.0001),
      );
    });

    testWidgets('emptying the altitude clears it', (tester) async {
      final controller = await pumpEditor(tester, high);

      await tester.tap(find.text('1200 m'));
      await tester.pump();
      await tester.enterText(find.byType(TextFormField), '');
      await tester.pump();

      expect(controller.session!.valueOf(diveAltitudeField), isNull);
      expect(controller.session!.working.altitude, isNull);
    });

    testWidgets('a negative pressure is refused', (tester) async {
      final controller = await pumpEditor(tester, high);

      await tester.tap(find.text('870 mbar'));
      await tester.pump();
      await tester.enterText(find.byType(TextFormField), '-5');
      await tester.pump();

      expect(controller.invalidCardIds, {_cardId});
      expect(controller.session!.valueOf(diveSurfacePressureField), 0.87);
    });

    testWidgets('with no pressure stored, the row hints the pressure for '
        'the altitude', (tester) async {
      await pumpEditor(tester, bare.copyWith(altitude: 2000));
      const units = UnitFormatter(AppSettings());
      final hint = formatFixedForInput(
        units.convertSurfacePressure(
          AltitudeCalculator.calculateBarometricPressure(2000),
        ),
        0,
      );
      expect(hint, isNot('1013'));

      expect(find.text(hint), findsOneWidget);

      // Back at sea level the hint is standard pressure.
      await tester.tap(find.text('2000 m'));
      await tester.pump();
      await tester.enterText(find.byType(TextFormField), '0');
      await tester.pump();

      expect(find.text('1013'), findsOneWidget);
      expect(find.text(hint), findsNothing);
    });

    testWidgets('the pressure hint follows the diver\'s unit', (tester) async {
      await pumpEditor(tester, bare.copyWith(altitude: 0), settings: imperial);

      // 1.01325 bar is 29.92 inHg.
      expect(find.text('29.92'), findsOneWidget);
    });

    testWidgets('typing an altitude shows its group banner', (tester) async {
      await pumpEditor(tester, bare.copyWith(altitude: 100));
      AltitudeGroupBanner banner() =>
          tester.widget(find.byType(AltitudeGroupBanner));
      expect(banner().group, AltitudeGroup.seaLevel);

      await tester.tap(find.text('100 m'));
      await tester.pump();
      await tester.enterText(find.byType(TextFormField), '2500');
      await tester.pump();

      expect(banner().group, AltitudeGroup.group3);
      expect(find.text('Altitude Group 3'), findsOneWidget);
    });

    // Unreadable text never reaches the sitting, which keeps the last
    // altitude that could be read. The banner follows the row the diver
    // reads, not that value, so it names no group while the row has none.
    testWidgets('an unreadable altitude shows no group banner', (tester) async {
      await pumpEditor(tester, bare.copyWith(altitude: 2500));
      AltitudeGroupBanner banner() =>
          tester.widget(find.byType(AltitudeGroupBanner));
      expect(banner().group, AltitudeGroup.group3);

      await tester.tap(find.text('2500 m'));
      await tester.pump();
      await tester.enterText(find.byType(TextFormField), '1.2.3');
      await tester.pump();

      expect(banner().group, AltitudeGroup.seaLevel);
      expect(find.text('Altitude Group 3'), findsNothing);

      await tester.enterText(find.byType(TextFormField), '1500');
      await tester.pump();

      expect(banner().group, AltitudeGroup.fromAltitude(1500));
    });

    // An imperial diver saw "300-900m (984-2953ft)": metres first, and a
    // unit they did not choose.
    testWidgets('the banner gives its range in the diver\'s unit', (
      tester,
    ) async {
      await pumpEditor(tester, high, settings: imperial);

      expect(find.text('Altitude Group 2'), findsOneWidget);
      expect(find.text('2,953-5,906 ft'), findsOneWidget);
    });

    testWidgets('at sea level the banner takes no room', (tester) async {
      await pumpEditor(tester, bare.copyWith(altitude: 100));

      expect(tester.getSize(find.byType(AltitudeGroupBanner)).height, 0);
    });

    testWidgets('opening an empty altitude fills it from the site', (
      tester,
    ) async {
      final elevation = _FakeElevation(result: 512);
      final controller = await pumpEditor(
        tester,
        bare.copyWith(site: lakeAt900),
        elevation: elevation,
      );

      expect(find.text('900 m'), findsOneWidget);
      expect(controller.session!.valueOf(diveAltitudeField), 900);
      expect(controller.session!.changedCardIds, {_cardId});
      expect(elevation.calls, 0);
    });

    testWidgets('a looked-up altitude is copied to the site with the sitting', (
      tester,
    ) async {
      final sites = _FakeSites();
      final controller = await pumpEditor(
        tester,
        bare.copyWith(site: lakeNoAltitude),
        elevation: _FakeElevation(result: 512),
        sites: sites,
      );

      expect(find.text('512 m'), findsOneWidget);
      expect(controller.session!.hasHeldWrites, isTrue);
      expect(sites.wrote, isEmpty);

      await controller.session!.runHeldWrites();

      expect(sites.wrote, [('site-1', 512.0)]);
    });

    // The lookup was made because the site had no altitude. One it gained
    // before the sitting was saved (typed on the site page, or brought in
    // by a sync) is newer than the lookup and is kept.
    testWidgets('a held site altitude does not overwrite one the site gained '
        'meanwhile', (tester) async {
      final sites = SiteRepository();
      await tester.runAsync(() => sites.createSite(lakeNoAltitude));
      final controller = await pumpEditor(
        tester,
        bare.copyWith(site: lakeNoAltitude),
        elevation: _FakeElevation(result: 512),
        sites: sites,
      );
      expect(controller.session!.hasHeldWrites, isTrue);

      await tester.runAsync(() => sites.updateSiteAltitude('site-1', 300));
      await tester.runAsync(() => controller.session!.runHeldWrites());

      final stored = await tester.runAsync(() => sites.getSiteById('site-1'));
      expect(stored!.altitude, 300);
    });

    testWidgets('a held site altitude is written while the site still has '
        'none', (tester) async {
      final sites = SiteRepository();
      await tester.runAsync(() => sites.createSite(lakeNoAltitude));
      final controller = await pumpEditor(
        tester,
        bare.copyWith(site: lakeNoAltitude),
        elevation: _FakeElevation(result: 512),
        sites: sites,
      );

      await tester.runAsync(() => controller.session!.runHeldWrites());

      final stored = await tester.runAsync(() => sites.getSiteById('site-1'));
      expect(stored!.altitude, 512);
    });

    testWidgets('an altitude that is set is not looked up', (tester) async {
      final elevation = _FakeElevation(result: 512);
      final controller = await pumpEditor(
        tester,
        high.copyWith(site: lakeNoAltitude),
        elevation: elevation,
      );

      expect(elevation.calls, 0);
      expect(controller.isDirty, isFalse);
    });

    // The lookup is made once in a sitting, as the dive form made it once
    // when it loaded. Opening the card again must not bring back an
    // altitude the diver took out.
    testWidgets('a looked-up altitude the diver cleared is not looked up '
        'again', (tester) async {
      final elevation = _FakeElevation(result: 512);
      final dive = bare.copyWith(site: lakeNoAltitude);
      final controller = await pumpEditor(
        tester,
        dive,
        elevation: elevation,
        sites: _FakeSites(),
      );
      expect(controller.session!.valueOf(diveAltitudeField), 512);

      controller.session!.set(diveAltitudeField, null);
      // The card is closed, then opened again.
      await pumpEditor(
        tester,
        dive,
        showEditor: false,
        controller: controller,
        elevation: elevation,
        sites: _FakeSites(),
      );
      await pumpEditor(
        tester,
        dive,
        controller: controller,
        elevation: elevation,
        sites: _FakeSites(),
      );

      expect(elevation.calls, 1);
      expect(controller.session!.valueOf(diveAltitudeField), isNull);
    });

    testWidgets('a stored altitude the diver cleared stays cleared when the '
        'card is opened again', (tester) async {
      final dive = high.copyWith(site: lakeAt900);
      final controller = await pumpEditor(tester, dive);

      controller.session!.set(diveAltitudeField, null);
      await pumpEditor(tester, dive, showEditor: false, controller: controller);
      await pumpEditor(tester, dive, controller: controller);

      expect(controller.session!.valueOf(diveAltitudeField), isNull);
    });

    testWidgets(
      'a lookup that returns after the editor has gone sets nothing',
      (tester) async {
        final gate = Completer<void>();
        final dive = bare.copyWith(site: lakeNoAltitude);
        final controller = await pumpEditor(
          tester,
          dive,
          elevation: _FakeElevation(result: 512, gate: gate),
          sites: _FakeSites(),
        );
        await pumpEditor(
          tester,
          dive,
          showEditor: false,
          controller: controller,
          sites: _FakeSites(),
        );

        gate.complete();
        await tester.pump();
        await tester.pump();

        expect(tester.takeException(), isNull);
        expect(controller.isDirty, isFalse);
        expect(controller.session!.hasHeldWrites, isFalse);
      },
    );
  });

  group('the read card', () {
    setUp(setUpTestDatabase);
    tearDown(tearDownTestDatabase);

    Future<void> pumpCard(
      WidgetTester tester,
      Widget card, {
      RecordEditController<Dive>? controller,
    }) async {
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            ...await getBaseOverrides(),
            elevationServiceProvider.overrideWithValue(_FakeElevation()),
          ],
          child: MaterialApp(
            locale: const Locale('en'),
            localizationsDelegates: AppLocalizations.localizationsDelegates,
            supportedLocales: AppLocalizations.supportedLocales,
            home: Scaffold(
              body: SingleChildScrollView(
                child: controller == null
                    ? card
                    : RecordEditScope<Dive>(
                        controller: controller,
                        child: RecordCardFrame<Dive>(
                          card: diveEditCards[DiveDetailSectionId.altitude]!,
                          child: card,
                        ),
                      ),
              ),
            ),
          ),
        ),
      );
      await tester.pump();
    }

    RecordEditController<Dive> unlocked(Dive dive) {
      final controller = RecordEditController<Dive>(onSave: (_) async {})
        ..unlock(dive);
      addTearDown(controller.dispose);
      return controller;
    }

    testWidgets('its title is the shared header, with its icon and info '
        'button', (tester) async {
      await pumpCard(tester, DiveAltitudeSection(dive: high));

      final header = find.byType(RecordCardHeader);
      expect(header, findsOneWidget);
      expect(
        find.descendant(of: header, matching: find.byIcon(Icons.terrain)),
        findsOneWidget,
      );
      expect(
        find.descendant(of: header, matching: find.byType(HeaderInfoButton)),
        findsOneWidget,
      );
      final title = tester.widget<Text>(find.text('Altitude Dive'));
      expect(
        title.style,
        Theme.of(tester.element(header)).textTheme.titleMedium,
      );
      expect(find.byIcon(Icons.edit_outlined), findsNothing);
    });

    testWidgets('the icon sits before the title and the info button at the '
        'right', (tester) async {
      await pumpCard(tester, DiveAltitudeSection(dive: high));

      final icon = tester.getRect(find.byIcon(Icons.terrain));
      final title = tester.getRect(find.text('Altitude Dive'));
      final info = tester.getRect(find.byType(HeaderInfoButton));
      expect(icon.right, lessThanOrEqualTo(title.left));
      expect(title.right, lessThanOrEqualTo(info.left));
    });

    testWidgets('it shows the group banner for its altitude', (tester) async {
      await pumpCard(
        tester,
        DiveAltitudeSection(dive: bare.copyWith(altitude: 1850)),
      );

      final banner = tester.widget<AltitudeGroupBanner>(
        find.byType(AltitudeGroupBanner),
      );
      expect(banner.group, AltitudeGroup.group3);
      expect(find.text('Altitude Group 3'), findsOneWidget);
      expect(find.text('1,800-2,700 m'), findsOneWidget);
    });

    testWidgets('unlocked, it gains the pencil and keeps its icon and info '
        'button', (tester) async {
      await pumpCard(
        tester,
        DiveAltitudeSection(dive: high),
        controller: unlocked(high),
      );

      expect(find.byTooltip('Edit Altitude Dive'), findsOneWidget);
      expect(find.byIcon(Icons.terrain), findsOneWidget);
      expect(find.byType(HeaderInfoButton), findsOneWidget);
    });

    testWidgets('open, the card keeps its icon before the title', (
      tester,
    ) async {
      final controller = unlocked(high)..openCard(_cardId);
      await pumpCard(
        tester,
        DiveAltitudeSection(dive: high),
        controller: controller,
      );

      expect(find.byType(DiveAltitudeCardEditor), findsOneWidget);
      final icon = tester.getRect(find.byIcon(Icons.terrain));
      final title = tester.getRect(find.text('Altitude Dive'));
      expect(icon.right, lessThanOrEqualTo(title.left));
      expect(find.text('Done'), findsOneWidget);
    });

    testWidgets('unlocked, the mismatch note opens the Altitude card', (
      tester,
    ) async {
      final dive = bare.copyWith(site: lakeAt900);
      final controller = unlocked(dive);
      await pumpCard(
        tester,
        const DiveAltitudeMismatchNote(),
        controller: controller,
      );

      await tester.tap(find.byType(ListTile));
      await tester.pump();
      await tester.pump();

      expect(controller.openCardIds, {_cardId});
      expect(find.byType(DiveAltitudeCardEditor), findsOneWidget);
    });

    // A locked page reads only (issue #4527, plan 11).
    testWidgets('locked, the mismatch note has no tap and no edit icon', (
      tester,
    ) async {
      final locked = RecordEditController<Dive>(onSave: (_) async {});
      addTearDown(locked.dispose);
      await tester.pumpWidget(
        MaterialApp(
          locale: const Locale('en'),
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: Scaffold(
            body: RecordEditScope<Dive>(
              controller: locked,
              child: const DiveAltitudeMismatchNote(),
            ),
          ),
        ),
      );

      expect(tester.widget<ListTile>(find.byType(ListTile)).onTap, isNull);
      expect(find.byIcon(Icons.edit_outlined), findsNothing);
    });
  });
}
