import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';

import 'package:submersion/features/dive_log/domain/entities/dive.dart';
import 'package:submersion/features/dive_log/domain/entities/dive_data_source.dart';
import 'package:submersion/features/dive_log/presentation/pages/dive_detail_page.dart';
import 'package:submersion/features/dive_log/presentation/providers/dive_providers.dart';
import 'package:submersion/features/dive_sites/domain/entities/dive_site.dart';
import 'package:submersion/l10n/arb/app_localizations.dart';

import '../../../../helpers/mock_providers.dart';

/// On a phone the dive detail page is a standalone page with an app bar.
/// That bar names the dive the same way the desktop pane's header does: its
/// own name when it has one, otherwise its site (issue #4445).
void main() {
  const site = DiveSite(id: 'site-1', name: 'House Reef');

  Future<void> pumpPhoneDetail(WidgetTester tester, Dive dive) async {
    tester.view.devicePixelRatio = 1.0;
    tester.view.physicalSize = const Size(400, 900);
    addTearDown(tester.view.reset);

    final overrides = await getBaseOverrides();
    final router = GoRouter(
      initialLocation: '/detail',
      routes: [
        GoRoute(
          path: '/detail',
          builder: (context, state) => DiveDetailPage(diveId: dive.id),
        ),
      ],
    );

    // The detail page overflows its fixed test viewport; that is not what
    // this test asserts, so swallow only overflow errors.
    final originalOnError = FlutterError.onError;
    FlutterError.onError = (details) {
      if (details.toString().contains('overflowed')) return;
      originalOnError?.call(details);
    };
    addTearDown(() => FlutterError.onError = originalOnError);

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          ...overrides,
          diveProvider(dive.id).overrideWith((ref) async => dive),
          diveDataSourcesProvider(
            dive.id,
          ).overrideWith((ref) async => <DiveDataSource>[]),
        ],
        child: MaterialApp.router(
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          locale: const Locale('en'),
          routerConfig: router,
        ),
      ),
    );
    await tester.pump();
    await tester.pump(const Duration(seconds: 1));
  }

  Finder inAppBar(String text) =>
      find.descendant(of: find.byType(AppBar), matching: find.text(text));

  testWidgets('app bar shows the site name', (tester) async {
    await pumpPhoneDetail(
      tester,
      createTestDiveWithBottomTime().copyWith(site: site),
    );

    expect(inAppBar('House Reef'), findsOneWidget);
    expect(inAppBar('Dive Details'), findsNothing);
  });

  testWidgets('app bar prefers the dive name over the site name', (
    tester,
  ) async {
    await pumpPhoneDetail(
      tester,
      createTestDiveWithBottomTime().copyWith(site: site, name: 'Night dive'),
    );

    expect(inAppBar('Night dive'), findsOneWidget);
    expect(inAppBar('House Reef'), findsNothing);
  });

  testWidgets('app bar ignores a blank dive name', (tester) async {
    await pumpPhoneDetail(
      tester,
      createTestDiveWithBottomTime().copyWith(site: site, name: '   '),
    );

    expect(inAppBar('House Reef'), findsOneWidget);
  });

  testWidgets('app bar falls back to unknown site without a site', (
    tester,
  ) async {
    await pumpPhoneDetail(tester, createTestDiveWithBottomTime());

    expect(inAppBar('Unknown Site'), findsOneWidget);
  });

  testWidgets('a long site name stays on one line in the app bar', (
    tester,
  ) async {
    const longName =
        'The Very Long Named Reef Wall Beyond The Northern Lighthouse Point';
    await pumpPhoneDetail(
      tester,
      createTestDiveWithBottomTime().copyWith(
        site: const DiveSite(id: 'site-2', name: longName),
      ),
    );

    final title = tester.widget<Text>(inAppBar(longName));
    expect(title.maxLines, 1);
    expect(title.overflow, TextOverflow.ellipsis);
  });
}
