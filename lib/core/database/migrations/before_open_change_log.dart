part of 'app_database_migrations.dart';

/// Removes every change log trigger. Run before the ladder, because a
/// trigger that names a column makes dropping that column fail, and again
/// before reinstalling.
Future<void> dropChangeLogTriggers(GeneratedDatabase db) async {
  final rows = await db
      .customSelect(
        "SELECT name FROM sqlite_master WHERE type = 'trigger' "
        'AND substr(name, 1, ${kChangeLogTriggerPrefix.length}) = ?',
        variables: const [Variable<String>(kChangeLogTriggerPrefix)],
      )
      .get();
  for (final row in rows) {
    await db.customStatement(
      'DROP TRIGGER IF EXISTS "${row.read<String>('name')}"',
    );
  }
}

/// The change log's beforeOpen step (issue #3922). Split from
/// before_open.dart, which is at the 800-line limit.
extension ChangeLogBackstop on AppDatabase {
  /// Asserts the log tables and triggers. Runs on every open, in both
  /// isolates, so it must never touch the source or suppression columns of
  /// the context row, which a running job in the other isolate may hold.
  ///
  /// Nothing here is rethrown: logging must never stop the app opening. A
  /// failure leaves no triggers at all, because a stale one could fail a
  /// save, and the app runs without recording.
  Future<void> _assertChangeLog() async {
    try {
      // On the connection, not in applyConnectionBasics: test databases and
      // the plain opener bypass that. Without it INSERT OR REPLACE fires no
      // delete trigger and the replaced row would be lost.
      await customStatement('PRAGMA recursive_triggers = ON');
      await _assertChangeLogSchema();
      await _assertChangeLogTriggers();
    } catch (error, stackTrace) {
      developer.log(
        'Could not install the change log',
        name: 'ChangeLog',
        error: error,
        stackTrace: stackTrace,
      );
      await _removeChangeLogTriggersAfterFailure();
    }
  }

  Future<void> _removeChangeLogTriggersAfterFailure() async {
    try {
      await dropChangeLogTriggers(this);
    } catch (error, stackTrace) {
      developer.log(
        'Could not remove the change log triggers',
        name: 'ChangeLog',
        error: error,
        stackTrace: stackTrace,
      );
    }
  }

  /// Replaces the triggers when the generated SQL differs from what the file
  /// holds, which also catches a database that arrived by restore or
  /// adoption, and one whose triggers went with a rebuilt table.
  Future<void> _assertChangeLogTriggers() async {
    final statements = await _changeLogTriggerStatements();
    final hash = changeLogTriggersHash(statements);

    final context = await customSelect(
      'SELECT trigger_hash FROM change_log_context WHERE id = 1',
    ).getSingle();
    final installed = await customSelect(
      "SELECT COUNT(*) AS c FROM sqlite_master WHERE type = 'trigger' "
      'AND substr(name, 1, ${kChangeLogTriggerPrefix.length}) = ?',
      variables: const [Variable<String>(kChangeLogTriggerPrefix)],
    ).getSingle();
    if (context.data['trigger_hash'] == hash &&
        installed.read<int>('c') == statements.length) {
      return;
    }

    await transaction(() async {
      await dropChangeLogTriggers(this);
      for (final statement in statements) {
        await customStatement(statement);
      }
      await customStatement(
        'UPDATE change_log_context SET trigger_hash = ? WHERE id = 1',
        [hash],
      );
    });
  }

  /// The triggers this file needs, narrowed to the tables and columns it
  /// really holds. A migration test's partial schema has fewer of both.
  Future<List<String>> _changeLogTriggerStatements() async {
    final rows = await customSelect(
      'SELECT m.name AS t, p.name AS c FROM sqlite_master m '
      "JOIN pragma_table_info(m.name) p WHERE m.type = 'table'",
    ).get();
    final present = <String, Set<String>>{};
    for (final row in rows) {
      (present[row.read<String>('t')] ??= {}).add(row.read<String>('c'));
    }

    return [
      for (final spec in changeLogSpecsFor(this))
        if (present[spec.table] case final columns?)
          ...buildChangeLogTriggers(
            spec.narrowedTo(columns),
            changeLogTables[spec.table] ?? ChangeLogClass.excluded,
            schemaVersion: AppDatabase.currentSchemaVersion,
          ),
    ];
  }
}
