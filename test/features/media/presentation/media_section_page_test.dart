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
import 'package:submersion/features/media_documents/presentation/pages/media_documents_page.dart';
import 'package:submersion/features/media_store/data/media_transfer_queue_repository.dart';
import 'package:submersion/features/media_store/presentation/providers/media_store_providers.dart';
import 'package:submersion/features/media_store/presentation/widgets/transfers_view.dart';
import 'package:submersion/features/settings/data/repositories/app_settings_repository.dart';
import 'package:submersion/features/settings/presentation/providers/settings_providers.dart';
import 'package:submersion/l10n/arb/app_localizations.dart';
import 'package:submersion/shared/widgets/section_tabs/section_tabs_header_title.dart';

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
  /// The real Media tab under the real Photos/Videos and Documents switch.
  Widget host({bool accents = false}) {
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
        if (accents) accentSectionHeadersProvider.overrideWithValue(true),
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
            headerTitle: sectionTabsHeaderTitle(
              controller: controller,
              tab: MediaDocumentsTab.media,
              labels: MediaDocumentsPage.labels,
              toggleKey: const ValueKey('media_documents_section_toggle'),
            ),
          ),
        ),
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
    // The section strip, not the Photos/Videos and Documents switch above
    // it.
    TabController controller() => tester
        .widget<TabBar>(
          find.ancestor(
            of: find.text('Sources'),
            matching: find.byType(TabBar),
          ),
        )
        .controller!;

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

  for (final accents in [false, true]) {
    for (final size in [const Size(400, 800), const Size(1400, 900)]) {
      testWidgets('at ${size.width.toInt()}px, accents '
          '${accents ? 'on' : 'off'}, the first section tab lines up with '
          "the switch's first name", (tester) async {
        // With accents on, the accent icon ahead of the switch pushes its
        // first name further in, and the tabs have to follow it.
        tester.view.physicalSize = size;
        tester.view.devicePixelRatio = 1.0;
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);

        await tester.pumpWidget(host(accents: accents));
        await tester.pumpAndSettle();

        expect(
          tester.getTopLeft(find.text('Library')).dx,
          tester.getTopLeft(find.text('Photos/Videos')).dx,
        );
      });
    }
  }

  group('with the accented switch as the title', () {
    // The section tabs sit under the Photos/Videos and Documents switch at
    // every width, never beside it (#3631).
    for (final size in [const Size(400, 800), const Size(1400, 900)]) {
      testWidgets('at ${size.width.toInt()}px the section tabs sit under '
          'the switch', (tester) async {
        tester.view.physicalSize = size;
        tester.view.devicePixelRatio = 1.0;
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);

        await tester.pumpWidget(host(accents: true));
        await tester.pumpAndSettle();

        expect(tester.takeException(), isNull);
        expect(find.byIcon(Icons.photo_library), findsWidgets);
        final toggle = find.byKey(
          const ValueKey('media_documents_section_toggle'),
        );
        expect(find.text('Photos/Videos'), findsOneWidget);
        expect(
          tester.getTopLeft(find.text('Library')).dy,
          greaterThanOrEqualTo(tester.getBottomLeft(toggle).dy),
        );
      });
    }
  });
}

/// Builds [child] under a [TabController] this test owns, so the real
/// `sectionTabsHeaderTitle` factory has a controller to drive, the same way
/// the host supplies one in production.
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
