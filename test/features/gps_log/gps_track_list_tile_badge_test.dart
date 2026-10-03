import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/features/gps_log/data/repositories/track_geometry_cache_repository.dart';
import 'package:submersion/features/gps_log/domain/entities/gps_track.dart';
import 'package:submersion/features/gps_log/presentation/providers/gps_track_map_providers.dart';
import 'package:submersion/features/gps_log/presentation/widgets/gps_track_list_tile.dart';
import 'package:submersion/l10n/arb/app_localizations.dart';

import '../../helpers/mock_providers.dart';

void main() {
  testWidgets('a kind badge sits under the detail line, which stays a Text', (
    tester,
  ) async {
    const track = GpsTrack(
      id: 't1',
      startTime: 1700000000000,
      endTime: 1700005400000,
      pointCount: 1,
    );
    final base = await getBaseOverrides();
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          ...base,
          gpsTrackGeometryProvider((
            't1',
            TrackLod.thumbnail,
          )).overrideWith((ref) async => const []),
        ],
        child: MaterialApp(
          locale: const Locale('en'),
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: Scaffold(
            body: ListView(
              children: [
                GpsTrackListTile(
                  track: track,
                  onTap: () {},
                  kindBadge: const SizedBox(
                    key: ValueKey('badge'),
                    width: 10,
                    height: 10,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    final detail = tester.getRect(find.text('1 point, 1h 30m'));
    final badge = tester.getRect(find.byKey(const ValueKey('badge')));
    expect(badge.top, greaterThanOrEqualTo(detail.bottom));
  });

  testWidgets('without a badge the detail line is the whole subtitle', (
    tester,
  ) async {
    const track = GpsTrack(
      id: 't1',
      startTime: 1700000000000,
      endTime: 1700005400000,
      pointCount: 1,
    );
    final base = await getBaseOverrides();
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          ...base,
          gpsTrackGeometryProvider((
            't1',
            TrackLod.thumbnail,
          )).overrideWith((ref) async => const []),
        ],
        child: MaterialApp(
          locale: const Locale('en'),
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: Scaffold(
            body: ListView(
              children: [GpsTrackListTile(track: track, onTap: () {})],
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    final tile = tester.widget<ListTile>(find.byType(ListTile));
    expect(tile.subtitle, isA<Text>());
    expect(find.text('1 point, 1h 30m'), findsOneWidget);
  });
}
