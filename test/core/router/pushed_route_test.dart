import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:submersion/core/constants/list_view_mode.dart';
import 'package:submersion/core/router/pushed_route.dart';

void main() {
  const desktop = Size(1200, 800);
  const phone = Size(400, 800);

  /// Pumps a router with /root and /item; [probe] runs inside /item's build.
  Future<GoRouter> pump(
    WidgetTester tester, {
    required Size size,
    required String initial,
    required void Function(BuildContext) probe,
  }) async {
    final router = GoRouter(
      initialLocation: initial,
      routes: [
        GoRoute(path: '/root', builder: (_, _) => const Text('ROOT')),
        GoRoute(
          path: '/item',
          builder: (_, _) => Builder(
            builder: (context) {
              probe(context);
              return const Text('ITEM');
            },
          ),
        ),
      ],
    );
    addTearDown(router.dispose);
    await tester.pumpWidget(
      MediaQuery(
        data: MediaQueryData(size: size),
        child: MaterialApp.router(routerConfig: router),
      ),
    );
    await tester.pumpAndSettle();
    return router;
  }

  group('isPushedRoute', () {
    testWidgets('a root page is not pushed', (tester) async {
      bool? pushed;
      await pump(
        tester,
        size: desktop,
        initial: '/item',
        probe: (c) => pushed = isPushedRoute(c),
      );
      expect(pushed, isFalse);
    });

    testWidgets('a page pushed over another is pushed', (tester) async {
      bool? pushed;
      final router = await pump(
        tester,
        size: desktop,
        initial: '/root',
        probe: (c) => pushed = isPushedRoute(c),
      );
      router.push('/item');
      await tester.pumpAndSettle();
      expect(pushed, isTrue);
    });
  });

  group('shouldRedirectToMasterDetail', () {
    Future<bool?> decide(
      WidgetTester tester, {
      Size size = desktop,
      bool pushedOver = false,
      bool embedded = false,
      ListViewMode mode = ListViewMode.detailed,
    }) async {
      bool? result;
      final router = await pump(
        tester,
        size: size,
        initial: pushedOver ? '/root' : '/item',
        probe: (c) => result = shouldRedirectToMasterDetail(
          c,
          embedded: embedded,
          viewMode: mode,
        ),
      );
      if (pushedOver) {
        router.push('/item');
        await tester.pumpAndSettle();
      }
      return result;
    }

    testWidgets('root page at desktop width in list mode redirects', (
      tester,
    ) async {
      expect(await decide(tester), isTrue);
    });

    testWidgets('a pushed page does not redirect', (tester) async {
      expect(await decide(tester, pushedOver: true), isFalse);
    });

    testWidgets('an embedded page does not redirect', (tester) async {
      expect(await decide(tester, embedded: true), isFalse);
    });

    testWidgets('phone width does not redirect', (tester) async {
      expect(await decide(tester, size: phone), isFalse);
    });

    testWidgets('table mode does not redirect', (tester) async {
      expect(await decide(tester, mode: ListViewMode.table), isFalse);
    });

    group('with the detail route nested under its list, as in the app', () {
      // go('/list/item') builds the list AND the item, so the item can pop;
      // that is not a push, and it still redirects into the split.
      Future<bool?> decideNested(
        WidgetTester tester, {
        required bool pushed,
      }) async {
        bool? result;
        final router = GoRouter(
          initialLocation: pushed ? '/root' : '/list/item',
          routes: [
            GoRoute(path: '/root', builder: (_, _) => const Text('ROOT')),
            GoRoute(
              path: '/list',
              builder: (_, _) => const Text('LIST'),
              routes: [
                GoRoute(
                  path: 'item',
                  builder: (_, _) => Builder(
                    builder: (context) {
                      result = shouldRedirectToMasterDetail(
                        context,
                        embedded: false,
                        viewMode: ListViewMode.detailed,
                      );
                      return const Text('ITEM');
                    },
                  ),
                ),
              ],
            ),
          ],
        );
        addTearDown(router.dispose);
        await tester.pumpWidget(
          MediaQuery(
            data: const MediaQueryData(size: desktop),
            child: MaterialApp.router(routerConfig: router),
          ),
        );
        await tester.pumpAndSettle();
        if (pushed) {
          router.push('/list/item');
          await tester.pumpAndSettle();
        }
        return result;
      }

      testWidgets('a go() to the detail URL redirects', (tester) async {
        expect(await decideNested(tester, pushed: false), isTrue);
      });

      testWidgets('a push of the detail URL does not redirect', (tester) async {
        expect(await decideNested(tester, pushed: true), isFalse);
      });

      testWidgets('a pushed page still does not redirect after a replace', (
        tester,
      ) async {
        bool? result;
        final router = GoRouter(
          initialLocation: '/root',
          routes: [
            GoRoute(path: '/root', builder: (_, _) => const Text('ROOT')),
            GoRoute(
              path: '/item',
              builder: (_, _) => Builder(
                builder: (context) {
                  result = shouldRedirectToMasterDetail(
                    context,
                    embedded: false,
                    viewMode: ListViewMode.detailed,
                  );
                  return const Text('ITEM');
                },
              ),
            ),
          ],
        );
        addTearDown(router.dispose);
        await tester.pumpWidget(
          MediaQuery(
            data: const MediaQueryData(size: desktop),
            child: MaterialApp.router(routerConfig: router),
          ),
        );
        router.push('/item');
        await tester.pumpAndSettle();
        router.replace('/item?selected=x');
        await tester.pumpAndSettle();
        expect(result, isFalse);
      });
    });
  });
}
