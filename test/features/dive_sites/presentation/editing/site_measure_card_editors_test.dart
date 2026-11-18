import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:submersion/core/constants/units.dart';
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
}
