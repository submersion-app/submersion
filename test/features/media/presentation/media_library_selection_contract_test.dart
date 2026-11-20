import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/core/providers/provider.dart';
import 'package:submersion/features/media/data/services/media_source_resolver_registry.dart';
import 'package:submersion/features/media/domain/entities/media_item.dart';
import 'package:submersion/features/media/domain/entities/media_library_filter.dart';
import 'package:submersion/features/media/domain/entities/media_source_type.dart';
import 'package:submersion/features/media/domain/services/media_source_resolver.dart';
import 'package:submersion/features/media/domain/value_objects/media_source_data.dart';
import 'package:submersion/features/media/domain/value_objects/verify_result.dart';
import 'package:submersion/features/equipment/presentation/providers/gear_photo_providers.dart';
import 'package:submersion/features/media/presentation/pages/media_library_view.dart';
import 'package:submersion/features/media/presentation/pages/media_section_page.dart';
import 'package:submersion/features/media/presentation/providers/media_library_providers.dart';
import 'package:submersion/features/media/presentation/providers/media_resolver_providers.dart';
import 'package:submersion/features/media/presentation/providers/media_watcher_providers.dart';
import 'package:submersion/features/media/presentation/widgets/media_library_toolbar.dart';
import 'package:submersion/features/media_store/data/media_transfer_queue_repository.dart';
import 'package:submersion/features/media_store/presentation/providers/media_store_providers.dart';
import 'package:submersion/features/media/presentation/widgets/media_library_grid.dart';
import 'package:submersion/features/settings/data/repositories/app_settings_repository.dart';
import 'package:submersion/features/settings/presentation/providers/settings_providers.dart';
import 'package:submersion/l10n/arb/app_localizations.dart';

import '../../../helpers/plain_header_title.dart';
import '../../../helpers/selection_contract.dart';

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
  Future<VerifyResult> verify(MediaItem item) async => VerifyResult.available;
}

/// Library notifier whose page can be replaced mid-test, which is how the
/// contract's filter step narrows the visible set.
class _SeededLibraryNotifier extends StateNotifier<MediaLibraryState>
    implements MediaLibraryNotifier {
  _SeededLibraryNotifier(super.state);

  void seed(List<MediaLibraryEntry> entries) {
    state = MediaLibraryState(entries: entries);
  }

  @override
  Future<void> loadFirstPage() async {}

  @override
  Future<void> loadMore() async {}

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class _FakeSettingsRepo extends AppSettingsRepository {
  @override
  Future<String?> getRawSetting(String key) async => null;

  @override
  Future<void> setRawSetting(String key, String value) async {}
}

MediaLibraryEntry _entry(String id) => MediaLibraryEntry(
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
  testWidgets('MediaLibraryView honours the selection contract', (
    tester,
  ) async {
    late _SeededLibraryNotifier notifier;

    Widget host() {
      notifier = _SeededLibraryNotifier(
        MediaLibraryState(entries: [_entry('a'), _entry('b'), _entry('c')]),
      );
      return ProviderScope(
        overrides: [
          mediaLibraryNotifierProvider.overrideWith((ref) => notifier),
          appSettingsRepositoryProvider.overrideWithValue(_FakeSettingsRepo()),
          mediaSourceResolverRegistryProvider.overrideWithValue(
            MediaSourceResolverRegistry({
              MediaSourceType.localFile: _UnavailableResolver(),
            }),
          ),
        ],
        child: const MaterialApp(
          locale: Locale('en'),
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: Scaffold(body: MediaLibraryView()),
        ),
      );
    }

    await verifySelectionContract(
      tester,
      build: host,
      selectButton: find.byKey(const ValueKey('enter_selection')),
      firstRow: find.byType(MediaLibraryTile).first,
      // The library draws a check badge over the thumbnail rather than a
      // Checkbox, so it opts out of that one assertion only.
      indicator: CheckedIndicator.custom,
      applyFilter: (tester) async => notifier.seed([_entry('a')]),
      visibleAfterFilter: 1,
    );
  });

  // Issue #4268: switching to a grouped view mode builds a new notifier,
  // which reloads page one from no rows. The checked rows it brings back
  // stay checked.
  testWidgets('a reload from no rows keeps the rows it brings back checked', (
    tester,
  ) async {
    final notifier = _SeededLibraryNotifier(
      MediaLibraryState(entries: [_entry('a'), _entry('b')]),
    );
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          mediaLibraryNotifierProvider.overrideWith((ref) => notifier),
          appSettingsRepositoryProvider.overrideWithValue(_FakeSettingsRepo()),
          mediaSourceResolverRegistryProvider.overrideWithValue(
            MediaSourceResolverRegistry({
              MediaSourceType.localFile: _UnavailableResolver(),
            }),
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

    await tester.tap(find.byKey(const ValueKey('enter_selection')));
    await tester.pump();
    await tester.tap(find.byKey(const ValueKey('selection_select_all')));
    await tester.pump();
    expect(find.text('2 selected'), findsOneWidget);

    notifier.state = const MediaLibraryState(isLoading: true);
    await tester.pump();
    await tester.pump();
    notifier.seed([_entry('a'), _entry('b')]);
    await tester.pump();
    await tester.pump();

    expect(find.text('2 selected'), findsOneWidget);
  });

  group('with the toolbar in the desktop header (#4777)', () {
    late _SeededLibraryNotifier notifier;

    Widget host() {
      notifier = _SeededLibraryNotifier(
        MediaLibraryState(entries: [_entry('a'), _entry('b'), _entry('c')]),
      );
      return ProviderScope(
        overrides: [
          mediaLibraryNotifierProvider.overrideWith((ref) => notifier),
          appSettingsRepositoryProvider.overrideWithValue(_FakeSettingsRepo()),
          mediaSourceResolverRegistryProvider.overrideWithValue(
            MediaSourceResolverRegistry({
              MediaSourceType.localFile: _UnavailableResolver(),
            }),
          ),
          mediaTransferEntriesProvider.overrideWith(
            (ref) => Stream.value(const <MediaTransferQueueEntry>[]),
          ),
          watchedRootsProvider.overrideWith((ref) async => const <String>[]),
          gearGalleryProvider.overrideWith((ref) async => const []),
        ],
        child: MaterialApp(
          locale: const Locale('en'),
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: MediaSectionPage(
            headerTitle: plainHeaderTitle('Media', paneTitleWidth: 200),
          ),
        ),
      );
    }

    void setDesktopSize(WidgetTester tester) {
      tester.view.physicalSize = const Size(1400, 900);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
    }

    testWidgets('the page honours the selection contract', (tester) async {
      // The Select button is in the header, the rows in the body: one
      // selection has to reach both.
      setDesktopSize(tester);
      await verifySelectionContract(
        tester,
        build: host,
        selectButton: find.byKey(const ValueKey('enter_selection')),
        firstRow: find.byType(MediaLibraryTile).first,
        indicator: CheckedIndicator.custom,
        applyFilter: (tester) async => notifier.seed([_entry('a')]),
        visibleAfterFilter: 1,
      );
    });

    testWidgets('Tab goes from the last section tab straight to the filter '
        'button', (tester) async {
      // The header's own keyboard scope must not add a stop of its own: a
      // blank stop spanning the toolbar reads as focus lost.
      setDesktopSize(tester);
      await tester.pumpWidget(host());
      await tester.pump();

      Focus.of(tester.element(find.text('Equipment'))).requestFocus();
      await tester.pump();
      await tester.sendKeyEvent(LogicalKeyboardKey.tab);
      await tester.pump();

      expect(
        FocusManager.instance.primaryFocus,
        Focus.of(tester.element(find.byIcon(Icons.filter_list))),
      );
    });

    testWidgets('Escape and Cmd/Ctrl-A answer with focus on a header control', (
      tester,
    ) async {
      // A keyboard user who tabbed to Select is still on the header when
      // the mode opens, outside the Library body's own scope.
      setDesktopSize(tester);
      await tester.pumpWidget(host());
      await tester.pump();

      final toolbar = find.byType(MediaLibraryToolbar);
      expect(toolbar, findsOneWidget);
      final select = find.byKey(const ValueKey('enter_selection'));
      expect(
        find.descendant(of: toolbar, matching: select),
        findsOneWidget,
        reason: 'precondition: Select is in the header toolbar',
      );
      await tester.tap(select);
      await tester.pump();
      expect(find.text('0 selected'), findsOneWidget);

      // Focus a header control that stays put inside the mode.
      Focus.of(tester.element(find.byIcon(Icons.filter_list))).requestFocus();
      await tester.pump();

      await tester.sendKeyDownEvent(LogicalKeyboardKey.control);
      await tester.sendKeyEvent(LogicalKeyboardKey.keyA);
      await tester.sendKeyUpEvent(LogicalKeyboardKey.control);
      await tester.pump();
      expect(find.text('3 selected'), findsOneWidget);

      await tester.sendKeyEvent(LogicalKeyboardKey.escape);
      await tester.pump();
      expect(find.text('3 selected'), findsNothing);
    });
  });
}
