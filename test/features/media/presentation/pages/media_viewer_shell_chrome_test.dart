import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:submersion/features/media/data/services/media_source_resolver_registry.dart';
import 'package:submersion/features/media/domain/entities/media_item.dart';
import 'package:submersion/features/media/domain/entities/media_source_type.dart';
import 'package:submersion/features/media/domain/services/media_source_resolver.dart';
import 'package:submersion/features/media/domain/value_objects/media_source_data.dart';
import 'package:submersion/features/media/domain/value_objects/verify_result.dart';
import 'package:submersion/features/media/presentation/pages/media_viewer_page.dart';
import 'package:submersion/features/media/presentation/providers/media_resolver_providers.dart';
import 'package:submersion/features/settings/presentation/providers/settings_providers.dart';
import 'package:submersion/l10n/arb/app_localizations.dart';
import 'package:submersion/shared/widgets/shell_chrome_scope.dart';

import '../../../../helpers/test_database.dart';

class _UnavailableResolver implements MediaSourceResolver {
  @override
  MediaSourceType get sourceType => MediaSourceType.platformGallery;
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

/// The smallest shell honouring hide requests: a 'NAV' label in place of
/// MainScaffold's navigation.
class _Shell extends StatefulWidget {
  const _Shell({required this.child});

  final Widget child;

  @override
  State<_Shell> createState() => _ShellState();
}

class _ShellState extends State<_Shell> {
  final _controller = ShellChromeController();

  void _changed() => setState(() {});

  @override
  void initState() {
    super.initState();
    _controller.addListener(_changed);
  }

  @override
  void dispose() {
    _controller
      ..removeListener(_changed)
      ..dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => ShellChromeScope(
    controller: _controller,
    child: Scaffold(
      body: widget.child,
      bottomNavigationBar: _controller.isHidden ? null : const Text('NAV'),
    ),
  );
}

void main() {
  late SharedPreferences prefs;

  setUp(() async {
    await setUpTestDatabase();
    SharedPreferences.setMockInitialValues({});
    prefs = await SharedPreferences.getInstance();
  });

  tearDown(tearDownTestDatabase);

  Future<void> pumpShell(WidgetTester tester) async {
    tester.view.physicalSize = const Size(1024, 800);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);
    final router = GoRouter(
      initialLocation: '/media',
      routes: [
        ShellRoute(
          builder: (context, state, child) => _Shell(child: child),
          routes: [
            GoRoute(
              path: '/media',
              builder: (context, state) => Builder(
                builder: (inner) => TextButton(
                  onPressed: () => Navigator.of(inner).push(
                    MaterialPageRoute<void>(
                      fullscreenDialog: true,
                      builder: (_) => MediaViewerPage(
                        mediaList: [
                          MediaItem(
                            id: 'a',
                            mediaType: MediaType.photo,
                            sourceType: MediaSourceType.platformGallery,
                            takenAt: DateTime.utc(2026, 7, 1, 10),
                            createdAt: DateTime.utc(2026, 7, 1),
                            updatedAt: DateTime.utc(2026, 7, 1),
                          ),
                        ],
                        initialMediaId: 'a',
                      ),
                    ),
                  ),
                  child: const Text('Media Section'),
                ),
              ),
            ),
          ],
        ),
      ],
    );
    addTearDown(router.dispose);
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          sharedPreferencesProvider.overrideWithValue(prefs),
          mediaSourceResolverRegistryProvider.overrideWithValue(
            MediaSourceResolverRegistry({
              MediaSourceType.platformGallery: _UnavailableResolver(),
            }),
          ),
        ],
        child: MaterialApp.router(
          routerConfig: router,
          locale: const Locale('en'),
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
        ),
      ),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.text('Media Section'));
    await tester.pumpAndSettle();
  }

  testWidgets('the shell nav stays up in normal mode', (tester) async {
    await pumpShell(tester);
    expect(find.byType(MediaViewerPage), findsOneWidget);
    expect(find.text('NAV'), findsOneWidget);
  });

  testWidgets('fullscreen hides the shell nav and leaving restores it', (
    tester,
  ) async {
    await pumpShell(tester);
    await tester.tap(find.byTooltip('Full screen'));
    await tester.pumpAndSettle();
    expect(find.text('NAV'), findsNothing);

    await tester.binding.handlePopRoute();
    await tester.pumpAndSettle();
    expect(find.byType(MediaViewerPage), findsOneWidget);
    expect(find.text('NAV'), findsOneWidget);
  });

  testWidgets('closing the viewer while fullscreen restores the nav', (
    tester,
  ) async {
    await pumpShell(tester);
    await tester.tap(find.byTooltip('Full screen'));
    await tester.pumpAndSettle();

    // Swipe-down closes with a plain Navigator.pop, which bypasses the
    // fullscreen PopScope; call the same pop directly so the test does not
    // depend on PhotoView's gesture arena.
    Navigator.of(tester.element(find.byType(MediaViewerPage))).pop();
    await tester.pumpAndSettle();
    expect(find.byType(MediaViewerPage), findsNothing);
    expect(find.text('NAV'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}
