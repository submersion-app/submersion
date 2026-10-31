import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:submersion/core/database/database.dart';
import 'package:submersion/core/providers/provider.dart';
import 'package:submersion/features/change_log/data/repositories/change_log_preferences.dart';
import 'package:submersion/features/change_log/data/repositories/change_log_repository.dart';
import 'package:submersion/features/change_log/presentation/pages/change_log_settings_page.dart';
import 'package:submersion/features/change_log/presentation/providers/change_log_providers.dart';
import 'package:submersion/features/change_log/presentation/widgets/change_log_storage_row.dart';
import 'package:submersion/features/divers/presentation/providers/diver_providers.dart';
import 'package:submersion/l10n/arb/app_localizations.dart';

import '../../../core/database/change_log/change_log_support.dart';
import '../../../helpers/mock_providers.dart';
import '../../../helpers/test_database.dart';

class _LockedRepository extends ChangeLogRepository {
  @override
  Future<int> clearForDiver(String diverId) =>
      Future.error(StateError('database is locked'));
}

void main() {
  late AppDatabase db;

  setUp(() async {
    db = await setUpTestDatabase();
    await insertDiver(db, 'me');
    await insertDive(db, 'dive', diverId: 'me', notes: 'Calm');
    await ChangeLogRepository().settleAll();
    await clearLog(db);
    await db.customStatement('DELETE FROM change_log_operations');
    await db.customStatement("UPDATE dives SET notes = 'Current'");
    await ChangeLogRepository().settleAll();
  });
  tearDown(tearDownTestDatabase);

  Future<SharedPreferences> pump(
    WidgetTester tester,
    Widget home, {
    List<Object> extra = const [],
  }) async {
    tester.view.devicePixelRatio = 1.0;
    tester.view.physicalSize = const Size(800, 1000);
    addTearDown(tester.view.reset);
    final overrides = await tester.runAsync(getBaseOverrides);
    final prefs = await tester.runAsync(SharedPreferences.getInstance);
    final router = GoRouter(
      routes: [GoRoute(path: '/', builder: (context, state) => home)],
    );
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          ...overrides!,
          validatedCurrentDiverIdProvider.overrideWith((ref) async => 'me'),
          ...extra,
        ].cast(),
        child: MaterialApp.router(
          locale: const Locale('en'),
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          routerConfig: router,
        ),
      ),
    );
    await settle(tester);
    return prefs!;
  }

  Future<int> operationCount(WidgetTester tester) async {
    final rows = await tester.runAsync(
      () => db.select(db.changeLogOperations).get(),
    );
    return rows!.length;
  }

  testWidgets('the retention picker saves', (tester) async {
    final prefs = await pump(tester, const ChangeLogSettingsPage());
    expect(find.text('12 months'), findsOneWidget);

    await tester.tap(find.text('3 months'));
    await settle(tester);

    expect(ChangeLogPreferences(prefs).retentionMonths, 3);
  });

  testWidgets('a clear that fails says so', (tester) async {
    await pump(
      tester,
      const ChangeLogSettingsPage(),
      extra: [
        changeLogRepositoryProvider.overrideWithValue(_LockedRepository()),
      ],
    );

    await tester.tap(find.text('Clear log'));
    await settle(tester);
    await tester.tap(find.widgetWithText(FilledButton, 'Clear'));
    await settle(tester);

    expect(
      find.text("Couldn't clear the change log. Nothing was removed."),
      findsOneWidget,
    );
  });

  testWidgets('forever is offered', (tester) async {
    final prefs = await pump(tester, const ChangeLogSettingsPage());

    await tester.tap(find.text('Forever'));
    await settle(tester);

    expect(ChangeLogPreferences(prefs).retentionMonths, 0);
  });

  testWidgets('Clear log confirms first', (tester) async {
    await pump(tester, const ChangeLogSettingsPage());

    await tester.tap(find.text('Clear log'));
    await settle(tester);

    expect(find.text('Clear the change log?'), findsOneWidget);
    expect(await operationCount(tester), 1);

    await tester.tap(find.text('Cancel'));
    await settle(tester);
    expect(await operationCount(tester), 1);

    await tester.tap(find.text('Clear log'));
    await settle(tester);
    await tester.tap(find.text('Clear'));
    await settle(tester);

    expect(await operationCount(tester), 0);
  });

  testWidgets('Storage usage shows a Change log line', (tester) async {
    await pump(tester, const Scaffold(body: ChangeLogStorageRow()));

    expect(find.text('Change log'), findsOneWidget);
    expect(find.textContaining('B'), findsWidgets);
  });
}

Future<void> settle(WidgetTester tester) async {
  for (var i = 0; i < 6; i++) {
    await tester.runAsync(
      () => Future<void>.delayed(const Duration(milliseconds: 30)),
    );
    await tester.pump();
  }
  await tester.pump(const Duration(milliseconds: 400));
}
