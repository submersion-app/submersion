import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:submersion/core/services/window_fullscreen.dart';
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
import 'package:submersion/features/settings/presentation/providers/viewer_fullscreen_mode_provider.dart';
import 'package:submersion/l10n/arb/app_localizations.dart';

import '../../../../core/services/window_fullscreen_test.dart'
    show FakeWindowFullscreenPlatform;
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

/// The viewer's fullscreen mode against the OS window (#3178): with the
/// Fullscreen setting the desktop window goes fullscreen too, with Full
/// window (the default) only the app's own chrome is hidden.
void main() {
  late SharedPreferences prefs;
  late FakeWindowFullscreenPlatform platform;

  setUp(() async {
    await setUpTestDatabase();
    SharedPreferences.setMockInitialValues({});
    prefs = await SharedPreferences.getInstance();
    platform = FakeWindowFullscreenPlatform();
  });

  tearDown(tearDownTestDatabase);

  late BuildContext hostContext;

  Future<void> pumpViewer(
    WidgetTester tester, {
    required ViewerFullscreenMode mode,
  }) async {
    tester.view.physicalSize = const Size(1024, 800);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          sharedPreferencesProvider.overrideWithValue(prefs),
          windowFullscreenPlatformProvider.overrideWithValue(platform),
          viewerFullscreenModeProvider.overrideWith(
            (ref) => ViewerFullscreenModeNotifier.unstored(mode),
          ),
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
            builder: (context) {
              hostContext = context;
              return TextButton(
                onPressed: () => Navigator.of(context).push(
                  MaterialPageRoute<void>(
                    builder: (_) => MediaViewerPage(
                      mediaList: [item('a'), item('b')],
                      initialMediaId: 'a',
                    ),
                  ),
                ),
                child: const Text('Open viewer'),
              );
            },
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.text('Open viewer'));
    await tester.pumpAndSettle();
  }

  Future<void> enterFullscreen(WidgetTester tester) async {
    await tester.tap(find.byTooltip('Full screen'));
    await tester.pump();
  }

  testWidgets('Fullscreen setting: the window goes fullscreen and back', (
    tester,
  ) async {
    await pumpViewer(tester, mode: ViewerFullscreenMode.fullscreen);
    expect(platform.setCalls, isEmpty, reason: 'opening is not fullscreen');

    await enterFullscreen(tester);
    expect(platform.fullScreen, isTrue);

    await tester.sendKeyEvent(LogicalKeyboardKey.escape);
    await tester.pumpAndSettle();
    expect(find.byType(MediaViewerPage), findsOneWidget);
    expect(platform.setCalls, [true, false]);
  });

  testWidgets('Full window setting: the OS window is never touched', (
    tester,
  ) async {
    await pumpViewer(tester, mode: ViewerFullscreenMode.fullWindow);
    await enterFullscreen(tester);
    await tester.sendKeyEvent(LogicalKeyboardKey.escape);
    await tester.pumpAndSettle();

    expect(platform.setCalls, isEmpty);
  });

  testWidgets('closing the viewer while fullscreen restores the window', (
    tester,
  ) async {
    await pumpViewer(tester, mode: ViewerFullscreenMode.fullscreen);
    await enterFullscreen(tester);
    expect(platform.fullScreen, isTrue);

    // Navigator.pop skips the PopScope, as the swipe-down close does.
    Navigator.of(hostContext).pop();
    await tester.pumpAndSettle();

    expect(find.byType(MediaViewerPage), findsNothing);
    expect(platform.setCalls, [true, false]);
  });
}
