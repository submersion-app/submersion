import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:submersion/core/constants/units.dart';
import 'package:submersion/core/utils/unit_formatter.dart';
import 'package:submersion/features/dive_log/domain/entities/dive.dart';
import 'package:submersion/features/dive_log/presentation/providers/dive_providers.dart';
import 'package:submersion/features/nav_track/domain/entities/nav_track.dart';
import 'package:submersion/features/nav_track/domain/entities/nav_track_point.dart';
import 'package:submersion/features/nav_track/presentation/providers/nav_track_providers.dart';
import 'package:submersion/features/nav_track/presentation/widgets/nav_track_list_row.dart';
import 'package:submersion/features/nav_track/presentation/widgets/nav_track_shape_thumbnail.dart';
import 'package:submersion/features/settings/presentation/providers/settings_providers.dart';
import 'package:submersion/l10n/arb/app_localizations.dart';

import '../../../../helpers/mock_providers.dart';

List<NavTrackPoint> _hydratedPoints() => [
  for (var i = 0; i < 5; i++)
    NavTrackPoint(
      timestamp: 1755856800 + i * 10,
      north: i * 10.0,
      east: 0,
      depth: 5,
    ),
];

NavTrack _route({
  required String id,
  String? diveId,
  String? name,
  String? deviceName,
  double? distance,
  double? maxDepth,
  double? anchorLatitude,
  double? anchorLongitude,
}) => NavTrack(
  id: id,
  diveId: diveId,
  linkMode: diveId == null ? null : NavTrackLinkMode.auto,
  name: name,
  deviceName: deviceName,
  source: NavTrackSource.seacraftEnc,
  sourceRef: '$id.csv',
  startTime: 1755856800000,
  endTime: 1755860400000,
  pointCount: 5,
  totalDistance: distance,
  maxDepth: maxDepth,
  anchorLatitude: anchorLatitude,
  anchorLongitude: anchorLongitude,
  createdAt: DateTime(2026, 8, 22),
  updatedAt: DateTime(2026, 8, 22),
);

Widget _row(NavTrack route, {Widget? kindBadge}) => Consumer(
  builder: (context, ref, _) => ListView(
    children: [
      NavTrackListRow(
        route: route,
        units: UnitFormatter(ref.watch(settingsProvider)),
        onTap: () {},
        onDelete: () {},
        kindBadge: kindBadge,
      ),
    ],
  ),
);

Future<void> _pumpRow(
  WidgetTester tester, {
  required NavTrack route,
  Dive? linkedDive,
  Map<String, NavTrack>? hydrated,
  MockSettingsNotifier? settingsNotifier,
  List<Override> extraOverrides = const [],
  Locale? locale,
  Widget? kindBadge,
}) async {
  final overrides = await getBaseOverrides(settingsNotifier: settingsNotifier);
  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        ...overrides,
        if (linkedDive != null)
          diveProvider(linkedDive.id).overrideWith((ref) async => linkedDive),
        if (hydrated != null)
          for (final entry in hydrated.entries)
            navTrackByIdProvider(
              entry.key,
            ).overrideWith((ref) async => entry.value),
        ...extraOverrides,
      ],
      child: MaterialApp(
        locale: locale,
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: Scaffold(body: _row(route, kindBadge: kindBadge)),
      ),
    ),
  );
  await tester.pumpAndSettle();
}

void main() {
  test('the detail line joins device and the stored duration', () {
    final line = formatNavTrackDetailLine(
      lookupAppLocalizations(const Locale('en')),
      const UnitFormatter(AppSettings()),
      _route(
        id: 'r1',
        deviceName: 'Seacraft ENC3',
      ).copyWith(durationSeconds: 600),
    );
    expect(line, contains('Seacraft ENC3'));
    expect(line, endsWith('10min'));
  });

  testWidgets('a kind badge sits on the chip line, below the status line', (
    tester,
  ) async {
    await _pumpRow(
      tester,
      route: _route(id: 'r1', name: 'Wreck dive', distance: 1050, maxDepth: 38),
      kindBadge: const SizedBox(key: ValueKey('badge'), width: 10, height: 10),
    );
    final status = tester.getRect(find.textContaining(' · '));
    final badge = tester.getRect(find.byKey(const ValueKey('badge')));
    expect(badge.top, greaterThanOrEqualTo(status.bottom));
  });

  testWidgets('no delete button without a delete callback', (tester) async {
    final overrides = await getBaseOverrides();
    await tester.pumpWidget(
      ProviderScope(
        overrides: overrides,
        child: MaterialApp(
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: Scaffold(
            body: Consumer(
              builder: (context, ref, _) => ListView(
                children: [
                  NavTrackListRow(
                    route: _route(
                      id: 'r1',
                      name: 'Wreck dive',
                      anchorLatitude: 1,
                      anchorLongitude: 2,
                    ),
                    units: UnitFormatter(ref.watch(settingsProvider)),
                    onTap: () {},
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.byIcon(Icons.delete_outline), findsNothing);
  });

  testWidgets('tapping a linked row\'s chip opens the linked dive', (
    tester,
  ) async {
    final dive = Dive(
      id: 'dive-1',
      diveNumber: 412,
      dateTime: DateTime(2026, 8, 22, 10, 8),
    );
    final overrides = await getBaseOverrides();
    final router = GoRouter(
      routes: [
        GoRoute(
          path: '/',
          builder: (_, _) => Scaffold(
            body: _row(_route(id: 'r1', name: 'Wreck', diveId: 'dive-1')),
          ),
        ),
        GoRoute(
          path: '/dives/:id',
          builder: (_, state) =>
              Text('dive page ${state.pathParameters['id']}'),
        ),
      ],
    );
    addTearDown(router.dispose);
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          ...overrides,
          diveProvider('dive-1').overrideWith((ref) async => dive),
        ],
        child: MaterialApp.router(
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          routerConfig: router,
        ),
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const ValueKey('nav-track-link-chip')));
    await tester.pumpAndSettle();

    expect(find.text('dive page dive-1'), findsOneWidget);
  });

  testWidgets('renders route rows with distance, depth and an unlinked chip', (
    tester,
  ) async {
    await _pumpRow(
      tester,
      route: _route(
        id: 'r1',
        name: 'Wreck dive',
        deviceName: 'Seacraft ENC3',
        distance: 1050,
        maxDepth: 38,
      ),
    );

    expect(find.text('Wreck dive'), findsOneWidget);
    expect(find.text('unlinked'), findsOneWidget);
  });

  testWidgets('a linked route shows a Dive # chip instead of unlinked', (
    tester,
  ) async {
    final dive = Dive(
      id: 'dive-1',
      diveNumber: 412,
      dateTime: DateTime(2026, 8, 22, 10, 8),
    );
    await _pumpRow(
      tester,
      route: _route(id: 'r1', name: 'Wreck dive', diveId: 'dive-1'),
      linkedDive: dive,
    );

    expect(find.text('unlinked'), findsNothing);
    expect(find.textContaining('Dive'), findsOneWidget);
    expect(find.textContaining('#412'), findsOneWidget);
  });

  testWidgets(
    'a linked row keeps its name and status line readable on a narrow '
    'phone in German (#2692)',
    (tester) async {
      // "Tauchgang #412" is far wider than "Dive #412". A ListTile measures
      // its trailing widget against the full tile width first, so a link chip
      // there starved the file name down to one fragment per line.
      await tester.binding.setSurfaceSize(const Size(360, 800));
      addTearDown(() => tester.binding.setSurfaceSize(null));

      const name = '011.DAT.csv';
      final dive = Dive(
        id: 'dive-1',
        diveNumber: 412,
        dateTime: DateTime(2026, 8, 22, 10, 8),
      );
      await _pumpRow(
        tester,
        route: _route(
          id: 'r1',
          name: name,
          diveId: 'dive-1',
          deviceName: 'Seacraft ENC3',
          distance: 1050,
          maxDepth: 38,
        ),
        linkedDive: dive,
        locale: const Locale('de'),
      );

      final title = tester.getRect(find.text(name));
      final status = tester.getRect(find.textContaining(' · '));
      final chip = tester.getRect(
        find.byKey(const ValueKey('nav-track-link-chip')),
      );

      expect(
        title.width,
        greaterThan(150),
        reason:
            'Name collapsed to ${title.width}px wide on a 360px screen; the '
            'link chip is starving the ListTile text column.',
      );
      expect(status.width, greaterThan(150));
      expect(
        chip.top,
        greaterThanOrEqualTo(status.bottom),
        reason: 'The link chip belongs on its own line below the status line.',
      );
    },
  );

  testWidgets(
    'the list row\'s date uses the wall-clock-as-UTC convention, not the '
    'host\'s local timezone (route.startTime, like dives.entryTime, is a '
    'wall-clock-as-UTC epoch)',
    (tester) async {
      // 23:30 UTC: on any host east of UTC (including this repo's own dev/CI
      // offset), a `.fromMillisecondsSinceEpoch` WITHOUT `isUtc: true` rolls
      // this over to the next local calendar day, changing the digits
      // `yyyymmdd` renders below. On a host west of UTC it would instead
      // roll BACK to 2026-03-27; either way, only isUtc: true keeps it at
      // 2026-03-28.
      final startTime = DateTime.utc(
        2026,
        3,
        28,
        23,
        30,
      ).millisecondsSinceEpoch;
      final settings = MockSettingsNotifier();
      await settings.setDateFormat(DateFormatPreference.yyyymmdd);

      await _pumpRow(
        tester,
        route: _route(
          id: 'r1',
          name: 'Wreck dive',
        ).copyWith(startTime: startTime, endTime: startTime + 600000),
        settingsNotifier: settings,
      );

      expect(find.textContaining('2026-03-28'), findsOneWidget);
      expect(find.textContaining('2026-03-29'), findsNothing);
    },
  );

  testWidgets(
    'an unanchored route\'s shape thumbnail renders the actual route, not '
    'an empty shape (item 9: the list query omits points, so the thumbnail '
    'must hydrate them itself rather than reading the unhydrated list row)',
    (tester) async {
      final listRow = _route(id: 'r1', name: 'Wreck dive');
      final hydratedRoute = listRow.copyWith(points: _hydratedPoints());
      await _pumpRow(tester, route: listRow, hydrated: {'r1': hydratedRoute});

      final thumbnail = tester.widget<NavTrackShapeThumbnail>(
        find.byType(NavTrackShapeThumbnail),
      );
      expect(thumbnail.points, isNotEmpty);
      expect(thumbnail.points, hydratedRoute.points);
    },
  );

  testWidgets(
    'the list row shows the stored dive duration, not the raw recording '
    'span, without loading the route\'s points',
    (tester) async {
      // Stored at import: 10 min up to the last dead-reckoned sample. The
      // raw file runs on for an hour after the GPS fix.
      final listRow = _route(
        id: 'r1',
        name: 'Wreck dive',
        anchorLatitude: 47.1,
        anchorLongitude: 8.3,
      ).copyWith(startTime: 0, endTime: 4200 * 1000, durationSeconds: 600);
      var hydrations = 0;
      await _pumpRow(
        tester,
        route: listRow,
        extraOverrides: [
          navTrackByIdProvider('r1').overrideWith((ref) async {
            hydrations++;
            return null;
          }),
        ],
      );

      expect(find.textContaining('10min'), findsOneWidget);
      expect(find.textContaining('1h 10min'), findsNothing);
      expect(hydrations, 0);
    },
  );
}
