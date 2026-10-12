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
  });
}
