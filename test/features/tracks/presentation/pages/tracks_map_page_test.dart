import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/features/gps_log/data/repositories/track_geometry_cache_repository.dart';
import 'package:submersion/features/gps_log/domain/entities/gps_track.dart';
import 'package:submersion/features/gps_log/presentation/providers/gps_log_providers.dart';
import 'package:submersion/features/gps_log/presentation/providers/gps_track_map_providers.dart';
import 'package:submersion/features/nav_track/presentation/providers/nav_track_providers.dart';
import 'package:submersion/features/tracks/presentation/pages/tracks_map_page.dart';
import 'package:submersion/features/tracks/presentation/widgets/tracks_overview_map.dart';
import 'package:submersion/l10n/arb/app_localizations.dart';
import 'package:submersion/shared/providers/map_list_selection_provider.dart';

import '../../../../helpers/mock_providers.dart';

GpsTrackPoint _p(int t, double base) => GpsTrackPoint(
  timestamp: t,
  latitude: base + t * 0.001,
  longitude: -87.0 + t * 0.001,
);

GpsTrack _track(String id, double base) => GpsTrack(
  id: id,
  startTime: 1700000000000,
  endTime: 1700003600000,
  pointCount: 3,
  points: [_p(0, base), _p(1, base), _p(2, base)],
);

Future<void> _pump(
  WidgetTester tester, {
  Size size = const Size(1400, 900),
  Future<List<GpsTrack>> Function()? tracks,
}) async {
  final base = await getBaseOverrides();
  final data = [_track('t1', 20.0), _track('t2', 25.0)];
  await tester.binding.setSurfaceSize(size);
  addTearDown(() => tester.binding.setSurfaceSize(null));
  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        ...base,
        gpsTracksProvider.overrideWith(
          (ref) => tracks?.call() ?? Future.value(data),
        ),
        allNavTracksProvider.overrideWith((ref) async => const []),
        for (final t in data)
          gpsTrackGeometryProvider((
            t.id,
            TrackLod.thumbnail,
          )).overrideWith((ref) async => t.points),
      ],
      child: MaterialApp(
        locale: const Locale('en'),
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: MediaQuery(
          data: MediaQueryData(size: size),
          child: const TracksMapPage(),
        ),
      ),
    ),
  );
  await tester.pumpAndSettle();
}

void main() {
  testWidgets('draws every track on one map with a list beside it', (
    tester,
  ) async {
    await _pump(tester);
    expect(find.text('Track Map'), findsOneWidget);
    final layer = tester.widget<PolylineLayer<String>>(
      find.byType(PolylineLayer<String>),
    );
    expect(layer.polylines.length, 2);
    // The map page lists rows only: no record card, summary or match action.
    expect(find.text('Match tracks to dives'), findsNothing);
  });

  testWidgets('a phone-width surface shows only the map', (tester) async {
    await _pump(tester, size: const Size(390, 844));
    expect(find.byType(FlutterMap), findsOneWidget);
    expect(find.byKey(const ValueKey('gps:t1')), findsNothing);
  });

  testWidgets('selecting a row promotes its track', (tester) async {
    await _pump(tester);
    final container = ProviderScope.containerOf(
      tester.element(find.byType(TracksMapPage)),
    );
    container
        .read(mapListSelectionProvider(kTracksSectionKey).notifier)
        .select('gps:t1');
    await tester.pumpAndSettle();
    final layer = tester.widget<PolylineLayer<String>>(
      find.byType(PolylineLayer<String>),
    );
    expect(layer.polylines.last.hitValue, 'gps:t1');
  });

  testWidgets('shows a spinner while loading, not the empty state', (
    tester,
  ) async {
    final pending = Completer<List<GpsTrack>>();
    await tester.binding.setSurfaceSize(const Size(1400, 900));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    final base = await getBaseOverrides();
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          ...base,
          gpsTracksProvider.overrideWith((ref) => pending.future),
          allNavTracksProvider.overrideWith((ref) async => const []),
        ],
        child: const MaterialApp(
          locale: Locale('en'),
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: MediaQuery(
            data: MediaQueryData(size: Size(1400, 900)),
            child: TracksMapPage(),
          ),
        ),
      ),
    );
    await tester.pump();
    expect(find.byType(CircularProgressIndicator), findsOneWidget);
    expect(find.text('No recorded tracks to show.'), findsNothing);
    pending.complete(const []);
    await tester.pumpAndSettle();
  });

  testWidgets('a failed query says so instead of claiming there are none', (
    tester,
  ) async {
    await _pump(tester, tracks: () => Future.error(StateError('boom')));
    expect(
      find.text('Something went wrong. Please try again.'),
      findsOneWidget,
    );
    expect(find.text('No recorded tracks to show.'), findsNothing);
  });
}
