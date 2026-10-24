import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:submersion/core/providers/provider.dart';
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
}
