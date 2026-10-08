import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/core/providers/provider.dart';
import 'package:submersion/features/dive_sites/presentation/providers/site_providers.dart';
import 'package:submersion/features/media/data/services/media_serving_recorder.dart';
import 'package:submersion/features/media/domain/entities/media_item.dart';
import 'package:submersion/features/media/domain/entities/media_library_filter.dart';
import 'package:submersion/features/media/domain/entities/media_source_type.dart';
import 'package:submersion/features/media/presentation/pages/media_library_view.dart';
import 'package:submersion/features/media/presentation/providers/media_library_providers.dart';
import 'package:submersion/features/media/presentation/providers/media_map_providers.dart';
import 'package:submersion/features/media/presentation/providers/media_provenance_providers.dart';
import 'package:submersion/features/media/presentation/providers/media_serving_providers.dart';
import 'package:submersion/features/media/presentation/widgets/media_library_grid.dart';
import 'package:submersion/features/media/presentation/widgets/media_map_content.dart';
import 'package:submersion/features/media_store/presentation/providers/media_store_providers.dart';
import 'package:submersion/features/settings/data/repositories/app_settings_repository.dart';
import 'package:submersion/features/settings/presentation/providers/settings_providers.dart';
import 'package:submersion/features/trips/presentation/providers/trip_providers.dart';
import 'package:submersion/l10n/arb/app_localizations.dart';

import '../../../helpers/mock_providers.dart';

class _SeededLibraryNotifier extends StateNotifier<MediaLibraryState>
    implements MediaLibraryNotifier {
  _SeededLibraryNotifier(super.state);

  @override
  Future<void> loadFirstPage() async {}

  @override
  Future<void> loadMore() async {}

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class _SeededMapNotifier extends StateNotifier<MediaMapState>
    implements MediaMapNotifier {
  _SeededMapNotifier() : super(const MediaMapState());

  @override
  Future<void> load() async {}

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class _MapModeSettingsRepo extends AppSettingsRepository {
  @override
  Future<String?> getRawSetting(String key) async =>
      key == 'media_library_view_mode' ? 'map' : null;

  @override
  Future<void> setRawSetting(String key, String value) async {}
}

MediaLibraryEntry _entry(String id) => MediaLibraryEntry(
  item: MediaItem(
    id: id,
    mediaType: MediaType.photo,
    sourceType: MediaSourceType.platformGallery,
    platformAssetId: 'asset-$id',
    takenAt: DateTime(2026, 3, 12),
    createdAt: DateTime(2026, 3, 12),
    updatedAt: DateTime(2026, 3, 12),
  ),
);

Future<void> _pumpView(
  WidgetTester tester,
  MediaLibraryState libraryState,
) async {
  tester.view.physicalSize = const Size(1200, 900);
  tester.view.devicePixelRatio = 1.0;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);

  final base = await getBaseOverrides();
  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        ...base,
        mediaLibraryNotifierProvider.overrideWith(
          (ref) => _SeededLibraryNotifier(libraryState),
        ),
        mediaMapPointsProvider.overrideWith((ref) => _SeededMapNotifier()),
        appSettingsRepositoryProvider.overrideWithValue(_MapModeSettingsRepo()),
        sitesProvider.overrideWith((ref) async => const []),
        allTripsProvider.overrideWith((ref) async => const []),
        mediaStoreAttachedProvider.overrideWith((ref) async => true),
        mediaQueueFactsProvider.overrideWith((ref, id) => Stream.value(null)),
        mediaStoreIdentityProvider.overrideWith((ref) async => null),
        currentDeviceIdProvider.overrideWith((ref) async => 'dev-a'),
        mediaServingRecorderProvider.overrideWithValue(MediaServingRecorder()),
      ],
      child: const MaterialApp(
        locale: Locale('en'),
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: Scaffold(body: MediaLibraryView()),
      ),
    ),
  );
  await tester.pump();
  await tester.pump(const Duration(seconds: 1));
}

void main() {
  // The map has its own loading, empty and error states; the grid's paged
  // state must not stand in for them.
  testWidgets('map mode renders the map even when the grid page is empty', (
    tester,
  ) async {
    await _pumpView(tester, const MediaLibraryState());

    expect(find.byType(MediaMapContent), findsOneWidget);
    expect(find.text('No media yet'), findsNothing);
    await tester.pump(const Duration(milliseconds: 400));
  });

  testWidgets('map mode renders the map while the grid page is loading', (
    tester,
  ) async {
    await _pumpView(tester, const MediaLibraryState(isLoading: true));

    expect(find.byType(MediaMapContent), findsOneWidget);
    await tester.pump(const Duration(milliseconds: 400));
  });

  testWidgets('the persisted map mode renders the map instead of the grid', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(1200, 900);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    final base = await getBaseOverrides();
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          ...base,
          mediaLibraryNotifierProvider.overrideWith(
            (ref) => _SeededLibraryNotifier(
              MediaLibraryState(entries: [_entry('a')]),
            ),
          ),
          mediaMapPointsProvider.overrideWith((ref) => _SeededMapNotifier()),
          appSettingsRepositoryProvider.overrideWithValue(
            _MapModeSettingsRepo(),
          ),
          sitesProvider.overrideWith((ref) async => const []),
          allTripsProvider.overrideWith((ref) async => const []),
          mediaStoreAttachedProvider.overrideWith((ref) async => true),
          mediaQueueFactsProvider.overrideWith((ref, id) => Stream.value(null)),
          mediaStoreIdentityProvider.overrideWith((ref) async => null),
          currentDeviceIdProvider.overrideWith((ref) async => 'dev-a'),
          mediaServingRecorderProvider.overrideWithValue(
            MediaServingRecorder(),
          ),
        ],
        child: const MaterialApp(
          locale: Locale('en'),
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: Scaffold(body: MediaLibraryView()),
        ),
      ),
    );
    await tester.pump();
    await tester.pump(const Duration(seconds: 1));

    expect(find.byType(MediaMapContent), findsOneWidget);
    expect(find.byType(MediaLibraryGrid), findsNothing);
    await tester.pump(const Duration(milliseconds: 400));
  });
}
