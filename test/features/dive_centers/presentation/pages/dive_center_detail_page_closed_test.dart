import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:submersion/core/providers/provider.dart';
import 'package:submersion/features/dive_centers/data/repositories/dive_center_repository.dart';
import 'package:submersion/features/dive_centers/domain/entities/dive_center.dart';
import 'package:submersion/features/dive_centers/presentation/pages/dive_center_detail_page.dart';
import 'package:submersion/l10n/arb/app_localizations.dart';

import '../../../../helpers/mock_providers.dart';
import '../../../../helpers/test_database.dart';

/// The detail page names a permanently closed center (#3379).
void main() {
  setUp(setUpTestDatabase);
  tearDown(tearDownTestDatabase);

  Future<void> pumpDetail(WidgetTester tester, {required bool closed}) async {
    tester.view.physicalSize = const Size(400, 900);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);
    final now = DateTime(2026);
    final center = await DiveCenterRepository().createDiveCenter(
      DiveCenter(
        id: '',
        name: 'Toucan Diving',
        city: 'Kralendijk',
        isPermanentlyClosed: closed,
        createdAt: now,
        updatedAt: now,
      ),
    );
    final overrides = await getBaseOverrides();
    final router = GoRouter(
      initialLocation: '/dive-centers/${center.id}',
      routes: [
        GoRoute(
          path: '/dive-centers/:id',
          builder: (_, s) =>
              DiveCenterDetailPage(centerId: s.pathParameters['id']!),
        ),
      ],
    );
    await tester.pumpWidget(
      ProviderScope(
        overrides: overrides,
        child: MaterialApp.router(
          locale: const Locale('en'),
          routerConfig: router,
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
        ),
      ),
    );
    await tester.pumpAndSettle();
  }

  testWidgets('a closed center says so under its name', (tester) async {
    await pumpDetail(tester, closed: true);
    expect(find.text('Permanently closed'), findsOneWidget);
  });

  testWidgets('an open center does not', (tester) async {
    await pumpDetail(tester, closed: false);
    expect(find.text('Permanently closed'), findsNothing);
  });
}
