import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/misc.dart' show Override;
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:submersion/core/database/database.dart' hide Dive;
import 'package:submersion/core/platform/device_capabilities.dart';
import 'package:submersion/features/dive_log/domain/entities/dive.dart';
import 'package:submersion/features/dive_log/presentation/providers/dive_providers.dart';
import 'package:submersion/features/media/data/repositories/media_repository.dart';
import 'package:submersion/features/media/data/services/media_source_resolver_registry.dart';
import 'package:submersion/features/media/domain/entities/media_item.dart';
import 'package:submersion/features/media/domain/entities/media_source_type.dart';
import 'package:submersion/features/media/domain/entities/photo_record.dart';
import 'package:submersion/features/media/domain/services/media_source_resolver.dart';
import 'package:submersion/features/media/domain/value_objects/media_source_data.dart';
import 'package:submersion/features/media/domain/value_objects/verify_result.dart';
import 'package:submersion/features/media/presentation/pages/media_viewer_page.dart';
import 'package:submersion/features/media/presentation/providers/media_resolver_providers.dart';
import 'package:submersion/features/media/presentation/widgets/media_viewer_toolbar.dart';
import 'package:submersion/features/settings/presentation/providers/settings_providers.dart';
import 'package:submersion/l10n/arb/app_localizations.dart';
import 'package:submersion/shared/widgets/record_editing/record_edit_controller.dart';

import '../../data/repositories/species_photo_fixtures.dart';

/// A resolver that finds nothing, so a page draws its placeholder at once.
class _Unavailable implements MediaSourceResolver {
  _Unavailable(this.sourceType);
  @override
  final MediaSourceType sourceType;
  @override
  bool canResolveOnThisDevice(MediaItem item) => true;
  @override
  Future<MediaSourceData> resolve(MediaItem item) async =>
      const UnavailableData(kind: UnavailableKind.notFound);
  @override
  Future<MediaSourceData> resolveThumbnail(
    MediaItem item, {
    required Size target,
  }) => resolve(item);
  @override
  Future<VerifyResult> verify(MediaItem item) async => VerifyResult.available;
}

/// A dive whose profile lets a photo be placed in time.
final harnessDive = Dive(
  id: 'd1',
  dateTime: DateTime.utc(2024, 1, 10, 9),
  profile: const [
    DiveProfilePoint(timestamp: 0, depth: 0.0),
    DiveProfilePoint(timestamp: 100, depth: 10.0),
    DiveProfilePoint(timestamp: 200, depth: 20.0),
    DiveProfilePoint(timestamp: 300, depth: 10.0),
  ],
);

/// Seeds the test database with a diver, a site, dive `d1`, photos `p1` to
/// `p3` on it and `lib` with no dive, a species and two buddies.
Future<void> seedViewerData() async {
  await insertTestDiver('me');
  await insertTestSite('s1', 'Blue Hole');
  await insertTestDive(
    id: 'd1',
    at: DateTime(2024, 1, 10, 9),
    siteId: 's1',
    diverId: 'me',
  );
  await insertTestSpecies(id: 'sp_turtle', name: 'Turtle');
  await insertTestBuddy(id: 'b1', name: 'Ann', diverId: 'me');
  await insertTestBuddy(id: 'b2', name: 'Bo', diverId: 'me');
  for (final id in ['p1', 'p2', 'p3']) {
    await insertTestMedia(
      id: id,
      diveId: 'd1',
      takenAt: DateTime(2024, 1, 10, 9, 2),
    );
  }
  await insertTestMedia(id: 'lib', takenAt: DateTime(2024, 1, 10, 9, 2));
}

/// Stored media rows, read as the viewer's callers read them.
Future<List<MediaItem>> storedMedia(List<String> ids) async {
  final repository = MediaRepository();
  return [for (final id in ids) (await repository.getMediaById(id))!];
}

/// How many change log events the database holds: every table the viewer
/// writes is tracked, so a count that does not move means nothing was
/// written.
Future<int> eventCount(AppDatabase db) async {
  final row = await db
      .customSelect('SELECT COUNT(*) AS n FROM change_log_events')
      .getSingle();
  return row.read<int>('n');
}

/// Lets real async work (database reads, provider ticks) land between
/// frames, without settling animations that never end.
Future<void> settleViewer(WidgetTester tester, {int rounds = 6}) async {
  for (var i = 0; i < rounds; i++) {
    await tester.runAsync(
      () => Future<void>.delayed(const Duration(milliseconds: 30)),
    );
    await tester.pump(const Duration(milliseconds: 50));
  }
}

/// Pumps [home] in an app with the test database's repositories, a
/// resolver that finds nothing, and [harnessDive] for `d1`.
Future<void> pumpViewerApp(
  WidgetTester tester,
  Widget home, {
  Size size = const Size(1280, 800),
  bool browser = false,
  List<Override> overrides = const [],
}) async {
  tester.view.physicalSize = size;
  tester.view.devicePixelRatio = 1.0;
  addTearDown(tester.view.reset);
  SharedPreferences.setMockInitialValues({});
  final prefs = await tester.runAsync(SharedPreferences.getInstance);
  await tester.runAsync(() async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          sharedPreferencesProvider.overrideWithValue(prefs!),
          mediaSourceResolverRegistryProvider.overrideWithValue(
            MediaSourceResolverRegistry({
              for (final type in MediaSourceType.values)
                type: _Unavailable(type),
            }),
          ),
          diveProvider('d1').overrideWith((ref) async => harnessDive),
          if (browser)
            deviceCapabilitiesProvider.overrideWithValue(
              DeviceCapabilities.web,
            ),
          ...overrides,
        ],
        child: MaterialApp(
          locale: const Locale('en'),
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: home,
        ),
      ),
    );
  });
  await settleViewer(tester);
}

/// Pumps the viewer on [ids], opened at [initial].
Future<void> pumpViewer(
  WidgetTester tester, {
  List<String> ids = const ['p1', 'p2', 'p3'],
  String initial = 'p2',
  bool showGoToDive = false,
  Size size = const Size(1280, 800),
  bool browser = false,
}) async {
  final items = await tester.runAsync(() => storedMedia(ids));
  await pumpViewerApp(
    tester,
    MediaViewerPage(
      mediaList: items!,
      initialMediaId: initial,
      showGoToDive: showGoToDive,
    ),
    size: size,
    browser: browser,
  );
}

/// The viewer's editing controller, read through its scope.
RecordEditController<PhotoRecord> photoController(WidgetTester tester) =>
    RecordEditScope.maybeOf<PhotoRecord>(
      tester.element(find.byType(MediaViewerToolbar)),
    )!;

Future<void> tapUnlock(WidgetTester tester) async {
  await tester.tap(find.byKey(const ValueKey('viewer_unlock')));
  await settleViewer(tester);
}

/// A home page whose "open" button pushes [page], so a test can see [page]
/// close itself and what it says on the page below.
Widget pushedFrom(Widget page) => Builder(
  builder: (context) => Scaffold(
    body: Center(
      child: TextButton(
        onPressed: () => Navigator.of(
          context,
        ).push(MaterialPageRoute<void>(builder: (_) => page)),
        child: const Text('open'),
      ),
    ),
  ),
);

/// Opens the page [pushedFrom] holds.
Future<void> openPushed(WidgetTester tester) async {
  await tester.tap(find.text('open'));
  await settleViewer(tester);
}
