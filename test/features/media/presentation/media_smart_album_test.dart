import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/core/providers/provider.dart';
import 'package:submersion/features/media/data/repositories/media_smart_album_repository.dart';
import 'package:submersion/features/media/domain/entities/media_item.dart';
import 'package:submersion/features/media/domain/entities/media_library_filter.dart';
import 'package:submersion/features/media/domain/entities/media_smart_album.dart';
import 'package:submersion/features/media/presentation/providers/media_library_providers.dart';
import 'package:submersion/features/media/presentation/providers/media_smart_album_providers.dart';
import 'package:submersion/features/media/presentation/widgets/media_library_filter_bar.dart';
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

  setUp(() => repo = _FakeAlbumRepo([]));

  Widget host() {
    return ProviderScope(
      overrides: [
        sitesProvider.overrideWith((ref) async => []),
        allTripsProvider.overrideWith((ref) async => []),
        mediaSmartAlbumRepositoryProvider.overrideWithValue(repo),
      ],
      child: const MaterialApp(
        locale: Locale('en'),
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: Scaffold(body: MediaLibraryFilterBar()),
      ),
    );
  }

  ProviderContainer containerOf(WidgetTester tester) =>
      ProviderScope.containerOf(
        tester.element(find.byType(MediaLibraryFilterBar)),
      );

  void setWide(WidgetTester tester) {
    tester.view.physicalSize = const Size(1600, 800);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
  }

  testWidgets('the save action only appears once the filter says something', (
    tester,
  ) async {
    setWide(tester);
    await tester.pumpWidget(host());
    await tester.pumpAndSettle();

    expect(find.text('Save as album'), findsNothing);

    await tester.tap(find.text('Photos'));
    await tester.pumpAndSettle();

    expect(find.text('Save as album'), findsOneWidget);
  });

  testWidgets('saving names the album and stores the live filter', (
    tester,
  ) async {
    setWide(tester);
    await tester.pumpWidget(host());
    await tester.pumpAndSettle();

    await tester.tap(find.text('Photos'));
    await tester.pumpAndSettle();
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
    setWide(tester);
    await tester.pumpWidget(host());
    await tester.pumpAndSettle();

    await tester.tap(find.text('Photos'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Save as album'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Cancel'));
    await tester.pumpAndSettle();

    expect(repo.created, isEmpty);
    expect(tester.takeException(), isNull);
  });

  testWidgets('an empty name cannot be saved', (tester) async {
    setWide(tester);
    await tester.pumpWidget(host());
    await tester.pumpAndSettle();

    await tester.tap(find.text('Photos'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Save as album'));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextField), '   ');
    await tester.pumpAndSettle();

    final save = tester.widget<FilledButton>(
      find.widgetWithText(FilledButton, 'Save'),
    );
    expect(save.onPressed, isNull);
  });

  testWidgets('the albums chip stays hidden while there are no albums', (
    tester,
  ) async {
    setWide(tester);
    await tester.pumpWidget(host());
    await tester.pumpAndSettle();

    expect(find.text('Albums'), findsNothing);
  });

  testWidgets('applying an album writes its filter to the library', (
    tester,
  ) async {
    repo = _FakeAlbumRepo([
      album(
        'a1',
        'Blue Hole video',
        const MediaLibraryFilter(siteId: 'site-1', mediaType: MediaType.video),
      ),
      album('a2', 'Everything else', MediaLibraryFilter.none),
    ]);
    setWide(tester);
    await tester.pumpWidget(host());
    await tester.pumpAndSettle();

    await tester.tap(find.text('Albums'));
    await tester.pumpAndSettle();

    expect(find.text('Blue Hole video'), findsOneWidget);
    expect(find.text('Everything else'), findsOneWidget);

    await tester.tap(find.text('Blue Hole video'));
    await tester.pumpAndSettle();

    final filter = containerOf(tester).read(mediaLibraryFilterProvider);
    expect(filter.siteId, 'site-1');
    expect(filter.mediaType, MediaType.video);
  });

  testWidgets('deleting an album from the menu calls the repository', (
    tester,
  ) async {
    repo = _FakeAlbumRepo([
      album('a1', 'Blue Hole video', const MediaLibraryFilter(siteId: 's1')),
    ]);
    setWide(tester);
    await tester.pumpWidget(host());
    await tester.pumpAndSettle();

    await tester.tap(find.text('Albums'));
    await tester.pumpAndSettle();
    await tester.tap(find.byIcon(Icons.delete_outline));
    await tester.pumpAndSettle();

    expect(repo.deleted, ['a1']);
    // Deleting must not also apply the album it removed.
    expect(containerOf(tester).read(mediaLibraryFilterProvider).siteId, isNull);
  });

  testWidgets('a delete that fails says so instead of failing silently', (
    tester,
  ) async {
    // The menu is dismissed before the delete runs, so the failure has to
    // find its way to the bar's own context or it has nowhere to show.
    repo = _FakeAlbumRepo([
      album('a1', 'Blue Hole video', const MediaLibraryFilter(siteId: 's1')),
    ])..deleteError = StateError('database is not having it');
    setWide(tester);
    await tester.pumpWidget(host());
    await tester.pumpAndSettle();

    await tester.tap(find.text('Albums'));
    await tester.pumpAndSettle();
    await tester.tap(find.byIcon(Icons.delete_outline));
    await tester.pumpAndSettle();

    expect(repo.deleted, isEmpty);
    expect(find.text('Could not delete album'), findsOneWidget);
  });
}
