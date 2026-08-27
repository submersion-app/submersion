import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
// Override is not re-exported by flutter_riverpod; test/helpers/mock_providers
// reaches for it the same way.
// ignore: implementation_imports
import 'package:riverpod/src/framework.dart' show Override;
import 'package:submersion/core/providers/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:submersion/features/media/data/services/media_source_resolver_registry.dart';
import 'package:submersion/features/media/domain/entities/media_item.dart';
import 'package:submersion/features/media/domain/entities/media_source_type.dart';
import 'package:submersion/features/media/domain/services/media_source_resolver.dart';
import 'package:submersion/features/media/domain/value_objects/media_source_data.dart';
import 'package:submersion/features/media/domain/value_objects/media_source_metadata.dart';
import 'package:submersion/features/media/domain/value_objects/verify_result.dart';
import 'package:submersion/features/media/presentation/pages/media_viewer_page.dart';
import 'package:submersion/features/media/presentation/pages/photo_viewer_page.dart';
import 'package:submersion/features/media/presentation/pages/trip_photo_viewer_page.dart';
import 'package:submersion/features/media/presentation/providers/media_providers.dart';
import 'package:submersion/features/media/presentation/providers/media_resolver_providers.dart';
import 'package:submersion/features/settings/presentation/providers/settings_providers.dart';
import 'package:submersion/features/trips/presentation/providers/trip_media_providers.dart';
import 'package:submersion/l10n/arb/app_localizations.dart';

import '../../../../helpers/test_database.dart';

class _UnavailableResolver implements MediaSourceResolver {
  @override
  MediaSourceType get sourceType => MediaSourceType.platformGallery;
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
  Future<MediaSourceMetadata?> extractMetadata(MediaItem item) async => null;
  @override
  Future<VerifyResult> verify(MediaItem item) async => VerifyResult.available;
}

MediaItem item(String id, {String? diveId}) => MediaItem(
  id: id,
  diveId: diveId,
  mediaType: MediaType.photo,
  sourceType: MediaSourceType.platformGallery,
  takenAt: DateTime.utc(2026, 7, 1, 10),
  createdAt: DateTime.utc(2026, 7, 1),
  updatedAt: DateTime.utc(2026, 7, 1),
);

/// Both wrappers are the same shape: watch a list provider, hand the data to
/// MediaViewerPage, and render their own loading and error scaffolds. The
/// two failure states are the point -- they are what a diver sees when the
/// dive or trip query is slow or broken, and neither had any coverage.
void main() {
  late SharedPreferences prefs;

  setUp(() async {
    await setUpTestDatabase();
    SharedPreferences.setMockInitialValues({});
    prefs = await SharedPreferences.getInstance();
  });

  tearDown(tearDownTestDatabase);

  Future<void> pump(
    WidgetTester tester,
    Widget home,
    List<Override> overrides,
  ) async {
    await tester.runAsync(() async {
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            sharedPreferencesProvider.overrideWithValue(prefs),
            mediaSourceResolverRegistryProvider.overrideWithValue(
              MediaSourceResolverRegistry({
                MediaSourceType.platformGallery: _UnavailableResolver(),
              }),
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
      await Future<void>.delayed(const Duration(milliseconds: 100));
      await tester.pump();
      await Future<void>.delayed(const Duration(milliseconds: 100));
      await tester.pump();
    });
  }

  group('PhotoViewerPage', () {
    testWidgets('hands the dive list to the shared viewer', (tester) async {
      await pump(
        tester,
        const PhotoViewerPage(diveId: 'd1', initialMediaId: 'm2'),
        [
          mediaForDiveProvider.overrideWith(
            (ref, id) async => [item('m1'), item('m2')],
          ),
        ],
      );
      expect(find.byType(MediaViewerPage), findsOneWidget);
    });

    testWidgets('shows a spinner while the dive list loads', (tester) async {
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            sharedPreferencesProvider.overrideWithValue(prefs),
            mediaForDiveProvider.overrideWith(
              (ref, id) => Completer<List<MediaItem>>().future,
            ),
          ],
          child: const MaterialApp(
            home: PhotoViewerPage(diveId: 'd1', initialMediaId: 'm1'),
          ),
        ),
      );
      await tester.pump();
      expect(find.byType(CircularProgressIndicator), findsOneWidget);
      expect(find.byType(MediaViewerPage), findsNothing);
    });

    testWidgets('surfaces a failed dive query instead of a blank screen', (
      tester,
    ) async {
      await pump(
        tester,
        const PhotoViewerPage(diveId: 'd1', initialMediaId: 'm1'),
        [
          mediaForDiveProvider.overrideWith(
            (ref, id) async => throw StateError('dive query failed'),
          ),
        ],
      );
      expect(find.textContaining('dive query failed'), findsOneWidget);
      expect(find.byType(MediaViewerPage), findsNothing);
    });
  });

  group('TripPhotoViewerPage', () {
    testWidgets('hands the trip list to the shared viewer', (tester) async {
      await pump(
        tester,
        const TripPhotoViewerPage(tripId: 't1', initialMediaId: 'm1'),
        [
          flatMediaListForTripProvider.overrideWith(
            (ref, id) async => [item('m1')],
          ),
        ],
      );
      expect(find.byType(MediaViewerPage), findsOneWidget);
    });

    testWidgets('shows a spinner while the trip list loads', (tester) async {
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            sharedPreferencesProvider.overrideWithValue(prefs),
            flatMediaListForTripProvider.overrideWith(
              (ref, id) => Completer<List<MediaItem>>().future,
            ),
          ],
          child: const MaterialApp(
            home: TripPhotoViewerPage(tripId: 't1', initialMediaId: 'm1'),
          ),
        ),
      );
      await tester.pump();
      expect(find.byType(CircularProgressIndicator), findsOneWidget);
    });

    testWidgets('surfaces a failed trip query instead of a blank screen', (
      tester,
    ) async {
      await pump(
        tester,
        const TripPhotoViewerPage(tripId: 't1', initialMediaId: 'm1'),
        [
          flatMediaListForTripProvider.overrideWith(
            (ref, id) async => throw StateError('trip query failed'),
          ),
        ],
      );
      expect(find.textContaining('trip query failed'), findsOneWidget);
      expect(find.byType(MediaViewerPage), findsNothing);
    });

    testWidgets('Go to dive keeps the trip gallery beneath the dive', (
      tester,
    ) async {
      // TripPhotoViewerPage is the OTHER showGoToDive consumer, so the shared
      // callback silently retargets this surface too. Without coverage a
      // change to trip routing could regress it with the suite green.
      final router = GoRouter(
        initialLocation: '/trips/t1/gallery',
        routes: [
          ShellRoute(
            builder: (context, state, child) => Scaffold(body: child),
            routes: [
              GoRoute(
                path: '/trips/:tripId/gallery',
                builder: (context, state) => const TripPhotoViewerPage(
                  tripId: 't1',
                  initialMediaId: 'm1',
                ),
              ),
              GoRoute(
                path: '/dives',
                builder: (context, state) => const Text('Dive List'),
                routes: [
                  GoRoute(
                    path: ':diveId',
                    builder: (context, state) => Scaffold(
                      appBar: AppBar(),
                      body: const Text('Dive Detail'),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ],
      );
      addTearDown(router.dispose);

      await tester.runAsync(() async {
        await tester.pumpWidget(
          ProviderScope(
            overrides: [
              sharedPreferencesProvider.overrideWithValue(prefs),
              mediaSourceResolverRegistryProvider.overrideWithValue(
                MediaSourceResolverRegistry({
                  MediaSourceType.platformGallery: _UnavailableResolver(),
                }),
              ),
              flatMediaListForTripProvider.overrideWith(
                (ref, id) async => [item('m1', diveId: 'd1')],
              ),
            ],
            child: MaterialApp.router(
              routerConfig: router,
              locale: const Locale('en'),
              localizationsDelegates: AppLocalizations.localizationsDelegates,
              supportedLocales: AppLocalizations.supportedLocales,
            ),
          ),
        );
        await Future<void>.delayed(const Duration(milliseconds: 100));
        await tester.pump();
        await Future<void>.delayed(const Duration(milliseconds: 100));
        await tester.pump();
      });

      await tester.tap(find.byTooltip('Go to dive'));
      await tester.pumpAndSettle();

      expect(find.text('Dive Detail'), findsOneWidget);
      expect(router.state.uri.toString(), '/dives/d1');
      expect(find.text('Dive List', skipOffstage: false), findsNothing);

      await tester.tap(find.byType(BackButton));
      await tester.pumpAndSettle();
      expect(find.byType(MediaViewerPage), findsOneWidget);
    });
  });
}
