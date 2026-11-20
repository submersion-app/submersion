import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:submersion/core/providers/provider.dart';
import 'package:submersion/features/media/domain/entities/media_library_filter.dart';
import 'package:submersion/features/media/presentation/media_tag_navigation.dart';
import 'package:submersion/features/media/presentation/providers/media_library_providers.dart';

/// A tag chip in the info sheet opens the filtered library even when the
/// viewer was pushed over the library itself (issue #1970).
void main() {
  testWidgets('closes the sheet and the viewer, then shows the library', (
    tester,
  ) async {
    final container = ProviderContainer();
    addTearDown(container.dispose);
    final router = GoRouter(
      initialLocation: '/media',
      routes: [
        GoRoute(
          path: '/media',
          builder: (context, _) => Scaffold(
            body: TextButton(
              // The viewer, pushed imperatively as MediaViewerLauncher does.
              onPressed: () => Navigator.of(context).push(
                MaterialPageRoute<void>(
                  builder: (viewerContext) => Scaffold(
                    body: TextButton(
                      onPressed: () => showModalBottomSheet<void>(
                        context: viewerContext,
                        builder: (_) => Consumer(
                          builder: (sheetContext, ref, _) => TextButton(
                            onPressed: () =>
                                openMediaWithTag(sheetContext, ref, 'wreck'),
                            child: const Text('tag chip'),
                          ),
                        ),
                      ),
                      child: const Text('VIEWER'),
                    ),
                  ),
                ),
              ),
              child: const Text('LIBRARY'),
            ),
          ),
        ),
      ],
    );
    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: MaterialApp.router(routerConfig: router),
      ),
    );
    await tester.tap(find.text('LIBRARY'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('VIEWER'));
    await tester.pumpAndSettle();

    await tester.tap(find.text('tag chip'));
    await tester.pumpAndSettle();

    expect(find.text('VIEWER'), findsNothing);
    expect(find.text('tag chip'), findsNothing);
    expect(find.text('LIBRARY'), findsOneWidget);
    expect(container.read(mediaLibraryFilterProvider).tagIds, {'wreck'});
  });

  // A viewer unlocked with unsaved changes refuses to pop (issue #4527):
  // Navigator.pop would close it anyway, past its guard, and the changes
  // would be dropped unasked.
  testWidgets('a viewer guarding unsaved changes is asked, not popped past', (
    tester,
  ) async {
    final container = ProviderContainer();
    addTearDown(container.dispose);
    final asked = <bool>[];
    final router = GoRouter(
      initialLocation: '/media',
      routes: [
        GoRoute(
          path: '/media',
          builder: (context, _) => Scaffold(
            body: TextButton(
              onPressed: () => Navigator.of(context).push(
                MaterialPageRoute<void>(
                  builder: (viewerContext) => PopScope(
                    canPop: false,
                    onPopInvokedWithResult: (didPop, _) => asked.add(didPop),
                    child: Scaffold(
                      body: TextButton(
                        onPressed: () => showModalBottomSheet<void>(
                          context: viewerContext,
                          builder: (_) => Consumer(
                            builder: (sheetContext, ref, _) => TextButton(
                              onPressed: () =>
                                  openMediaWithTag(sheetContext, ref, 'wreck'),
                              child: const Text('tag chip'),
                            ),
                          ),
                        ),
                        child: const Text('VIEWER'),
                      ),
                    ),
                  ),
                ),
              ),
              child: const Text('LIBRARY'),
            ),
          ),
        ),
      ],
    );
    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: MaterialApp.router(routerConfig: router),
      ),
    );
    await tester.tap(find.text('LIBRARY'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('VIEWER'));
    await tester.pumpAndSettle();

    await tester.tap(find.text('tag chip'));
    await tester.pumpAndSettle();

    expect(find.text('VIEWER'), findsOneWidget);
    expect(asked, [false]);
    expect(container.read(mediaLibraryFilterProvider).tagIds, isEmpty);
  });

  // A card on another section's page (the site's +N, the buddy's photos)
  // opens the library over that page, so Back returns to it (issue #4741).
  group('opened from another section', () {
    late ProviderContainer container;
    late GoRouter router;

    Future<void> pumpSite(WidgetTester tester) async {
      container = ProviderContainer();
      addTearDown(container.dispose);
      router = GoRouter(
        initialLocation: '/sites/s1',
        routes: [
          GoRoute(
            path: '/sites/s1',
            builder: (context, _) => Scaffold(
              body: Consumer(
                builder: (context, ref, _) => TextButton(
                  onPressed: () => openMediaWithFilter(
                    context,
                    ref,
                    const MediaLibraryFilter(siteId: 's1'),
                  ),
                  child: const Text('SITE'),
                ),
              ),
            ),
          ),
          GoRoute(
            path: '/media',
            builder: (context, _) => Scaffold(
              appBar: AppBar(title: const Text('LIBRARY')),
              body: Consumer(
                builder: (context, ref, _) => TextButton(
                  onPressed: () => openMediaWithTag(context, ref, 'wreck'),
                  child: const Text('tag chip'),
                ),
              ),
            ),
          ),
        ],
      );
      await tester.pumpWidget(
        UncontrolledProviderScope(
          container: container,
          child: MaterialApp.router(routerConfig: router),
        ),
      );
      await tester.tap(find.text('SITE'));
      await tester.pumpAndSettle();
    }

    testWidgets('pushes the library, and Back returns to the site', (
      tester,
    ) async {
      await pumpSite(tester);

      expect(find.text('LIBRARY'), findsOneWidget);
      expect(container.read(mediaLibraryFilterProvider).siteId, 's1');
      expect(find.byType(BackButton), findsOneWidget);

      await tester.tap(find.byType(BackButton));
      await tester.pumpAndSettle();
      expect(find.text('SITE'), findsOneWidget);
      expect(find.text('LIBRARY'), findsNothing);
    });

    testWidgets('a second open from the library does not stack another', (
      tester,
    ) async {
      await pumpSite(tester);

      await tester.tap(find.text('tag chip'));
      await tester.pumpAndSettle();
      expect(container.read(mediaLibraryFilterProvider).tagIds, {'wreck'});

      // One Back, straight to the site.
      await tester.tap(find.byType(BackButton));
      await tester.pumpAndSettle();
      expect(find.text('SITE'), findsOneWidget);
    });
  });
}
