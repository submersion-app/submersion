import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/core/providers/provider.dart';
import 'package:submersion/core/router/media_documents_locations.dart';
import 'package:submersion/core/theme/app_theme_registry.dart';
import 'package:submersion/features/media/domain/entities/media_source_type.dart';
import 'package:submersion/features/media/presentation/pages/media_library_view.dart';
import 'package:submersion/features/media/presentation/pages/media_section_page.dart';
import 'package:submersion/features/media/presentation/pages/media_sources_section_view.dart';
import 'package:submersion/features/media/presentation/providers/media_library_providers.dart';
import 'package:submersion/features/media/presentation/providers/media_watcher_providers.dart';
import 'package:submersion/features/media/presentation/widgets/media_console_scaffold.dart';
import 'package:submersion/features/media_documents/presentation/widgets/media_documents_section_toggle.dart';
import 'package:submersion/features/media_store/data/media_transfer_queue_repository.dart';
import 'package:submersion/features/media_store/presentation/providers/media_store_providers.dart';
import 'package:submersion/features/media_store/presentation/widgets/transfers_view.dart';
import 'package:submersion/features/settings/data/repositories/app_settings_repository.dart';
import 'package:submersion/features/settings/presentation/providers/settings_providers.dart';
import 'package:submersion/l10n/arb/app_localizations.dart';

class _SeededLibraryNotifier extends StateNotifier<MediaLibraryState>
    implements MediaLibraryNotifier {
  _SeededLibraryNotifier() : super(const MediaLibraryState());

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

void main() {
  Widget host() {
    return ProviderScope(
      overrides: [
        mediaLibraryNotifierProvider.overrideWith(
          (ref) => _SeededLibraryNotifier(),
        ),
        appSettingsRepositoryProvider.overrideWithValue(_FakeSettingsRepo()),
        mediaTransferEntriesProvider.overrideWith(
          (ref) => Stream.value(const <MediaTransferQueueEntry>[]),
        ),
        sourceCountsProvider.overrideWith(
          (ref) async => const {MediaSourceType.platformGallery: 7},
        ),
        watchedRootsProvider.overrideWith((ref) async => const <String>[]),
      ],
      child: const MaterialApp(
        locale: Locale('en'),
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: MediaSectionPage(),
      ),
    );
  }

  void setDesktopSize(WidgetTester tester) {
    tester.view.physicalSize = const Size(1100, 800);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
  }

  testWidgets('switching sections swaps library and transfers content', (
    tester,
  ) async {
    setDesktopSize(tester);

    await tester.pumpWidget(host());
    await tester.pumpAndSettle();

    expect(find.byType(MediaLibraryView), findsOneWidget);
    expect(find.byType(TransfersView), findsNothing);

    await tester.tap(find.text('Transfers'));
    await tester.pumpAndSettle();

    expect(find.byType(TransfersView), findsOneWidget);
    expect(find.byType(MediaLibraryView), findsNothing);

    await tester.tap(find.text('Library'));
    await tester.pumpAndSettle();
    expect(find.byType(MediaLibraryView), findsOneWidget);
  });

  testWidgets('browsing a source jumps to Library and moves the tab with it', (
    tester,
  ) async {
    // The jump happens outside the tab strip, so the strip has to follow the
    // page's selection rather than only its own taps.
    setDesktopSize(tester);

    await tester.pumpWidget(host());
    await tester.pumpAndSettle();
    TabController controller() =>
        tester.widget<TabBar>(find.byType(TabBar)).controller!;

    await tester.tap(find.text('Sources'));
    await tester.pumpAndSettle();
    expect(find.byType(MediaSourcesSectionView), findsOneWidget);
    expect(controller().index, MediaConsoleSection.sources.index);

    await tester.tap(find.widgetWithText(ListTile, '7'));
    await tester.pumpAndSettle();
    expect(find.byType(MediaLibraryView), findsOneWidget);
    expect(find.byType(MediaSourcesSectionView), findsNothing);
    expect(controller().index, MediaConsoleSection.library.index);
  });

  group('with the real media-documents header title and accents on', () {
    // The merged headerTitle (#3631): its title widget is the real
    // MediaDocumentsSectionToggle/FeatureAppBarTitle.custom chain, not a
    // bare Text, so this reproduces the actual inline-tabs layout a code
    // review flagged (unbounded nested flex) and the accent-icon lookup a
    // second finding flagged (missing media/documents entries once they
    // left kNavDestinations).
    Widget hostWithRealHeaderTitle() {
      return ProviderScope(
        overrides: [
          mediaLibraryNotifierProvider.overrideWith(
            (ref) => _SeededLibraryNotifier(),
          ),
          appSettingsRepositoryProvider.overrideWithValue(_FakeSettingsRepo()),
          mediaTransferEntriesProvider.overrideWith(
            (ref) => Stream.value(const <MediaTransferQueueEntry>[]),
          ),
          sourceCountsProvider.overrideWith(
            (ref) async => const {MediaSourceType.platformGallery: 7},
          ),
          watchedRootsProvider.overrideWith((ref) async => const <String>[]),
          accentSectionHeadersProvider.overrideWithValue(true),
        ],
        child: MaterialApp(
          theme: AppThemeRegistry.resolveTheme(
            AppThemeRegistry.findById('submersion'),
            Brightness.light,
          ),
          locale: const Locale('en'),
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: _HeaderHarness(
            builder: (controller) => MediaSectionPage(
              headerTitle: mediaDocumentsHeaderTitle(
                controller: controller,
                tab: MediaDocumentsTab.media,
              ),
            ),
          ),
        ),
      );
    }

    testWidgets(
      'inline tabs beside the accented switch lay out without a RenderFlex '
      'assertion',
      (tester) async {
        // Wide enough that Media's own Library/Sources/Transfers/Import
        // strip fits inline beside the outer switch -- the layout this
        // bug only reaches.
        tester.view.physicalSize = const Size(1400, 900);
        tester.view.devicePixelRatio = 1.0;
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);

        await tester.pumpWidget(hostWithRealHeaderTitle());
        await tester.pumpAndSettle();

        expect(tester.takeException(), isNull);
        expect(find.byIcon(Icons.photo_library), findsWidgets);
      },
    );
  });
}

/// Builds [child] under a [TabController] this test owns, so the real
/// `mediaDocumentsHeaderTitle` factory has a controller to drive, the same
/// way [MediaDocumentsPage] supplies one in production.
class _HeaderHarness extends StatefulWidget {
  const _HeaderHarness({required this.builder});

  final Widget Function(TabController controller) builder;

  @override
  State<_HeaderHarness> createState() => _HeaderHarnessState();
}

class _HeaderHarnessState extends State<_HeaderHarness>
    with SingleTickerProviderStateMixin {
  late final TabController _controller = TabController(length: 2, vsync: this);

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => widget.builder(_controller);
}
