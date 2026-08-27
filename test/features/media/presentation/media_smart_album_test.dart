import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/core/providers/provider.dart';
import 'package:submersion/features/media/data/repositories/media_smart_album_repository.dart';
import 'package:submersion/features/media/domain/entities/media_item.dart';
import 'package:submersion/features/media/domain/entities/media_library_filter.dart';
import 'package:submersion/features/media/domain/entities/media_smart_album.dart';
import 'package:submersion/features/media/presentation/providers/media_library_providers.dart';
import 'package:submersion/features/media/presentation/providers/media_smart_album_providers.dart';
import 'package:submersion/features/media/presentation/widgets/media_library_active_filter_chips.dart';
import 'package:submersion/features/media/presentation/widgets/media_library_filter_sheet.dart';
import 'package:submersion/features/dive_sites/presentation/providers/site_providers.dart';
import 'package:submersion/features/trips/presentation/providers/trip_providers.dart';
import 'package:submersion/l10n/arb/app_localizations.dart';

class _FakeAlbumRepo implements MediaSmartAlbumRepository {
  _FakeAlbumRepo(this.albums);

  final List<MediaSmartAlbum> albums;
  final List<MediaSmartAlbum> created = [];
  final List<String> deleted = [];

  /// When set, [delete] throws instead of recording -- the stand-in for a
  /// database that will not take the write.
  Object? deleteError;

  @override
  Future<List<MediaSmartAlbum>> getAll() async => albums;

  @override
  Future<MediaSmartAlbum> create({
    required String name,
    required MediaLibraryFilter filter,
  }) async {
    final album = MediaSmartAlbum(
      id: 'new-${created.length}',
      name: name,
      filter: filter,
      createdAt: DateTime(2026, 8, 6),
      updatedAt: DateTime(2026, 8, 6),
    );
    created.add(album);
    return album;
  }

  @override
  Future<void> delete(String id) async {
    final error = deleteError;
    if (error != null) throw error;
    deleted.add(id);
  }

  @override
  Stream<void> watchChanges() => const Stream.empty();

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

MediaSmartAlbum album(String id, String name, MediaLibraryFilter filter) =>
    MediaSmartAlbum(
      id: id,
      name: name,
      filter: filter,
      createdAt: DateTime(2026, 8, 6),
      updatedAt: DateTime(2026, 8, 6),
    );

void main() {
  late _FakeAlbumRepo repo;
  late ProviderContainer container;

  setUp(() => repo = _FakeAlbumRepo([]));

  /// Built per test rather than in setUp: several tests replace [repo] with
  /// a seeded one first, and the container has to close over that instance.
  ProviderContainer buildContainer() {
    container = ProviderContainer(
      overrides: [
        sitesProvider.overrideWith((ref) async => []),
        allTripsProvider.overrideWith((ref) async => []),
        mediaSmartAlbumRepositoryProvider.overrideWithValue(repo),
      ],
    );
    addTearDown(container.dispose);
    return container;
  }

  void setWide(WidgetTester tester) {
    tester.view.physicalSize = const Size(1600, 1800);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
  }

  Widget wrap(Widget child) => UncontrolledProviderScope(
    container: buildContainer(),
    child: MaterialApp(
      locale: const Locale('en'),
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      home: Scaffold(body: child),
    ),
  );

  group('saving an album from the active filter chips', () {
    Widget host() => wrap(const MediaLibraryActiveFilterChips());

    /// The chip strip renders nothing on an empty filter, so a test that
    /// needs it visible has to put something in the filter first.
    Future<void> pumpFiltered(WidgetTester tester) async {
      setWide(tester);
      await tester.pumpWidget(host());
      container.read(mediaLibraryFilterProvider.notifier).state =
          const MediaLibraryFilter(mediaType: MediaType.photo);
      await tester.pumpAndSettle();
    }

    testWidgets('the save action only appears once the filter says something', (
      tester,
    ) async {
      setWide(tester);
      await tester.pumpWidget(host());
      await tester.pumpAndSettle();

      expect(find.text('Save as album'), findsNothing);

      container.read(mediaLibraryFilterProvider.notifier).state =
          const MediaLibraryFilter(mediaType: MediaType.photo);
      await tester.pumpAndSettle();

      expect(find.text('Save as album'), findsOneWidget);
    });

    testWidgets('saving names the album and stores the live filter', (
      tester,
    ) async {
      await pumpFiltered(tester);

      await tester.tap(find.text('Save as album'));
      await tester.pumpAndSettle();

      expect(find.text('Name this album'), findsOneWidget);
      await tester.enterText(find.byType(TextField), '  Wide angle  ');
      await tester.pumpAndSettle();
      await tester.tap(find.text('Save'));
      await tester.pumpAndSettle();

      expect(repo.created, hasLength(1));
      expect(repo.created.single.name, 'Wide angle');
      expect(repo.created.single.filter.mediaType, MediaType.photo);
      expect(find.text('Album saved'), findsOneWidget);
      expect(tester.takeException(), isNull);
    });

    testWidgets('cancelling the name dialog saves nothing', (tester) async {
      await pumpFiltered(tester);

      await tester.tap(find.text('Save as album'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Cancel'));
      await tester.pumpAndSettle();

      expect(repo.created, isEmpty);
      expect(tester.takeException(), isNull);
    });

    testWidgets('an empty name cannot be saved', (tester) async {
      await pumpFiltered(tester);

      await tester.tap(find.text('Save as album'));
      await tester.pumpAndSettle();
      await tester.enterText(find.byType(TextField), '   ');
      await tester.pumpAndSettle();

      final save = tester.widget<FilledButton>(
        find.widgetWithText(FilledButton, 'Save'),
      );
      expect(save.onPressed, isNull);
    });
  });

  group('loading an album from the filter sheet', () {
    Widget host() => wrap(
      Builder(
        builder: (context) => TextButton(
          onPressed: () => showMediaLibraryFilterSheet(context),
          child: const Text('open'),
        ),
      ),
    );

    Future<void> openSheet(WidgetTester tester) async {
      setWide(tester);
      await tester.pumpWidget(host());
      await tester.tap(find.text('open'));
      await tester.pumpAndSettle();
    }

    testWidgets('the load action stays hidden while there are no albums', (
      tester,
    ) async {
      await openSheet(tester);

      expect(find.text('Load album'), findsNothing);
    });

    testWidgets('applying an album writes its filter to the library', (
      tester,
    ) async {
      repo = _FakeAlbumRepo([
        album(
          'a1',
          'Blue Hole video',
          const MediaLibraryFilter(
            siteId: 'site-1',
            mediaType: MediaType.video,
          ),
        ),
        album('a2', 'Everything else', MediaLibraryFilter.none),
      ]);
      await openSheet(tester);

      await tester.tap(find.text('Load album'));
      await tester.pumpAndSettle();

      expect(find.text('Blue Hole video'), findsOneWidget);
      expect(find.text('Everything else'), findsOneWidget);

      await tester.tap(find.text('Blue Hole video'));
      await tester.pumpAndSettle();
      // The album only drafts the facets; Apply is what commits them.
      await tester.tap(find.text('Apply'));
      await tester.pumpAndSettle();

      final filter = container.read(mediaLibraryFilterProvider);
      expect(filter.siteId, 'site-1');
      expect(filter.mediaType, MediaType.video);
    });

    testWidgets('deleting an album from the list calls the repository', (
      tester,
    ) async {
      repo = _FakeAlbumRepo([
        album('a1', 'Blue Hole video', const MediaLibraryFilter(siteId: 's1')),
      ]);
      await openSheet(tester);

      await tester.tap(find.text('Load album'));
      await tester.pumpAndSettle();
      await tester.tap(find.byIcon(Icons.delete_outline));
      await tester.pumpAndSettle();

      expect(repo.deleted, ['a1']);
      // Deleting must not also apply the album it removed.
      expect(container.read(mediaLibraryFilterProvider).siteId, isNull);
    });

    testWidgets('a delete that fails says so instead of failing silently', (
      tester,
    ) async {
      // The album list is dismissed before the delete runs, so the failure
      // has to find its way to the sheet's own context or it has nowhere to
      // show.
      repo = _FakeAlbumRepo([
        album('a1', 'Blue Hole video', const MediaLibraryFilter(siteId: 's1')),
      ])..deleteError = StateError('database is not having it');
      await openSheet(tester);

      await tester.tap(find.text('Load album'));
      await tester.pumpAndSettle();
      await tester.tap(find.byIcon(Icons.delete_outline));
      await tester.pumpAndSettle();

      expect(repo.deleted, isEmpty);
      expect(find.text('Could not delete album'), findsOneWidget);
    });
  });
}
