import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';

import 'package:submersion/core/providers/provider.dart';
import 'package:submersion/features/dive_sites/presentation/providers/site_match_review_notifier.dart';
import 'package:submersion/features/media/presentation/helpers/offer_site_review_after_import.dart';

import '../../../../helpers/test_app.dart';

void main() {
  Future<List<Object?>> pump(
    WidgetTester tester,
    List<String> eligible, {
    required List<String> imported,
    List<String>? overrideKey,
  }) async {
    final pushed = <Object?>[];
    final router = GoRouter(
      routes: [
        GoRoute(
          path: '/',
          builder: (context, state) => Scaffold(
            body: Consumer(
              builder: (context, ref, _) => TextButton(
                onPressed: () =>
                    offerSiteReviewAfterImport(context, ref, imported),
                child: const Text('done'),
              ),
            ),
          ),
        ),
        GoRoute(
          path: '/dives/match-sites',
          builder: (context, state) {
            pushed.add(state.extra);
            return const Scaffold(body: Text('review page'));
          },
        ),
      ],
    );
    await tester.pumpWidget(
      testAppRouter(
        router: router,
        // flutter_test forwards the host's locale list, so pin English or the
        // string assertions below fail on a non-English machine.
        locale: const Locale('en'),
        overrides: [
          eligibleImportedDivesProvider(
            ImportedDiveIds(overrideKey ?? imported),
          ).overrideWith((ref) async => eligible),
        ],
      ),
    );
    return pushed;
  }

  testWidgets('offers a review with the eligible count and navigates', (
    tester,
  ) async {
    final pushed = await pump(
      tester,
      ['d1', 'd2'],
      imported: ['d1', 'd2', 'd3'],
    );
    await tester.tap(find.text('done'));
    await tester.pumpAndSettle();
    expect(
      find.text('2 dives could get a site from their photos'),
      findsOneWidget,
    );
    await tester.tap(find.text('Review sites'));
    await tester.pumpAndSettle();
    expect(find.text('review page'), findsOneWidget);
    expect(pushed.single, ['d1', 'd2']);
  });

  testWidgets('stays silent when nothing is eligible or nothing was imported', (
    tester,
  ) async {
    await pump(tester, const [], imported: ['d1']);
    await tester.tap(find.text('done'));
    await tester.pumpAndSettle();
    expect(find.byType(SnackBar), findsNothing);
  });

  testWidgets('the provider key is canonical regardless of import order', (
    tester,
  ) async {
    // ImportedDiveIds is an Equatable over the list, so an unsorted key would
    // miss this override entirely and address a second family entry.
    final pushed = await pump(
      tester,
      ['d1', 'd2'],
      imported: ['d2', 'd1', 'd2'],
      overrideKey: ['d1', 'd2'],
    );
    await tester.tap(find.text('done'));
    await tester.pumpAndSettle();
    expect(
      find.text('2 dives could get a site from their photos'),
      findsOneWidget,
    );
    await tester.tap(find.text('Review sites'));
    await tester.pumpAndSettle();
    expect(pushed.single, ['d1', 'd2']);
  });

  testWidgets('stays silent when the importing page goes away mid-lookup', (
    tester,
  ) async {
    // Callers run this inside the try that reports an import failure, so a
    // throw here would claim a successful import broke.
    final gate = Completer<List<String>>();
    final router = GoRouter(
      routes: [
        GoRoute(
          path: '/',
          builder: (context, state) => Scaffold(
            body: Consumer(
              builder: (context, ref, _) => TextButton(
                onPressed: () =>
                    offerSiteReviewAfterImport(context, ref, const ['d1']),
                child: const Text('done'),
              ),
            ),
          ),
        ),
      ],
    );
    await tester.pumpWidget(
      testAppRouter(
        router: router,
        locale: const Locale('en'),
        overrides: [
          eligibleImportedDivesProvider(
            const ImportedDiveIds(['d1']),
          ).overrideWith((ref) => gate.future),
        ],
      ),
    );
    await tester.tap(find.text('done'));
    await tester.pump();

    // Tear the importing page down, then let the eligibility query land.
    await tester.pumpWidget(
      const MaterialApp(home: Scaffold(body: SizedBox())),
    );
    await tester.pumpAndSettle();
    gate.complete(const ['d1']);
    await tester.pumpAndSettle();

    expect(tester.takeException(), isNull);
    expect(find.byType(SnackBar), findsNothing);
  });

  testWidgets('a host with no messenger, router or l10n is a silent no-op', (
    tester,
  ) async {
    // Callers run this inside the try that reports an import failure, so a
    // bare host must not turn a successful import into an error.
    late BuildContext hostContext;
    late WidgetRef hostRef;
    await tester.pumpWidget(
      ProviderScope(
        child: Directionality(
          textDirection: TextDirection.ltr,
          child: Consumer(
            builder: (context, ref, _) {
              hostContext = context;
              hostRef = ref;
              return const SizedBox();
            },
          ),
        ),
      ),
    );

    await expectLater(
      offerSiteReviewAfterImport(hostContext, hostRef, const ['d1']),
      completes,
    );
    expect(tester.takeException(), isNull);
  });
}
