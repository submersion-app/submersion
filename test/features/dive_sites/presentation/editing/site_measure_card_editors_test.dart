import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:intl/intl.dart';

import 'package:submersion/core/constants/units.dart';
import 'package:submersion/core/constants/site_detail_sections.dart';
import 'package:submersion/features/dive_sites/presentation/editing/site_edit_cards.dart';
import 'package:submersion/features/dive_sites/domain/entities/dive_site.dart';
import 'package:submersion/features/dive_sites/presentation/editing/site_measure_card_editors.dart';
import 'package:submersion/features/dive_sites/presentation/editing/site_plain_fields.dart';
import 'package:submersion/features/dive_sites/presentation/site_difficulty_display.dart';
import 'package:submersion/features/settings/presentation/providers/settings_providers.dart';
import 'package:submersion/features/weather/data/services/elevation_service.dart';
import 'package:submersion/features/weather/presentation/providers/weather_providers.dart';
import 'package:submersion/l10n/arb/app_localizations_en.dart';

import 'site_editor_harness.dart';

class _FakeElevation extends ElevationService {
  _FakeElevation(this.metres);

  final double? metres;
  int asks = 0;

  @override
  Future<double?> fetchElevation({
    required double latitude,
    required double longitude,
  }) async {
    asks++;
    return metres;
  }
}

/// The site's Altitude, Depth, Difficulty and Rating cards edited in place
/// (issue #4527, phase 2, plan 2).
void main() {
  final l = AppLocalizationsEn();
  const site = DiveSite(id: 's1', name: 'Hole');

  testWidgets("altitude shows in the diver's unit and writes metres", (
    tester,
  ) async {
    final h = await pumpSiteEditor(
      tester,
      site,
      (session) => SiteAltitudeCardEditor(session: session),
      settings: const AppSettings(altitudeUnit: AltitudeUnit.feet),
      overrides: [
        elevationServiceProvider.overrideWithValue(_FakeElevation(null)),
      ],
    );

    await tester.tap(find.text(l.diveSites_edit_section_altitude));
    await tester.pump();
    await tester.enterText(find.byType(TextFormField), '100');
    await tester.pump();

    expect(h.session.valueOf(siteAltitudeField), closeTo(30.48, 0.001));
  });

  testWidgets('altitude takes no value below sea level, as the form', (
    tester,
  ) async {
    final h = await pumpSiteEditor(
      tester,
      site,
      (session) => SiteAltitudeCardEditor(session: session),
      overrides: [
        elevationServiceProvider.overrideWithValue(_FakeElevation(null)),
      ],
    );

    await tester.tap(find.text(l.diveSites_edit_section_altitude));
    await tester.pump();
    await tester.enterText(find.byType(TextFormField), '-20');
    await tester.pump();

    final altitude = h.session.valueOf(siteAltitudeField);
    expect(altitude == null || altitude >= 0, isTrue);
  });

  testWidgets('an elevation below sea level is not offered', (tester) async {
    await pumpSiteEditor(
      tester,
      const DiveSite(id: 's1', name: 'Hole', location: GeoPoint(31.5, 35.5)),
      (session) => SiteAltitudeCardEditor(session: session),
      overrides: [
        elevationServiceProvider.overrideWithValue(_FakeElevation(-400)),
      ],
    );

    expect(
      find.byTooltip(l.diveSites_edit_altitude_foundTooltip),
      findsNothing,
    );
  });

  testWidgets('the found altitude is not offered once the site has moved', (
    tester,
  ) async {
    final h = await pumpSiteEditor(
      tester,
      const DiveSite(id: 's1', name: 'Hole', location: GeoPoint(1, 2)),
      (session) => SiteAltitudeCardEditor(session: session),
      overrides: [
        elevationServiceProvider.overrideWithValue(_FakeElevation(12)),
      ],
    );
    final offer = find.byTooltip(l.diveSites_edit_altitude_foundTooltip);
    expect(offer, findsOneWidget);

    // Moved in the sitting: 12 m was found for where the site was.
    h.session.set(siteLocationField, const GeoPoint(3, 4));
    await tester.pump();

    expect(offer, findsNothing);
  });

  testWidgets('the found altitude is offered and used only on a tap', (
    tester,
  ) async {
    final elevation = _FakeElevation(12);
    final h = await pumpSiteEditor(
      tester,
      const DiveSite(id: 's1', name: 'Hole', location: GeoPoint(1, 2)),
      (session) => SiteAltitudeCardEditor(session: session),
      overrides: [elevationServiceProvider.overrideWithValue(elevation)],
    );

    expect(h.session.isDirty, isFalse);
    final offer = find.byTooltip(l.diveSites_edit_altitude_foundTooltip);
    expect(offer, findsOneWidget);

    await tester.tap(offer);
    await tester.pump();

    expect(h.session.valueOf(siteAltitudeField), 12);
    expect(elevation.asks, 1);
  });

  testWidgets('depth rows write metres', (tester) async {
    final h = await pumpSiteEditor(
      tester,
      site,
      (session) => SiteDepthCardEditor(session: session),
    );

    await tester.tap(find.text(l.diveSites_edit_depth_minLabel('m')));
    await tester.pump();
    await tester.enterText(find.byType(TextFormField), '5');
    await tester.pump();
    await tester.tap(find.text(l.diveSites_edit_depth_maxLabel('m')));
    await tester.pump();
    await tester.enterText(find.byType(TextFormField).last, '40');
    await tester.pump();

    expect(h.session.valueOf(siteMinDepthField), 5);
    expect(h.session.valueOf(siteMaxDepthField), 40);
  });

  testWidgets('a minimum deeper than the maximum refuses Save and says why', (
    tester,
  ) async {
    final h = await pumpSiteEditor(
      tester,
      site,
      (session) => SiteDepthCardEditor(session: session),
    );
    final depth = siteEditCards[SiteDetailSectionId.depth]!;

    h.session
      ..set(siteMinDepthField, 40.0)
      ..set(siteMaxDepthField, 5.0);
    await tester.pump();

    expect(depth.isValid!(h.session), isFalse);
    expect(find.text(l.diveSites_edit_depth_rangeInvalid), findsOneWidget);

    // Either alone, or in order, is fine.
    h.session.set(siteMaxDepthField, null);
    await tester.pump();
    expect(depth.isValid!(h.session), isTrue);
    expect(find.text(l.diveSites_edit_depth_rangeInvalid), findsNothing);
  });

  testWidgets('a stored range out of order does not block saving another '
      'card', (tester) async {
    final h = await pumpSiteEditor(
      tester,
      site.copyWith(minDepth: 40.0, maxDepth: 5.0),
      (session) => SiteDepthCardEditor(session: session),
    );

    // Not the diver's to fix before saving, say, the notes.
    expect(
      siteEditCards[SiteDetailSectionId.depth]!.isValid!(h.session),
      isTrue,
    );
  });

  testWidgets('difficulty chips set and clear', (tester) async {
    final h = await pumpSiteEditor(
      tester,
      site,
      (session) => SiteDifficultyCardEditor(session: session),
    );
    final advanced = find.text(SiteDifficulty.advanced.localizedName(l));

    await tester.tap(advanced);
    await tester.pump();
    expect(h.session.valueOf(siteDifficultyField), SiteDifficulty.advanced);

    await tester.tap(advanced);
    await tester.pump();
    expect(h.session.valueOf(siteDifficultyField), isNull);
  });

  testWidgets('rating sets and clears', (tester) async {
    final h = await pumpSiteEditor(
      tester,
      site,
      (session) => SiteRatingCardEditor(session: session),
    );

    await tester.tap(find.byIcon(Icons.star_border).at(2));
    await tester.pump();
    expect(h.session.valueOf(siteRatingField), 3);

    await tester.tap(find.byTooltip(l.common_action_clearRating));
    await tester.pump();
    expect(h.session.valueOf(siteRatingField), isNull);
  });

  // The form's locale cases, on the Depth card (plan 7).
  group('in a locale with a decimal comma', () {
    late String? previousLocale;
    setUp(() => previousLocale = Intl.defaultLocale);
    tearDown(() => Intl.defaultLocale = previousLocale);

    testWidgets('comma decimals typed into the depth rows are held (fr)', (
      tester,
    ) async {
      Intl.defaultLocale = 'fr';
      final h = await pumpSiteEditor(
        tester,
        site,
        (session) => SiteDepthCardEditor(session: session),
      );

      await tester.tap(find.text(l.diveSites_edit_depth_minLabel('m')));
      await tester.pump();
      await tester.enterText(find.byType(TextFormField), '12,5');
      await tester.pump();
      await tester.tap(find.text(l.diveSites_edit_depth_maxLabel('m')));
      await tester.pump();
      await tester.enterText(find.byType(TextFormField).last, '30,5');
      await tester.pump();

      expect(h.session.valueOf(siteMinDepthField), 12.5);
      expect(h.session.valueOf(siteMaxDepthField), 30.5);
      expect(h.controller.invalidCardIds, isNot(contains('depth')));
    });

    testWidgets('opening and leaving the rows changes nothing (de)', (
      tester,
    ) async {
      Intl.defaultLocale = 'de';
      final h = await pumpSiteEditor(
        tester,
        site.copyWith(minDepth: 12.5, maxDepth: 30),
        (session) => SiteDepthCardEditor(session: session),
      );
      expect(find.textContaining('12,5'), findsOneWidget);

      await tester.tap(find.text(l.diveSites_edit_depth_minLabel('m')));
      await tester.pump();
      await tester.tap(find.text(l.diveSites_edit_depth_maxLabel('m')));
      await tester.pump();
      await tester.tapAt(const Offset(5, 5));
      await tester.pump();

      expect(h.session.valueOf(siteMinDepthField), 12.5);
      expect(h.session.valueOf(siteMaxDepthField), 30);
      expect(h.session.isDirty, isFalse);
    });
  });
}
