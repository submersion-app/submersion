import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:submersion/features/dive_log/data/repositories/dive_repository_impl.dart';
import 'package:submersion/features/dive_log/presentation/pages/dive_list_page.dart';
import 'package:submersion/features/dive_log/presentation/providers/dive_providers.dart';
import 'package:submersion/features/explore/presentation/providers/explore_gate_providers.dart';
import 'package:submersion/l10n/arb/app_localizations.dart';
import 'package:submersion/l10n/arb/app_localizations_en.dart';

import '../../../../helpers/mock_providers.dart';
import '../../../../helpers/test_database.dart';

void main() {
  late DiveRepository repository;
  final tooltip = AppLocalizationsEn().diveLog_listPage_tooltip_explore;

  setUp(() async {
    await setUpTestDatabase();
    repository = DiveRepository();
  });
  tearDown(() async => tearDownTestDatabase());

  Future<void> pump(WidgetTester tester, {required bool enabled}) async {
    final overrides = await getBaseOverrides();
    final router = GoRouter(
      routes: [
        GoRoute(path: '/', builder: (context, state) => const DiveListPage()),
        GoRoute(
          path: '/dives/explore',
          builder: (context, state) => const Scaffold(),
        ),
      ],
    );
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          ...overrides,
          diveRepositoryProvider.overrideWithValue(repository),
          diveListNotifierProvider.overrideWith(
            (ref) => DiveListNotifier(repository, ref),
          ),
          paginatedDiveListProvider.overrideWith(
            (ref) => PaginatedDiveListNotifier(repository, ref),
          ),
          exploreEnabledProvider.overrideWithValue(enabled),
        ].cast(),
        child: MaterialApp.router(
          locale: const Locale('en'),
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          routerConfig: router,
        ),
      ),
    );
    await tester.pumpAndSettle();
  }

  testWidgets('the explore action is hidden when the gate is closed', (
    tester,
  ) async {
    await pump(tester, enabled: false);
    expect(find.byTooltip(tooltip), findsNothing);
  });

  testWidgets('the explore action is shown when the gate is open', (
    tester,
  ) async {
    await pump(tester, enabled: true);
    expect(find.byTooltip(tooltip), findsOneWidget);
  });
}
