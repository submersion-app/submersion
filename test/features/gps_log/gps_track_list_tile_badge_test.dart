import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/features/gps_log/data/repositories/track_geometry_cache_repository.dart';
import 'package:submersion/features/gps_log/domain/entities/gps_track.dart';
import 'package:submersion/features/gps_log/presentation/providers/gps_track_map_providers.dart';
import 'package:submersion/features/gps_log/presentation/widgets/gps_track_list_tile.dart';
import 'package:submersion/features/tracks/presentation/widgets/track_badge_line.dart';
import 'package:submersion/l10n/arb/app_localizations.dart';

import '../../helpers/mock_providers.dart';

void main() {
  testWidgets('a kind badge sits on the detail line, at its right edge', (
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

    // The badge rides the detail line (the row's last line, where an
    // underwater row carries its dive link), pinned to the right edge, not
    // the title row it sat in before (#3749).
    final tile = tester.widget<ListTile>(find.byType(ListTile));
    final title = tester.getRect(find.byWidget(tile.title!));
    final detail = tester.getRect(find.text('1 point, 1h 30m'));
    final line = tester.getRect(find.byType(TrackBadgeLine));
    final badge = tester.getRect(find.byKey(const ValueKey('badge')));
    expect(badge.top, greaterThanOrEqualTo(title.bottom));
    expect(badge.center.dy, inInclusiveRange(detail.top, detail.bottom));
    expect(badge.left, greaterThan(detail.right));
    expect(badge.right, line.right);

    expect(tile.title, isA<Text>());
    expect(tile.subtitle, isA<TrackBadgeLine>());
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
    // No badge: the subtitle is a badge-less TrackBadgeLine around the
    // detail text, which renders that text alone, with no Wrap around it.
    final tile = tester.widget<ListTile>(find.byType(ListTile));
    expect(tile.subtitle, isA<TrackBadgeLine>());
    final line = tile.subtitle! as TrackBadgeLine;
    expect(line.badge, isNull);
    expect((line.child as Text).data, '1 point, 1h 30m');
    expect(
      find.descendant(of: find.byWidget(line), matching: find.byType(Wrap)),
      findsNothing,
    );
    expect(find.text('1 point, 1h 30m'), findsOneWidget);
  });
}
