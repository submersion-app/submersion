import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/features/certifications/data/repositories/certification_repository.dart';
import 'package:submersion/features/certifications/presentation/pages/certification_edit_page.dart';
import 'package:submersion/features/certifications/presentation/providers/certification_providers.dart';
import 'package:submersion/l10n/arb/app_localizations.dart';
import 'package:submersion/shared/widgets/tab_visibility.dart';

import '../../../../helpers/mock_providers.dart';
import '../../../../helpers/test_database.dart';

/// An unsaved embedded editor in a Training tab the diver has switched away
/// from must not answer Back with a discard dialog for a form that is not on
/// screen (#3437).
void main() {
  setUp(() async {
    await setUpTestDatabase();
  });

  tearDown(() async {
    await tearDownTestDatabase();
  });

  Future<void> pumpEditorRoute(
    WidgetTester tester, {
    required bool visible,
  }) async {
    tester.view.physicalSize = const Size(1200, 2000);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);

    final overrides = await getBaseOverrides();
    final navigatorKey = GlobalKey<NavigatorState>();
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          ...overrides,
          certificationRepositoryProvider.overrideWithValue(
            CertificationRepository(),
          ),
        ],
        child: MaterialApp(
          navigatorKey: navigatorKey,
          locale: const Locale('en'),
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: const Scaffold(body: Text('home')),
        ),
      ),
    );
    navigatorKey.currentState!.push(
      MaterialPageRoute<void>(
        builder: (_) => Scaffold(
          body: TabVisibility(
            visible: visible,
            child: const CertificationEditPage(embedded: true),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextFormField).first, 'Rescue Diver');
    await tester.pump();
    await navigatorKey.currentState!.maybePop();
    await tester.pumpAndSettle();
  }

  testWidgets('a hidden tab lets Back leave without a discard dialog', (
    tester,
  ) async {
    await pumpEditorRoute(tester, visible: false);

    expect(find.byType(AlertDialog), findsNothing);
    expect(find.text('home'), findsOneWidget);
  });

  testWidgets('a shown tab still asks before discarding', (tester) async {
    await pumpEditorRoute(tester, visible: true);

    expect(find.byType(AlertDialog), findsOneWidget);
  });
}
