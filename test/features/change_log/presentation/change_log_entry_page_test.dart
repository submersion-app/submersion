import 'package:drift/drift.dart' show Value;
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';

import 'package:submersion/core/database/database.dart';
import 'package:submersion/core/providers/provider.dart';
import 'package:submersion/core/services/change_log/change_log_scope.dart';
import 'package:submersion/core/services/change_log/record_edit_label.dart';
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

  testWidgets('a sitting entry shows the dive, a site child row and a '
      'dismissal row, each with Revert', (tester) async {
    final id = await tester.runAsync(() async {
      await db.customStatement(
        'INSERT INTO dive_safety_findings (id, dive_id, rule_id, severity, '
        "engine_version, created_at) VALUES ('finding', 'dive', "
        "'fast_ascent', 'warning', 1, 0)",
      );
      await ChangeLogRepository().settleAll();
      await clearLog(db);
      await db.customStatement('DELETE FROM change_log_operations');
      await ChangeLogScope.run(
        db,
        source: ChangeLogSource.manual,
        label: RecordEditLabel.encode(
          table: 'dives',
          id: 'dive',
          cardIds: ['notes', 'safetyReview'],
        ),
        body: () async {
          await db.customStatement(
            "UPDATE dives SET notes = 'Current' WHERE id = 'dive'",
          );
          await db.customStatement(
            "UPDATE dive_sites SET altitude = 512 WHERE id = 'site'",
          );
          await db.customStatement(
            'UPDATE dive_safety_findings SET dismissed_at = 7000',
          );
        },
      );
      return onlyOperation();
    });

    await pump(tester, id!);

    expect(tester.takeException(), isNull);
    expect(find.text('Dive 412, Blue Hole'), findsOneWidget);
    expect(find.text('Safety finding · Edited'), findsOneWidget);
    for (final column in ['notes', 'altitude', 'dismissed_at']) {
      expect(
        find.byKey(ValueKey('change_log_revert_$column')),
        findsOneWidget,
        reason: column,
      );
    }
  });

  // A new dive's sitting creates the dive (issue #4527, plan 8).
  testWidgets('a sitting that created its dive names its cards alone', (
    tester,
  ) async {
    final id = await tester.runAsync(() async {
      await ChangeLogScope.run(
        db,
        source: ChangeLogSource.manual,
        label: RecordEditLabel.encode(
          table: 'dives',
          id: 'new-dive',
          cardIds: ['header', 'notes'],
        ),
        body: () => insertDive(db, 'new-dive', diverId: 'me', notes: 'Wall'),
      );
      return onlyOperation();
    });

    await pump(tester, id!);

    expect(tester.takeException(), isNull);
    expect(find.textContaining('Dive, Notes'), findsOneWidget);
    expect(find.textContaining('Edited: Dive'), findsNothing);
  });

  // Readings move between cylinders in pairs, so reverting one row on its
  // own would leave both series on one cylinder and none on the other.
  testWidgets('moved readings are listed with no Revert of their own', (
    tester,
  ) async {
    final id = await tester.runAsync(() async {
      for (final tank in ['a', 'b']) {
        await db.customStatement(
          "INSERT INTO dive_tanks (id, dive_id) VALUES (?, 'dive')",
          [tank],
        );
      }
      for (final (series, tank) in [('s1', 'a'), ('s2', 'b')]) {
        await db.customStatement(
          'INSERT INTO tank_pressure_series (id, dive_id, tank_id, '
          'sample_count, start_timestamp, end_timestamp, codec_version, '
          "samples, created_at, updated_at) VALUES (?, 'dive', ?, 2, 0, 60, "
          "1, X'010203', 0, 0)",
          [series, tank],
        );
      }
      await ChangeLogRepository().settleAll();
      await clearLog(db);
      await db.customStatement('DELETE FROM change_log_operations');
      await ChangeLogScope.run(
        db,
        source: ChangeLogSource.manual,
        label: RecordEditLabel.encode(
          table: 'dives',
          id: 'dive',
          cardIds: ['notes', 'tanks'],
        ),
        body: () async {
          await db.customStatement(
            "UPDATE dives SET notes = 'Current' WHERE id = 'dive'",
          );
          await db.customStatement(
            'UPDATE tank_pressure_series SET tank_id = '
            "CASE tank_id WHEN 'a' THEN 'b' ELSE 'a' END",
          );
        },
      );
      return onlyOperation();
    });

    await pump(tester, id!);

    expect(tester.takeException(), isNull);
    expect(find.text('Pressure readings · Edited'), findsNWidgets(2));
    expect(
      find.byKey(const ValueKey('change_log_revert_notes')),
      findsOneWidget,
    );
    expect(
      find.byKey(const ValueKey('change_log_revert_tank_id')),
      findsNothing,
    );
  });

  // A type row records no fields when it is added, and its removal's copy
  // is not a change of any one field, so without a name the row said only
  // that something was added.
  testWidgets('an added and a removed dive type each name the type', (
    tester,
  ) async {
    final id = await tester.runAsync(() async {
      await db.customStatement(
        'INSERT INTO dive_dive_types (id, dive_id, dive_type_id, created_at) '
        "VALUES ('old', 'dive', 'night', 1)",
      );
      await ChangeLogRepository().settleAll();
      await clearLog(db);
      await db.customStatement('DELETE FROM change_log_operations');
      await ChangeLogScope.run(
        db,
        source: ChangeLogSource.manual,
        label: RecordEditLabel.encode(
          table: 'dives',
          id: 'dive',
          cardIds: ['notes'],
        ),
        body: () async {
          await db.customStatement(
            "UPDATE dives SET notes = 'Current' WHERE id = 'dive'",
          );
          await db.customStatement(
            "DELETE FROM dive_dive_types WHERE id = 'old'",
          );
          await db.customStatement(
            'INSERT INTO dive_dive_types (id, dive_id, dive_type_id, '
            "created_at) VALUES ('new', 'dive', 'wreck', 2)",
          );
        },
      );
      return onlyOperation();
    });

    await pump(tester, id!);

    expect(tester.takeException(), isNull);
    expect(find.text('Dive type · Added'), findsOneWidget);
    expect(find.text('Dive type · Deleted'), findsOneWidget);
    expect(find.text('Wreck'), findsOneWidget);
    expect(find.text('Night'), findsOneWidget);
    expect(find.text('dive_type_id'), findsNothing);
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

  testWidgets('another diver\'s entry does not open', (tester) async {
    final id = await tester.runAsync(() async {
      await insertDiver(db, 'them');
      await insertDive(db, 'theirs', diverId: 'them', notes: 'Flat');
      await ChangeLogRepository().settleAll();
      await clearLog(db);
      await db.customStatement('DELETE FROM change_log_operations');
      await db.customStatement(
        "UPDATE dives SET notes = 'Private' WHERE id = 'theirs'",
      );
      await ChangeLogRepository().settleAll();
      final row = await db
          .customSelect('SELECT id FROM change_log_operations')
          .getSingle();
      return row.read<String>('id');
    });

    await pump(tester, id!);

    expect(find.text('Private'), findsNothing);
    expect(find.text('Revert'), findsNothing);
  });

  testWidgets('a deleted dive shows no false more records line', (
    tester,
  ) async {
    final id = await tester.runAsync(() async {
      await db.customStatement(
        'INSERT INTO tide_records (id, dive_id, height_meters, tide_state, '
        "created_at) VALUES ('tide', 'dive', 1.0, 'rising', 0)",
      );
      await ChangeLogRepository().settleAll();
      await clearLog(db);
      await db.customStatement('DELETE FROM change_log_operations');
      await db.customStatement("DELETE FROM dives WHERE id = 'dive'");
      return onlyOperation();
    });

    await pump(tester, id!);

    expect(find.textContaining('more record'), findsNothing);
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
