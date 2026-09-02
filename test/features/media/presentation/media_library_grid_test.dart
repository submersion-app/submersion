import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/core/providers/provider.dart';
import 'package:submersion/features/dive_sites/presentation/providers/site_providers.dart';
import 'package:submersion/features/media/data/services/media_source_resolver_registry.dart';
import 'package:submersion/features/media/domain/entities/media_item.dart';
import 'package:submersion/features/media/domain/entities/media_library_filter.dart';
import 'package:submersion/features/media/domain/entities/media_source_type.dart';
import 'package:submersion/features/media/domain/services/media_source_resolver.dart';
import 'package:submersion/features/media/domain/value_objects/media_source_data.dart';
import 'package:submersion/features/media/domain/value_objects/media_source_metadata.dart';
import 'package:submersion/features/media/domain/value_objects/verify_result.dart';
import 'package:submersion/features/media/presentation/pages/media_library_view.dart';
import 'package:submersion/features/media/presentation/providers/media_library_providers.dart';
import 'package:submersion/features/media/presentation/providers/media_resolver_providers.dart';
import 'package:submersion/features/media/presentation/widgets/media_library_grid.dart';
import 'package:submersion/features/media/presentation/widgets/media_library_grouped_list.dart';
import 'package:submersion/features/settings/data/repositories/app_settings_repository.dart';
import 'package:submersion/features/settings/presentation/providers/settings_providers.dart';
import 'package:submersion/features/trips/presentation/providers/trip_providers.dart';
import 'package:submersion/l10n/arb/app_localizations.dart';

class _UnavailableResolver implements MediaSourceResolver {
  @override
  MediaSourceType get sourceType => MediaSourceType.localFile;
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

class _SeededLibraryNotifier extends StateNotifier<MediaLibraryState>
    implements MediaLibraryNotifier {
  _SeededLibraryNotifier(super.state);
  int loadMoreCalls = 0;

  @override
  Future<void> loadFirstPage() async {}

  @override
  Future<void> loadMore() async {
    loadMoreCalls++;
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class _FakeSettingsRepo extends AppSettingsRepository {
  final Map<String, String> values = {};

  @override
  Future<String?> getRawSetting(String key) async => values[key];

  @override
  Future<void> setRawSetting(String key, String value) async {
    values[key] = value;
  }
}

MediaLibraryEntry entry(String id) => MediaLibraryEntry(
  item: MediaItem(
    id: id,
    mediaType: MediaType.photo,
    sourceType: MediaSourceType.localFile,
    filePath: '/tmp/$id',
    localPath: '/tmp/$id',
    takenAt: DateTime(2026, 6, 1),
    createdAt: DateTime(2026, 6, 1),
    updatedAt: DateTime(2026, 6, 1),
  ),
);

void main() {
  Widget host(_SeededLibraryNotifier notifier) {
    return ProviderScope(
      overrides: [
        mediaLibraryNotifierProvider.overrideWith((ref) => notifier),
        appSettingsRepositoryProvider.overrideWithValue(_FakeSettingsRepo()),
        mediaSourceResolverRegistryProvider.overrideWithValue(
          MediaSourceResolverRegistry({
            MediaSourceType.localFile: _UnavailableResolver(),
          }),
        ),
        // The filter sheet reads both; without overrides they reach real
        // repositories that have no database under flutter test.
        sitesProvider.overrideWith((ref) async => []),
        allTripsProvider.overrideWith((ref) async => []),
      ],
      child: const MaterialApp(
        locale: Locale('en'),
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: Scaffold(body: MediaLibraryView()),
      ),
    );
  }

  testWidgets('renders one tile per entry', (tester) async {
    final notifier = _SeededLibraryNotifier(
      MediaLibraryState(entries: [entry('a'), entry('b'), entry('c')]),
    );
    await tester.pumpWidget(host(notifier));
    await tester.pumpAndSettle();
    expect(find.byType(MediaLibraryGrid), findsOneWidget);
    expect(
      tester.widgetList(find.byType(GestureDetector)).length,
      greaterThanOrEqualTo(3),
    );
  });

  testWidgets('shows localized empty state when no entries', (tester) async {
    final notifier = _SeededLibraryNotifier(const MediaLibraryState());
    await tester.pumpWidget(host(notifier));
    await tester.pumpAndSettle();
    expect(find.text('No media yet'), findsOneWidget);
  });

  testWidgets('scrolling near the end calls loadMore', (tester) async {
    final notifier = _SeededLibraryNotifier(
      MediaLibraryState(
        entries: [for (var i = 0; i < 60; i++) entry('m$i')],
        nextCursor: const MediaLibraryCursor(sortKey: 1, id: 'm59'),
      ),
    );
    await tester.pumpWidget(host(notifier));
    await tester.pumpAndSettle();
    await tester.drag(find.byType(GridView), const Offset(0, -6000));
    await tester.pumpAndSettle();
    expect(notifier.loadMoreCalls, greaterThan(0));
  });

  testWidgets('view mode switcher swaps to the grouped presentation', (
    tester,
  ) async {
    final notifier = _SeededLibraryNotifier(
      MediaLibraryState(entries: [entry('a'), entry('b')]),
    );
    await tester.pumpWidget(host(notifier));
    await tester.pumpAndSettle();
    expect(find.byType(MediaLibraryGrid), findsOneWidget);

    await tester.tap(find.byIcon(Icons.scuba_diving));
    await tester.pumpAndSettle();
    expect(find.byType(MediaLibraryGroupedList), findsOneWidget);
    expect(find.byType(MediaLibraryGrid), findsNothing);

    await tester.tap(find.byIcon(Icons.calendar_month));
    await tester.pumpAndSettle();
    expect(find.byType(MediaLibraryGroupedList), findsOneWidget);
  });

  testWidgets('the toolbar filter button reaches the sheet and applies', (
    tester,
  ) async {
    // End to end through the real view: the type facet now lives in the
    // filter sheet, so this proves the view mounts the toolbar and the
    // toolbar opens a sheet that writes the shared filter provider.
    tester.view.physicalSize = const Size(1200, 2000);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    final notifier = _SeededLibraryNotifier(
      MediaLibraryState(entries: [entry('a')]),
    );
    await tester.pumpWidget(host(notifier));
    await tester.pumpAndSettle();

    final container = ProviderScope.containerOf(
      tester.element(find.byType(MediaLibraryView)),
    );

    await tester.tap(find.byIcon(Icons.filter_list));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Videos'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Apply'));
    await tester.pumpAndSettle();

    expect(
      container.read(mediaLibraryFilterProvider).mediaType,
      MediaType.video,
    );

    await tester.tap(find.byIcon(Icons.filter_list));
    await tester.pumpAndSettle();
    await tester.tap(find.text('All'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Apply'));
    await tester.pumpAndSettle();

    expect(container.read(mediaLibraryFilterProvider).mediaType, isNull);
  });
}
