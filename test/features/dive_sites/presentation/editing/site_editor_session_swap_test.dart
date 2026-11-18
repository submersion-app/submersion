import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:submersion/core/providers/provider.dart';
import 'package:submersion/core/utils/coordinates/coordinate_format.dart';
import 'package:submersion/features/dive_sites/domain/entities/dive_site.dart';
import 'package:submersion/features/dive_sites/presentation/editing/site_coordinate_rows.dart';
import 'package:submersion/features/dive_sites/presentation/editing/site_measure_card_editors.dart';
import 'package:submersion/features/dive_sites/presentation/editing/site_plain_fields.dart';
import 'package:submersion/features/weather/data/services/elevation_service.dart';
import 'package:submersion/features/weather/presentation/providers/weather_providers.dart';
import 'package:submersion/l10n/arb/app_localizations.dart';
import 'package:submersion/l10n/arb/app_localizations_en.dart';
import 'package:submersion/shared/widgets/record_editing/edit_session.dart';

import '../../../../helpers/mock_providers.dart';

class _Elevation extends ElevationService {
  @override
  Future<double?> fetchElevation({
    required double latitude,
    required double longitude,
  }) async => latitude;
}

/// A site card's editor handed another sitting while mounted (a retake
/// after a whole-record operation) follows the new one (issue #4527).
void main() {
  final l = AppLocalizationsEn();

  Future<void> pump(WidgetTester tester, Widget child) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          ...await getBaseOverrides(),
          elevationServiceProvider.overrideWithValue(_Elevation()),
        ].cast<Override>(),
        child: MaterialApp(
          locale: const Locale('en'),
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: Scaffold(body: SingleChildScrollView(child: child)),
        ),
      ),
    );
    await tester.pumpAndSettle();
  }

  testWidgets('the coordinate rows follow a new sitting', (tester) async {
    final first = EditSession<DiveSite>(
      const DiveSite(id: 's1', name: 'A', location: GeoPoint(1, 2)),
    );
    final second = EditSession<DiveSite>(
      const DiveSite(id: 's1', name: 'A', location: GeoPoint(3, 4)),
    );
    addTearDown(first.dispose);
    addTearDown(second.dispose);
    Widget rows(EditSession<DiveSite> s) =>
        SiteCoordinateRows(session: s, format: CoordinateFormat.decimalDegrees);

    await pump(tester, rows(first));
    await pump(tester, rows(second));

    expect(find.textContaining('3.'), findsWidgets);
    second.rebase(
      const DiveSite(id: 's1', name: 'A', location: GeoPoint(5, 6)),
    );
    await tester.pump();
    expect(find.textContaining('5.'), findsWidgets);
  });

  testWidgets("the old sitting's unreadable position is not carried over", (
    tester,
  ) async {
    final first = EditSession<DiveSite>(
      const DiveSite(id: 's1', name: 'A', location: GeoPoint(1, 2)),
    );
    final second = EditSession<DiveSite>(
      const DiveSite(id: 's1', name: 'A', location: GeoPoint(3, 4)),
    );
    addTearDown(first.dispose);
    addTearDown(second.dispose);
    Widget rows(EditSession<DiveSite> s) =>
        SiteCoordinateRows(session: s, format: CoordinateFormat.decimalDegrees);

    await pump(tester, rows(first));
    await tester.enterText(find.byType(TextField).first, '95');
    await tester.pump();
    expect(find.text(l.common_coordinates_invalidLatitude), findsWidgets);

    await pump(tester, rows(second));

    // The new sitting's position reads: no error from the old one remains.
    expect(find.text(l.common_coordinates_invalidLatitude), findsNothing);
  });

  testWidgets('the altitude suggestion follows a new sitting', (tester) async {
    final first = EditSession<DiveSite>(
      const DiveSite(id: 's1', name: 'A', location: GeoPoint(10, 2)),
    );
    final second = EditSession<DiveSite>(
      const DiveSite(id: 's1', name: 'A', location: GeoPoint(20, 2)),
    );
    addTearDown(first.dispose);
    addTearDown(second.dispose);

    await pump(tester, SiteAltitudeCardEditor(session: first));
    await pump(tester, SiteAltitudeCardEditor(session: second));

    final offer = find.byTooltip(l.diveSites_edit_altitude_foundTooltip);
    await tester.tap(offer);
    await tester.pump();
    // The elevation found for the second sitting's position.
    expect(second.valueOf(siteAltitudeField), 20);
  });
}
