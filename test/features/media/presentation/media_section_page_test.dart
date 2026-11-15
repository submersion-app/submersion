import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/core/providers/provider.dart';
import 'package:submersion/core/router/media_documents_locations.dart';
import 'package:submersion/core/theme/app_theme_registry.dart';
import 'package:submersion/features/equipment/presentation/providers/gear_photo_providers.dart';
import 'package:submersion/features/media/data/services/photo_picker_service.dart';
import 'package:submersion/features/media/domain/entities/media_source_type.dart';
import 'package:submersion/features/media/presentation/pages/gear_gallery_view.dart';
import 'package:submersion/features/media/presentation/pages/media_library_view.dart';
import 'package:submersion/features/media/presentation/pages/media_section_page.dart';
import 'package:submersion/features/media/presentation/pages/media_sources_section_page.dart';
import 'package:submersion/features/media/presentation/providers/media_library_providers.dart';
import 'package:submersion/features/media/presentation/providers/media_watcher_providers.dart';
import 'package:submersion/features/media/presentation/widgets/media_console_scaffold.dart';
import 'package:submersion/features/media_documents/presentation/pages/media_documents_page.dart';
import 'package:submersion/features/media_store/data/media_transfer_queue_repository.dart';
import 'package:submersion/features/media_store/presentation/pages/transfers_page.dart';
import 'package:submersion/features/media_store/presentation/providers/media_store_providers.dart';
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
  Widget host({
    bool accents = false,
    Future<List<AssetInfo>> Function(BuildContext context)? importPick,
  }) {
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
        gearGalleryProvider.overrideWith((ref) async => const []),
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
            importPickOverride: importPick,
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

  /// The section strip, not the Photos/Videos and Documents switch above
  /// it.
  TabController strip(WidgetTester tester) => tester
      .widget<TabBar>(
        find.ancestor(of: find.text('Library'), matching: find.byType(TabBar)),
      )
      .controller!;

  Finder action(MediaConsoleAction a) =>
      find.byKey(ValueKey('media_console_action_${a.name}'));

  testWidgets('switching tabs swaps the library and the gear gallery', (
    tester,
  ) async {
    setDesktopSize(tester);

    await tester.pumpWidget(host());
    await tester.pumpAndSettle();

    expect(find.byType(MediaLibraryView), findsOneWidget);
    expect(find.byType(GearGalleryView), findsNothing);

    await tester.tap(find.text('Equipment'));
    await tester.pumpAndSettle();

    expect(find.byType(GearGalleryView), findsOneWidget);
    expect(find.byType(MediaLibraryView), findsNothing);

    await tester.tap(find.text('Library'));
    await tester.pumpAndSettle();
    expect(find.byType(MediaLibraryView), findsOneWidget);
  });

  testWidgets('the Transfers button opens the Transfers page over Media', (
    tester,
  ) async {
    setDesktopSize(tester);
    await tester.pumpWidget(host());
    await tester.pumpAndSettle();

    await tester.tap(action(MediaConsoleAction.transfers));
    await tester.pumpAndSettle();
    expect(find.byType(TransfersPage), findsOneWidget);
    // Titled like the button, not Settings' "Uploads".
    expect(
      find.descendant(
        of: find.byType(AppBar),
        matching: find.text('Transfers'),
      ),
      findsOneWidget,
    );

    await tester.tap(find.byType(BackButton));
    await tester.pumpAndSettle();
    expect(find.byType(TransfersPage), findsNothing);
    expect(find.byType(MediaLibraryView), findsOneWidget);
  });

  testWidgets('a double tap on Transfers opens one page, not two', (
    tester,
  ) async {
    setDesktopSize(tester);
    await tester.pumpWidget(host());
    await tester.pumpAndSettle();

    // The second tap lands before the route covers the button.
    await tester.tap(action(MediaConsoleAction.transfers));
    await tester.tap(action(MediaConsoleAction.transfers));
    await tester.pumpAndSettle();

    await tester.tap(find.byType(BackButton));
    await tester.pumpAndSettle();
    expect(find.byType(TransfersPage), findsNothing);
    expect(find.byType(MediaLibraryView), findsOneWidget);

    // Once the page has closed, the button works again.
    await tester.tap(action(MediaConsoleAction.transfers));
    await tester.pumpAndSettle();
    expect(find.byType(TransfersPage), findsOneWidget);
  });

  testWidgets('the Import button opens the picker straight away', (
    tester,
  ) async {
    setDesktopSize(tester);
    var picks = 0;
    await tester.pumpWidget(
      host(
        importPick: (_) async {
          picks++;
          return const [];
        },
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(action(MediaConsoleAction.importMedia));
    await tester.pumpAndSettle();

    expect(picks, 1);
    // An empty pick leaves the section as it was.
    expect(find.byType(MediaLibraryView), findsOneWidget);
    expect(strip(tester).index, MediaConsoleSection.library.index);
  });

  testWidgets('a second tap while the picker is open starts nothing', (
    tester,
  ) async {
    // A desktop file dialog is no route, so nothing covers the button
    // while it is open; the page itself has to ignore the second tap.
    setDesktopSize(tester);
    var picks = 0;
    final picked = Completer<List<AssetInfo>>();
    await tester.pumpWidget(
      host(
        importPick: (_) {
          picks++;
          return picked.future;
        },
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(action(MediaConsoleAction.importMedia));
    await tester.pump();
    await tester.tap(action(MediaConsoleAction.importMedia));
    await tester.pump();
    expect(picks, 1);

    // Once the picker closes, the button works again.
    picked.complete(const []);
    await tester.pumpAndSettle();
    await tester.tap(action(MediaConsoleAction.importMedia));
    await tester.pumpAndSettle();
    expect(picks, 2);
  });

  testWidgets(
    'browsing a source from Gear closes Sources and selects Library',
    (tester) async {
      // The selection changes outside the tab strip, so the strip has to
      // follow the page's selection rather than only its own taps.
      setDesktopSize(tester);
      await tester.pumpWidget(host());
      await tester.pumpAndSettle();

      await tester.tap(find.text('Equipment'));
      await tester.pumpAndSettle();
      await tester.tap(action(MediaConsoleAction.sources));
      await tester.pumpAndSettle();
      expect(find.byType(MediaSourcesSectionPage), findsOneWidget);

      await tester.tap(find.widgetWithText(ListTile, '7'));
      await tester.pumpAndSettle();
      expect(find.byType(MediaSourcesSectionPage), findsNothing);
      expect(find.byType(MediaLibraryView), findsOneWidget);
      expect(find.byType(GearGalleryView), findsNothing);
      expect(strip(tester).index, MediaConsoleSection.library.index);
    },
  );

  testWidgets('closing Sources with Back keeps the current tab', (
    tester,
  ) async {
    setDesktopSize(tester);
    await tester.pumpWidget(host());
    await tester.pumpAndSettle();

    await tester.tap(find.text('Equipment'));
    await tester.pumpAndSettle();
    await tester.tap(action(MediaConsoleAction.sources));
    await tester.pumpAndSettle();
    await tester.tap(find.byType(BackButton));
    await tester.pumpAndSettle();

    expect(find.byType(MediaSourcesSectionPage), findsNothing);
    expect(find.byType(GearGalleryView), findsOneWidget);
    expect(strip(tester).index, MediaConsoleSection.gear.index);
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
