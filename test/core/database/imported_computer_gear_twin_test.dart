import 'dart:io';

import 'package:drift/drift.dart' hide isNull;
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:submersion/core/database/database.dart';
import 'package:submersion/core/database/dive_computer_gear_identity.dart';

/// The #1288 self-heal registers computers named by file-imported dives with a
/// raw INSERT OR IGNORE, bypassing createComputer and therefore the gear-twin
/// hook there. It needs its own mint, and that mint must fire ONLY where the
/// computer row was genuinely inserted: otherwise a user who deleted the gear
/// item would get it back on the next app open.
void main() {
  late Directory tempDir;
  late File dbFile;

  setUp(() async {
    // A file-backed database, because the heal runs in beforeOpen and this
    // needs several opens of the same data. An in-memory database cannot be
    // reopened and would lose its rows anyway.
    tempDir = await Directory.systemTemp.createTemp('gear_twin_heal_');
    dbFile = File('${tempDir.path}/test.db');
  });
  tearDown(() async {
    if (await tempDir.exists()) await tempDir.delete(recursive: true);
  });

  test('the heal mints a twin and does not re-mint a deleted one', () async {
    final t = DateTime.now().millisecondsSinceEpoch;

    // Open once to create the schema, and seed a file-imported dive that names
    // a computer with no registry row behind it.
    final first = AppDatabase(NativeDatabase(dbFile));
    await first.customStatement(
      'INSERT INTO dives (id, dive_computer_model, dive_date_time, '
      'created_at, updated_at) '
      "VALUES ('dive1', 'Perdix 2', 1, ?, ?)",
      [t, t],
    );
    await first.close();

    // Reopen: beforeOpen runs the heal against that dive.
    final second = AppDatabase(NativeDatabase(dbFile));
    final registered = await second
        .customSelect('SELECT id, equipment_id FROM dive_computers')
        .get();
    expect(registered, hasLength(1));
    final computerId = registered.single.read<String>('id');
    final twinId = registered.single.read<String?>('equipment_id');
    expect(twinId, diveComputerGearId(computerId));

    final gear = await second
        .customSelect(
          'SELECT type FROM equipment WHERE id = ?',
          variables: [Variable<String>(twinId!)],
        )
        .getSingle();
    expect(gear.read<String>('type'), 'computer');

    // The user deletes the gear item. The FK's setNull clears the link.
    await second.customStatement('DELETE FROM equipment WHERE id = ?', [
      twinId,
    ]);
    await second.close();

    // Reopen: the heal must NOT resurrect it. The computer row already exists,
    // so INSERT OR IGNORE changes nothing and the mint is never reached.
    final third = AppDatabase(NativeDatabase(dbFile));
    addTearDown(third.close);
    final after = await third
        .customSelect('SELECT COUNT(*) AS c FROM equipment')
        .getSingle();
    expect(after.read<int>('c'), 0);
  });
}
