import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';

import 'package:submersion/core/data/repositories/sync_repository.dart';
import 'package:submersion/core/database/database.dart';
import 'package:submersion/core/providers/provider.dart';
import 'package:submersion/core/services/change_log/change_log_scope.dart';
import 'package:submersion/core/services/sync/sync_clock.dart';
import 'package:submersion/core/services/sync/sync_coordinator.dart';
import 'package:submersion/features/change_log/data/repositories/change_log_repository.dart';
import 'package:submersion/features/change_log/data/services/change_log_revert_service.dart';
import 'package:submersion/features/change_log/domain/entities/change_log_filter.dart';
import 'package:submersion/features/change_log/presentation/pages/change_log_entry_page.dart';
import 'package:submersion/features/change_log/presentation/providers/change_log_providers.dart';
import 'package:submersion/features/divers/presentation/providers/diver_providers.dart';
import 'package:submersion/l10n/arb/app_localizations.dart';

import '../../../core/database/change_log/change_log_support.dart';
import '../../../helpers/mock_providers.dart';
import '../../../helpers/test_database.dart';

void main() {
  late AppDatabase db;
  final repository = ChangeLogRepository();

  setUp(() async {
    db = await setUpTestDatabase();
    SyncClock.instance.configure(nodeId: 'node-test', now: () => 5000);
    await insertDiver(db, 'me');
    await insertDive(db, 'dive', diverId: 'me', notes: 'Calm');
    await repository.settleAll();
    await clearLog(db);
    await db.customStatement('DELETE FROM change_log_operations');
    await SyncRepository().clearPendingRecords();
  });

  tearDown(() async {
    // A turn queued in one test's fake zone would never run in the next.
    SyncCoordinator.reset();
    SyncClock.instance.reset();
    await tearDownTestDatabase();
  });

  Future<String> newestOperation() async {
    await repository.settleAll();
    final feed = await repository.getFeed(
      diverId: 'me',
      filter: const ChangeLogFilter(),
    );
    return feed.first.id;
  }

  Future<String?> notes() async {
    final row = await db
        .customSelect("SELECT notes FROM dives WHERE id = 'dive'")
        .getSingleOrNull();
    return row?.data['notes'] as String?;
  }

  Future<void> pump(
    WidgetTester tester,
    String id, {
    ChangeLogRevertService? service,
  }) async {
    tester.view.devicePixelRatio = 1.0;
    tester.view.physicalSize = const Size(800, 1200);
    addTearDown(tester.view.reset);
    final overrides = await tester.runAsync(getBaseOverrides);
    final router = GoRouter(
      routes: [
        GoRoute(
          path: '/',
          builder: (context, state) => ChangeLogEntryPage(operationId: id),
        ),
      ],
    );
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          ...overrides!,
          validatedCurrentDiverIdProvider.overrideWith((ref) async => 'me'),
          changeLogRevertServiceProvider.overrideWithValue(
            service ?? ChangeLogRevertService(afterDiveWrites: (_) {}),
          ),
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
  }

  testWidgets('Revert all applies with no prompt when nothing changed since', (
    tester,
  ) async {
    final id = await tester.runAsync(() async {
      await db.customStatement(
        "UPDATE dives SET notes = 'Current', max_depth = 30 WHERE id = 'dive'",
      );
      return newestOperation();
    });
    await pump(tester, id!);

    await tester.tap(find.text('Revert all 2'));
    await settle(tester);

    expect(find.byType(AlertDialog), findsNothing);
    expect(await tester.runAsync(notes), 'Calm');
    expect(find.text('Reverted'), findsOneWidget);
  });

  testWidgets('one field reverts on its own', (tester) async {
    final id = await tester.runAsync(() async {
      await db.customStatement(
        "UPDATE dives SET notes = 'Current', max_depth = 30 WHERE id = 'dive'",
      );
      return newestOperation();
    });
    await pump(tester, id!);

    await tester.tap(find.byKey(const ValueKey('change_log_revert_notes')));
    await settle(tester);

    expect(await tester.runAsync(notes), 'Calm');
    expect(find.byKey(const ValueKey('change_log_revert_notes')), findsNothing);
    expect(
      find.byKey(const ValueKey('change_log_revert_max_depth')),
      findsOneWidget,
    );
  });

  testWidgets('the three-value warning shows when a value changed since', (
    tester,
  ) async {
    final id = await tester.runAsync(() async {
      await db.customStatement(
        "UPDATE dives SET notes = 'Current' WHERE id = 'dive'",
      );
      final id = await newestOperation();
      await db.customStatement(
        "UPDATE dives SET notes = 'Later' WHERE id = 'dive'",
      );
      return id;
    });
    await pump(tester, id!);

    await tester.tap(find.byKey(const ValueKey('change_log_revert_notes')));
    await settle(tester);

    expect(
      find.text('This field has changed since this entry.'),
      findsOneWidget,
    );
    expect(find.text('Set in this entry: Current'), findsOneWidget);
    expect(find.text('Now: Later'), findsOneWidget);
    expect(find.text('After revert: Calm'), findsOneWidget);

    await tester.tap(find.text('Revert anyway'));
    await settle(tester);

    expect(await tester.runAsync(notes), 'Calm');
  });

  testWidgets('Cancel leaves the value alone', (tester) async {
    final id = await tester.runAsync(() async {
      await db.customStatement(
        "UPDATE dives SET notes = 'Current' WHERE id = 'dive'",
      );
      final id = await newestOperation();
      await db.customStatement(
        "UPDATE dives SET notes = 'Later' WHERE id = 'dive'",
      );
      return id;
    });
    await pump(tester, id!);

    await tester.tap(find.byKey(const ValueKey('change_log_revert_notes')));
    await settle(tester);
    await tester.tap(find.text('Cancel'));
    await settle(tester);

    expect(await tester.runAsync(notes), 'Later');
  });

  Future<String> importedAndEdited() async {
    await ChangeLogScope.run(
      db,
      source: ChangeLogSource.import,
      label: 'Perdix',
      body: () async {
        await insertDive(db, 'one', diverId: 'me');
        await insertDive(db, 'two', diverId: 'me');
      },
    );
    final id = await newestOperation();
    await db.customStatement(
      "UPDATE dives SET notes = 'Mine now' WHERE id = 'two'",
    );
    await repository.settleAll();
    return id;
  }

  testWidgets('bulk undo offers the three choices', (tester) async {
    final id = await tester.runAsync(importedAndEdited);
    await pump(tester, id!);

    await tester.tap(find.text('Undo this import'));
    await settle(tester);

    expect(find.text('Revert the rest'), findsOneWidget);
    expect(find.text('Revert all'), findsOneWidget);
    expect(find.text('Cancel'), findsOneWidget);
    expect(find.text('1 record has changed since this entry.'), findsOneWidget);

    await tester.tap(find.text('Revert the rest'));
    await settle(tester);

    final left = await tester.runAsync(
      () => db.customSelect("SELECT id FROM dives WHERE id != 'dive'").get(),
    );
    expect(left!.map((r) => r.read<String>('id')), ['two']);
  });

  testWidgets('a bulk undo with nothing changed still asks first', (
    tester,
  ) async {
    final id = await tester.runAsync(() async {
      await ChangeLogScope.run(
        db,
        source: ChangeLogSource.import,
        body: () => insertDive(db, 'one', diverId: 'me'),
      );
      return newestOperation();
    });
    await pump(tester, id!);

    await tester.tap(find.text('Undo this import'));
    await settle(tester);

    expect(find.text('Revert the rest'), findsNothing);
    expect(find.text('Revert all'), findsOneWidget);
  });

  testWidgets('kept records are listed after a bulk undo', (tester) async {
    final id = await tester.runAsync(() async {
      await ChangeLogScope.run(
        db,
        source: ChangeLogSource.import,
        body: () => db.customStatement(
          'INSERT INTO dive_sites (id, diver_id, name, created_at, '
          "updated_at) VALUES ('reef', 'me', 'Coral Reef', 0, 0), "
          "('spare', 'me', 'Spare Reef', 0, 0)",
        ),
      );
      final id = await newestOperation();
      await db.customStatement("UPDATE dives SET site_id = 'reef'");
      await repository.settleAll();
      return id;
    });
    await pump(tester, id!);

    await tester.tap(find.text('Undo this import'));
    await settle(tester);
    await tester.tap(find.text('Revert all'));
    await settle(tester);

    expect(find.text('1 record was kept'), findsOneWidget);
    expect(find.text('Coral Reef'), findsWidgets);
    expect(find.text('Later data still uses this record.'), findsOneWidget);
  });

  testWidgets('a record that cannot go explains why', (tester) async {
    final id = await tester.runAsync(() async {
      await db.customStatement(
        'INSERT INTO dive_sites (id, diver_id, name, created_at, updated_at) '
        "VALUES ('reef', 'me', 'Coral Reef', 0, 0)",
      );
      final id = await newestOperation();
      await db.customStatement("UPDATE dives SET site_id = 'reef'");
      await repository.settleAll();
      return id;
    });
    await pump(tester, id!);

    expect(find.text('Later data still uses this record.'), findsOneWidget);
    expect(find.text('Undo this change'), findsNothing);
  });

  testWidgets('a blocked field explains why', (tester) async {
    final id = await tester.runAsync(() async {
      await db.customStatement(
        "UPDATE dives SET notes = 'Current' WHERE id = 'dive'",
      );
      final id = await newestOperation();
      await db.customStatement("DELETE FROM dives WHERE id = 'dive'");
      await repository.settleAll();
      return id;
    });
    await pump(tester, id!);

    expect(find.text('This record no longer exists.'), findsOneWidget);
    expect(find.byKey(const ValueKey('change_log_revert_notes')), findsNothing);
  });

  testWidgets('a deleted record offers Restore', (tester) async {
    final id = await tester.runAsync(() async {
      await db.customStatement("DELETE FROM dives WHERE id = 'dive'");
      return newestOperation();
    });
    await pump(tester, id!);

    await tester.tap(find.text('Restore'));
    await settle(tester);

    expect(await tester.runAsync(notes), 'Calm');
  });

  testWidgets('a reverted entry shows its badge', (tester) async {
    final id = await tester.runAsync(() async {
      await db.customStatement(
        "UPDATE dives SET notes = 'Current' WHERE id = 'dive'",
      );
      final id = await newestOperation();
      final service = ChangeLogRevertService(afterDiveWrites: (_) {});
      await service.execute(await service.planOperation(id));
      return id;
    });
    await pump(tester, id!);

    expect(find.text('Reverted'), findsOneWidget);
    expect(find.textContaining('Revert all'), findsNothing);
  });

  testWidgets('a failed revert says so', (tester) async {
    final id = await tester.runAsync(() async {
      await db.customStatement(
        "UPDATE dives SET notes = 'Current' WHERE id = 'dive'",
      );
      return newestOperation();
    });
    await pump(tester, id!, service: _FailingRevertService());

    await tester.tap(find.byKey(const ValueKey('change_log_revert_notes')));
    await settle(tester);

    expect(
      find.text("Couldn't revert this change. Nothing was changed."),
      findsOneWidget,
    );
  });
}

class _FailingRevertService extends ChangeLogRevertService {
  @override
  Future<Never> execute(plan, {bool includeChangedSince = true}) async =>
      throw StateError('no');
}

Future<void> settle(WidgetTester tester) async {
  for (var i = 0; i < 8; i++) {
    await tester.runAsync(
      () => Future<void>.delayed(const Duration(milliseconds: 30)),
    );
    await tester.pump();
  }
  await tester.pump(const Duration(milliseconds: 400));
}
