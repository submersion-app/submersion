import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/core/data/repositories/sync_repository.dart';
import 'package:submersion/core/database/database.dart';
import 'package:submersion/core/database/tag_scope_tables.dart';
import 'package:submersion/features/tags/domain/entities/tag.dart';

/// The tag scope registry (issue #1942): one entry per scope a tag can apply
/// to, shared by migrations, the tag repository and sync.
void main() {
  test('TagScope follows the registry, in registry order', () {
    expect([for (final scope in TagScope.values) scope.table], tagScopeTables);
  });

  test('dives and sites keep their columns, tables and parent rule', () {
    expect(TagScope.dives.table, same(diveTagScopeTable));
    expect(diveTagScopeTable.scopeColumn, 'applies_to_dives');
    expect(diveTagScopeTable.junctionTable, 'dive_tags');
    expect(diveTagScopeTable.parentColumn, 'dive_id');
    expect(diveTagScopeTable.syncEntity, 'diveTags');
    expect(diveTagScopeTable.restampedParentTable, 'dives');
    expect(
      diveTagScopeTable.sweepsOrphanLinks,
      isFalse,
      reason: 'an orphaned dive link survives the repair (v149)',
    );

    expect(TagScope.sites.table, same(siteTagScopeTable));
    expect(siteTagScopeTable.scopeColumn, 'applies_to_sites');
    expect(siteTagScopeTable.junctionTable, 'site_tags');
    expect(siteTagScopeTable.parentColumn, 'site_id');
    expect(siteTagScopeTable.syncEntity, 'siteTags');
    expect(
      siteTagScopeTable.restampedParentTable,
      isNull,
      reason: 'site links are clockless children (#1769)',
    );
    expect(
      siteTagScopeTable.sweepsOrphanLinks,
      isTrue,
      reason: 'the repair has always swept orphaned site links (#1849)',
    );
  });

  test('no two scopes share a column, a junction or a sync entity', () {
    final columns = tagScopeTables.map((t) => t.scopeColumn).toList();
    final junctions = tagScopeTables.map((t) => t.junctionTable).toList();
    final entities = tagScopeTables.map((t) => t.syncEntity).toList();
    expect(columns.toSet(), hasLength(columns.length));
    expect(junctions.toSet(), hasLength(junctions.length));
    expect(entities.toSet(), hasLength(entities.length));
  });

  test('every registry entry names real schema', () async {
    final db = AppDatabase(NativeDatabase.memory());
    addTearDown(db.close);

    Future<Set<String>> columnsOf(String table) async => {
      for (final column
          in await db.customSelect("PRAGMA table_info('$table')").get())
        column.read<String>('name'),
    };

    final tagColumns = await columnsOf('tags');
    for (final entry in tagScopeTables) {
      expect(tagColumns, contains(entry.scopeColumn));
      expect(
        await columnsOf(entry.junctionTable),
        containsAll(['id', entry.parentColumn, 'tag_id', 'created_at', 'hlc']),
      );
      expect(
        db.allTables.map((t) => t.actualTableName),
        contains(entry.junctionTable),
        reason: 'registry-driven writes look the Drift table up by name',
      );
    }
  });

  test('a re-stamped parent is a synced entity of the same name', () {
    for (final entry in tagScopeTables) {
      final parent = entry.restampedParentTable;
      if (parent == null) continue;
      expect(SyncRepository.hlcTargets[parent]?.table, parent);
    }
  });
}
