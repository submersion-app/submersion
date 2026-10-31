import 'package:drift/drift.dart' show Value;
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';

import 'package:submersion/core/database/database.dart';
import 'package:submersion/core/providers/provider.dart';
import 'package:submersion/core/services/change_log/change_log_scope.dart';
import 'package:submersion/features/change_log/data/repositories/change_log_repository.dart';
import 'package:submersion/features/change_log/domain/entities/change_log_filter.dart';
import 'package:submersion/features/change_log/presentation/pages/change_log_entry_page.dart';
import 'package:submersion/features/change_log/presentation/widgets/change_log_history_menu_item.dart';
import 'package:submersion/features/divers/presentation/providers/diver_providers.dart';
import 'package:submersion/l10n/arb/app_localizations.dart';

import '../../../core/database/change_log/change_log_support.dart';
import '../../../helpers/mock_providers.dart';
import '../../../helpers/test_database.dart';

void main() {
  late AppDatabase db;

  setUp(() async {
    db = await setUpTestDatabase();
    await insertDiver(db, 'me');
    await db
        .into(db.diveSites)
        .insert(
          DiveSitesCompanion.insert(
            id: 'site',
            name: 'Blue Hole',
            createdAt: 0,
            updatedAt: 0,
            diverId: const Value('me'),
          ),
        );
    await insertDive(db, 'dive', diverId: 'me', notes: 'Calm');
    await db.customStatement(
      "UPDATE dives SET dive_number = 412, site_id = 'site' WHERE id = 'dive'",
    );
    await ChangeLogRepository().settleAll();
    await clearLog(db);
    await db.customStatement('DELETE FROM change_log_operations');
  });
  tearDown(tearDownTestDatabase);

  Future<String> onlyOperation() async {
    final repository = ChangeLogRepository();
    await repository.settleAll();
    final feed = await repository.getFeed(
      diverId: 'me',
      filter: const ChangeLogFilter(),
    );
    return feed.single.id;
  }

  Future<List<String>> pump(WidgetTester tester, String id) async {
    tester.view.devicePixelRatio = 1.0;
    tester.view.physicalSize = const Size(800, 1000);
    addTearDown(tester.view.reset);
    final overrides = await tester.runAsync(getBaseOverrides);
    final pushed = <String>[];
    final router = GoRouter(
      routes: [
        GoRoute(
          path: '/',
          builder: (context, state) => ChangeLogEntryPage(operationId: id),
        ),
        GoRoute(
          path: '/:rest(.*)',
          builder: (context, state) {
            pushed.add(state.uri.toString());
            return const Scaffold(body: SizedBox());
          },
        ),
      ],
    );
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          ...overrides!,
          validatedCurrentDiverIdProvider.overrideWith((ref) async => 'me'),
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
    return pushed;
  }

  testWidgets('detail lists every changed field', (tester) async {
    final id = await tester.runAsync(() async {
      await db.customStatement(
        "UPDATE dives SET notes = 'Current', max_depth = 30, avg_depth = 12, "
        "boat_name = 'Sea Fox' WHERE id = 'dive'",
      );
      return onlyOperation();
    });

    await pump(tester, id!);

    expect(find.text('Dive 412, Blue Hole'), findsOneWidget);
    for (final label in ['Notes', 'Max Depth', 'Average Depth', 'Boat name']) {
      expect(find.text(label), findsOneWidget, reason: label);
    }
    expect(find.text('Current'), findsOneWidget);
    expect(find.text('Calm'), findsOneWidget);
  });

  testWidgets('two saves to one field show as one change', (tester) async {
    final id = await tester.runAsync(() async {
      await db.customStatement(
        "UPDATE dives SET notes = 'One' WHERE id = 'dive'",
      );
      await db.customStatement(
        "UPDATE dives SET notes = 'Two' WHERE id = 'dive'",
      );
      return onlyOperation();
    });

    await pump(tester, id!);

    expect(tester.takeException(), isNull);
    expect(find.text('Notes'), findsOneWidget);
    expect(find.text('Calm'), findsOneWidget);
    expect(find.text('Two'), findsOneWidget);
    expect(find.text('One'), findsNothing);
  });

  testWidgets('a bulk entry lists its records', (tester) async {
    final id = await tester.runAsync(() async {
      await insertDive(db, 'second', diverId: 'me');
      await db.customStatement(
        "UPDATE dives SET dive_number = 413 WHERE id = 'second'",
      );
      await ChangeLogRepository().settleAll();
      await clearLog(db);
      await db.customStatement('DELETE FROM change_log_operations');
      await ChangeLogScope.run(
        db,
        source: ChangeLogSource.import,
        label: 'Perdix',
        body: () async {
          await db.customStatement("UPDATE dives SET notes = 'Imported'");
        },
      );
      return onlyOperation();
    });

    await pump(tester, id!);

    expect(find.text('Imported from Perdix'), findsOneWidget);
    expect(find.textContaining('Blue Hole'), findsWidgets);
    expect(find.byType(ExpansionTile), findsNWidgets(2));
  });

  testWidgets('a live record offers its link', (tester) async {
    final id = await tester.runAsync(() async {
      await db.customStatement(
        "UPDATE dives SET notes = 'Current' WHERE id = 'dive'",
      );
      return onlyOperation();
    });

    final pushed = await pump(tester, id!);
    await tester.tap(find.text('Open record'));
    await settle(tester);

    expect(pushed, ['/dives/dive']);
  });

  testWidgets('a deleted record shows no open link', (tester) async {
    final id = await tester.runAsync(() async {
      await db.customStatement("DELETE FROM dives WHERE id = 'dive'");
      return onlyOperation();
    });

    await pump(tester, id!);

    expect(find.text('Dive 412, Blue Hole'), findsOneWidget);
    expect(find.text('Open record'), findsNothing);
    expect(find.text('Deleted'), findsOneWidget);
  });

  testWidgets("a dive's History item opens the filtered log", (tester) async {
    final pushed = <String>[];
    final router = GoRouter(
      routes: [
        GoRoute(
          path: '/',
          builder: (context, state) => Scaffold(
            appBar: AppBar(
              actions: [
                PopupMenuButton<String>(
                  key: const ValueKey('menu'),
                  itemBuilder: (context) => [
                    changeLogHistoryMenuItem(
                      context,
                      rootTable: 'dives',
                      rootId: 'dive 1',
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
        GoRoute(
          path: '/:rest(.*)',
          builder: (context, state) {
            pushed.add(state.uri.toString());
            return const Scaffold(body: SizedBox());
          },
        ),
      ],
    );
    await tester.pumpWidget(
      MaterialApp.router(
        locale: const Locale('en'),
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        routerConfig: router,
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const ValueKey('menu')));
    await tester.pumpAndSettle();
    await tester.tap(find.text('History'));
    await tester.pumpAndSettle();

    expect(pushed, ['/settings/change-log?rootTable=dives&rootId=dive+1']);
  });
}

Future<void> settle(WidgetTester tester) async {
  for (var i = 0; i < 6; i++) {
    await tester.runAsync(
      () => Future<void>.delayed(const Duration(milliseconds: 30)),
    );
    await tester.pump();
  }
  await tester.pump(const Duration(milliseconds: 100));
}
