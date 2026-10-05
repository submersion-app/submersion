import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:submersion/features/media/data/services/media_source_resolver_registry.dart';
import 'package:submersion/features/media/domain/entities/media_item.dart';
import 'package:submersion/features/media/domain/entities/media_source_type.dart';
import 'package:submersion/features/media/domain/services/media_source_resolver.dart';
import 'package:submersion/features/media/domain/value_objects/media_source_data.dart';
import 'package:submersion/features/media/domain/value_objects/verify_result.dart';
import 'package:submersion/features/media/presentation/pages/media_viewer_page.dart';
import 'package:submersion/features/media/presentation/providers/lightroom_providers.dart';
import 'package:submersion/features/media/presentation/providers/media_resolver_providers.dart';
import 'package:submersion/features/settings/presentation/providers/settings_providers.dart';
import 'package:submersion/l10n/arb/app_localizations.dart';

import '../../../../helpers/test_database.dart';

class _UnavailableResolver implements MediaSourceResolver {
  _UnavailableResolver([this.sourceType = MediaSourceType.platformGallery]);
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

MediaItem item(String id) => MediaItem(
  id: id,
  mediaType: MediaType.photo,
  sourceType: MediaSourceType.platformGallery,
  takenAt: DateTime.utc(2026, 7, 1, 10),
  createdAt: DateTime.utc(2026, 7, 1),
  updatedAt: DateTime.utc(2026, 7, 1),
);

void main() {
  late SharedPreferences prefs;

  setUp(() async {
    await setUpTestDatabase();
    SharedPreferences.setMockInitialValues({});
    prefs = await SharedPreferences.getInstance();
  });

  tearDown(tearDownTestDatabase);

  /// The viewer pushed over a host page, so Back and Esc have somewhere to
  /// go. No runAsync: pumpAndSettle drives the fake clock the 3 s fade uses.
  Future<void> pumpViewer(WidgetTester tester, {List<MediaItem>? media}) async {
    tester.view.physicalSize = const Size(1024, 800);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          sharedPreferencesProvider.overrideWithValue(prefs),
          mediaSourceResolverRegistryProvider.overrideWithValue(
            MediaSourceResolverRegistry({
              MediaSourceType.platformGallery: _UnavailableResolver(),
              MediaSourceType.serviceConnector: _UnavailableResolver(
                MediaSourceType.serviceConnector,
              ),
            }),
          ),
          lightroomAccountProvider.overrideWith((ref) async => null),
        ],
        child: MaterialApp(
          locale: const Locale('en'),
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: Builder(
            builder: (context) => TextButton(
              onPressed: () => Navigator.of(context).push(
                MaterialPageRoute<void>(
                  builder: (_) => MediaViewerPage(
                    mediaList: media ?? [item('a'), item('b')],
                    initialMediaId: 'a',
                  ),
                ),
              ),
              child: const Text('Open viewer'),
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.text('Open viewer'));
    await tester.pumpAndSettle();
  }

  /// A tap on the photo. The wait lets PhotoView's double-tap recognizer
  /// time out and release the gesture arena to the tap target.
  Future<void> tapPhoto(WidgetTester tester) async {
    await tester.tapAt(tester.getCenter(find.byType(MediaViewerPage)));
    await tester.pump(const Duration(milliseconds: 500));
    await tester.pump();
  }

  Future<void> enterFullscreen(WidgetTester tester) async {
    await tester.tap(find.byTooltip('Full screen'));
    await tester.pump();
  }

  final exitButton = find.byTooltip('Exit full screen');

  testWidgets('opens in normal mode with the Full screen button', (
    tester,
  ) async {
    await pumpViewer(tester);
    expect(find.text('1 / 2'), findsOneWidget);
    expect(find.byTooltip('Full screen'), findsOneWidget);
    expect(exitButton, findsNothing);
  });

  testWidgets('fullscreen hides every overlay', (tester) async {
    await pumpViewer(tester);
    await enterFullscreen(tester);
    expect(find.text('1 / 2'), findsNothing);
    expect(find.byTooltip('Next media'), findsNothing);
    expect(find.byTooltip('Full screen'), findsNothing);
    expect(exitButton, findsNothing);
  });

  testWidgets('a tap reveals the exit button, which hides after 3 s', (
    tester,
  ) async {
    await pumpViewer(tester);
    await enterFullscreen(tester);
    await tapPhoto(tester);
    expect(exitButton, findsOneWidget);

    await tester.pump(const Duration(seconds: 2));
    expect(exitButton, findsOneWidget);
    await tester.pump(const Duration(seconds: 1));
    expect(exitButton, findsNothing);
    expect(find.text('1 / 2'), findsNothing);
  });

  testWidgets('a second tap hides the exit button straight away', (
    tester,
  ) async {
    await pumpViewer(tester);
    await enterFullscreen(tester);
    await tapPhoto(tester);
    await tapPhoto(tester);
    expect(exitButton, findsNothing);
  });

  testWidgets('the exit button returns to the normal viewer', (tester) async {
    await pumpViewer(tester);
    await enterFullscreen(tester);
    await tapPhoto(tester);
    await tester.tap(exitButton);
    await tester.pumpAndSettle();
    expect(find.text('1 / 2'), findsOneWidget);
    expect(find.byType(MediaViewerPage), findsOneWidget);
  });

  testWidgets('Esc leaves fullscreen first, then closes the viewer', (
    tester,
  ) async {
    await pumpViewer(tester);
    await enterFullscreen(tester);

    await tester.sendKeyEvent(LogicalKeyboardKey.escape);
    await tester.pumpAndSettle();
    expect(find.byType(MediaViewerPage), findsOneWidget);
    expect(find.text('1 / 2'), findsOneWidget);

    await tester.sendKeyEvent(LogicalKeyboardKey.escape);
    await tester.pumpAndSettle();
    expect(find.byType(MediaViewerPage), findsNothing);
  });

  testWidgets('Back leaves fullscreen first, then closes the viewer', (
    tester,
  ) async {
    await pumpViewer(tester);
    await enterFullscreen(tester);

    await tester.binding.handlePopRoute();
    await tester.pumpAndSettle();
    expect(find.byType(MediaViewerPage), findsOneWidget);
    expect(find.text('1 / 2'), findsOneWidget);

    await tester.binding.handlePopRoute();
    await tester.pumpAndSettle();
    expect(find.byType(MediaViewerPage), findsNothing);
  });

  testWidgets('arrow keys still page and fullscreen stays on', (tester) async {
    await pumpViewer(tester);
    await enterFullscreen(tester);
    await tester.sendKeyEvent(LogicalKeyboardKey.arrowRight);
    await tester.pumpAndSettle();

    await tester.sendKeyEvent(LogicalKeyboardKey.escape);
    await tester.pumpAndSettle();
    expect(find.text('2 / 2'), findsOneWidget);
  });

  testWidgets('a viewer opened again starts in normal mode', (tester) async {
    await pumpViewer(tester);
    await enterFullscreen(tester);
    final navigator = tester.state<NavigatorState>(find.byType(Navigator));
    navigator.pop();
    await tester.pumpAndSettle();

    await tester.tap(find.text('Open viewer'));
    await tester.pumpAndSettle();
    expect(find.text('1 / 2'), findsOneWidget);
  });

  testWidgets('an emptied gallery leaves fullscreen by itself', (tester) async {
    final media = ValueNotifier<List<MediaItem>>([item('a')]);
    addTearDown(media.dispose);
    await pumpViewer(tester);
    // Re-host the viewer on a list that can change under it, as the
    // provider-backed wrappers do.
    final navigator = tester.state<NavigatorState>(find.byType(Navigator));
    navigator.pop();
    await tester.pumpAndSettle();
    navigator.push(
      MaterialPageRoute<void>(
        builder: (_) => ValueListenableBuilder<List<MediaItem>>(
          valueListenable: media,
          builder: (context, list, child) =>
              MediaViewerPage(mediaList: list, initialMediaId: 'a'),
        ),
      ),
    );
    await tester.pumpAndSettle();
    await enterFullscreen(tester);

    media.value = const [];
    await tester.pumpAndSettle();
    expect(find.text('No photos available'), findsOneWidget);

    // Out of fullscreen, so one Back closes the viewer.
    await tester.binding.handlePopRoute();
    await tester.pumpAndSettle();
    expect(find.byType(MediaViewerPage), findsNothing);
  });

  testWidgets('a Lightroom-linked video hides its badge and reveals the '
      'exit button on tap', (tester) async {
    final connectorVideo = MediaItem(
      id: 'lr1',
      mediaType: MediaType.video,
      sourceType: MediaSourceType.serviceConnector,
      remoteAssetId: 'asset-1',
      takenAt: DateTime.utc(2026, 7, 1, 10),
      createdAt: DateTime.utc(2026, 7, 1),
      updatedAt: DateTime.utc(2026, 7, 1),
    );
    await pumpViewer(tester, media: [connectorVideo]);
    expect(find.byIcon(Icons.play_arrow), findsOneWidget);

    await enterFullscreen(tester);
    // The poster's play badge is chrome too.
    expect(find.byIcon(Icons.play_arrow), findsNothing);

    await tapPhoto(tester);
    expect(exitButton, findsOneWidget);
  });
}
