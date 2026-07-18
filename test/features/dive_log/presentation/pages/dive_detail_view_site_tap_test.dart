import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:submersion/features/dive_log/domain/entities/dive.dart';
import 'package:submersion/features/dive_log/domain/entities/dive_data_source.dart';
import 'package:submersion/features/dive_log/presentation/pages/dive_detail_page.dart';
import 'package:submersion/features/dive_log/presentation/providers/dive_providers.dart';
import 'package:submersion/features/dive_log/presentation/widgets/dive_locations_map.dart';
import 'package:submersion/features/dive_sites/domain/entities/dive_site.dart';
import 'package:submersion/l10n/arb/app_localizations.dart';

import '../../../../helpers/mock_providers.dart';

void main() {
  // A dive whose site has coordinates, so DiveDetailPage renders the location
  // card (and therefore the tappable "View Site" tile).
  const site = DiveSite(
    id: 'site-1',
    name: 'Blue Hole',
    location: GeoPoint(12.3, 45.6),
  );
  final dive = Dive(
    id: 'dive-1',
    diveNumber: 1,
    dateTime: DateTime(2023, 1, 1),
    site: site,
  );

  // Returns the location-card InkWell (the one carrying a non-null onTap).
  InkWell locationInkWell(WidgetTester tester) {
    final candidates = tester.widgetList<InkWell>(
      find.ancestor(
        of: find.byType(DiveLocationsMap),
        matching: find.byType(InkWell),
      ),
    );
    return candidates.firstWhere((w) => w.onTap != null);
  }

  Future<String?> pumpAndTapViewSite(
    WidgetTester tester, {
    required bool embedded,
    required Size size,
  }) async {
    tester.view.devicePixelRatio = 1.0;
    tester.view.physicalSize = size;
    addTearDown(() {
      tester.view.resetPhysicalSize();
      tester.view.resetDevicePixelRatio();
    });

    final overrides = await getBaseOverrides();

    String? lastLocation;
    final router = GoRouter(
      initialLocation: '/test',
      redirect: (context, state) {
        lastLocation = state.uri.toString();
        return null;
      },
      routes: [
        GoRoute(
          path: '/test',
          builder: (context, state) =>
              DiveDetailPage(diveId: dive.id, embedded: embedded),
        ),
        GoRoute(
          path: '/sites/:id',
          builder: (context, state) =>
              const Scaffold(body: Text('SITE_STUB_PAGE')),
        ),
      ],
    );

    // The location card lays a FlutterMap under a gradient; overflow warnings
    // in the constrained test viewport are irrelevant to this test.
    final originalOnError = FlutterError.onError;
    FlutterError.onError = (details) {
      if (details.toString().contains('overflowed')) return;
      originalOnError?.call(details);
    };

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          ...overrides,
          diveProvider(dive.id).overrideWith((ref) async => dive),
          diveDataSourcesProvider(
            dive.id,
          ).overrideWith((ref) async => <DiveDataSource>[]),
        ],
        child: MaterialApp.router(
          routerConfig: router,
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
        ),
      ),
    );
    await tester.pump();
    await tester.pump(const Duration(seconds: 1));

    locationInkWell(tester).onTap!();
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 100));
    tester.takeException();

    FlutterError.onError = originalOnError;
    return lastLocation;
  }

  testWidgets(
    'embedded + master-detail: View Site adds the site query param in place',
    (tester) async {
      final location = await pumpAndTapViewSite(
        tester,
        embedded: true,
        size: const Size(1200, 800),
      );

      // Stays on the same page, only appends ?site=<id> so the dive list
      // remains visible (nested navigation).
      expect(location, isNotNull);
      expect(location, contains('site=site-1'));
      expect(location, startsWith('/test'));
    },
  );

  testWidgets(
    'non master-detail: View Site pushes the standalone /sites route',
    (tester) async {
      final location = await pumpAndTapViewSite(
        tester,
        embedded: true,
        size: const Size(400, 800),
      );

      // Phone width is not master-detail, so it navigates to the full site page.
      expect(find.text('SITE_STUB_PAGE'), findsOneWidget);
      expect(location, '/sites/site-1');
    },
  );
}
