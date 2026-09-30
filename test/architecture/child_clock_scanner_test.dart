import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as p;

import 'child_clock_scanner.dart';

/// Unit tests for the scanner that backs
/// `test/architecture/child_write_restamps_test.dart`.
///
/// Uses synthetic source in a temp directory rather than the real `lib/` tree,
/// so the accept/reject shapes stay pinned even as the codebase moves.
void main() {
  late Directory temp;

  setUp(() => temp = Directory.systemTemp.createTempSync('child_clock'));
  tearDown(() => temp.deleteSync(recursive: true));

  const tables = {'diveTanks': 'dive_tanks', 'diveEquipment': 'dive_equipment'};

  ChildWriteScan scan(String body) {
    final file = File(p.join(temp.path, 'writer.dart'))
      ..writeAsStringSync('class Writer {\n$body\n}\n');
    return scanChildWrites(
      files: [file],
      tables: tables,
      relativize: p.basename,
    );
  }

  test('an update that sets a child value without a clock is flagged', () {
    final result = scan('''
  Future<void> relink() async {
    await (_db.update(_db.diveTanks)..where((t) => t.id.equals('x')))
        .write(DiveTanksCompanion(computerId: Value('c')));
  }
''');
    expect(result.childWrites, 1);
    expect(result.violations.single.key, 'writer.dart::relink::diveTanks');
  });

  test('an hlc in the same companion restamps the row', () {
    final result = scan('''
  Future<void> relink() async {
    await (_db.update(_db.diveTanks)..where((t) => t.id.equals('x'))).write(
      DiveTanksCompanion(computerId: Value('c'), hlc: Value(await clock())),
    );
  }
''');
    expect(result.childWrites, 1);
    expect(result.violations, isEmpty);
  });

  test('marking the same child pending in the member restamps it', () {
    final result = scan('''
  Future<void> relink() async {
    await (_db.update(_db.diveTanks)..where((t) => t.id.equals('x')))
        .write(DiveTanksCompanion(computerId: Value('c')));
    await _sync.markRecordPending(
      entityType: 'diveTanks',
      recordId: 'x',
      localUpdatedAt: 1,
    );
  }
''');
    expect(result.violations, isEmpty);
  });

  test('marking only the parent pending does not count', () {
    final result = scan('''
  Future<void> relink() async {
    await (_db.update(_db.diveTanks)..where((t) => t.id.equals('x')))
        .write(DiveTanksCompanion(computerId: Value('c')));
    await _sync.markRecordPending(
      entityType: 'dives',
      recordId: 'd',
      localUpdatedAt: 1,
    );
  }
''');
    expect(result.violations, hasLength(1));
  });

  test('a marker with a reason accepts the write, an empty one does not', () {
    final marked = scan('''
  Future<void> relink() async {
    // child-clock: stamped by stage('diveTanks') in applyParsedUpdate
    await (_db.update(_db.diveTanks)..where((t) => t.id.equals('x')))
        .write(DiveTanksCompanion(computerId: Value('c')));
  }
''');
    expect(marked.violations, isEmpty);

    final empty = scan('''
  Future<void> relink() async {
    // child-clock:
    await (_db.update(_db.diveTanks)..where((t) => t.id.equals('x')))
        .write(DiveTanksCompanion(computerId: Value('c')));
  }
''');
    expect(empty.violations, hasLength(1));
  });

  test('a direct update chain and a replace are both writes', () {
    final result = scan('''
  Future<void> a() => _db.update(_db.diveTanks).write(DiveTanksCompanion());
  Future<void> b() => db.update(db.diveTanks).replace(row);
''');
    expect(result.childWrites, 2);
    expect(result.violations.map((v) => v.member), ['a', 'b']);
  });

  test('a batch update is checked on its companion', () {
    final result = scan('''
  Future<void> a() => _db.batch(
    (b) => b.update(_db.diveEquipment, DiveEquipmentCompanion(viaSetId: Value(null))),
  );
  Future<void> b() => _db.batch(
    (b) => b.update(
      _db.diveEquipment,
      DiveEquipmentCompanion(viaSetId: Value(null), hlc: Value(h)),
    ),
  );
''');
    expect(result.childWrites, 2);
    expect(result.violations.map((v) => v.member), ['a']);
  });

  test('raw SQL updating a child needs hlc in the same statement', () {
    final result = scan(r'''
  Future<void> a() => _db.customStatement(
    'UPDATE dive_tanks SET computer_id = ? WHERE id = ?',
    [c, id],
  );
  Future<void> b() => _db.customStatement(
    'UPDATE dive_tanks SET computer_id = ?, hlc = ? '
    'WHERE id IN ($ph)',
    [c, h, ...ids],
  );
  Future<void> c() => _db.customUpdate(
    'UPDATE "dive_equipment" SET via_set_id = NULL WHERE dive_id = ?',
    variables: [v],
  );
''');
    expect(result.childWrites, 3);
    expect(result.violations.map((v) => v.member), ['a', 'c']);
  });

  test('writes to other tables are not child writes', () {
    final result = scan('''
  Future<void> a() async {
    await (_db.update(_db.dives)..where((t) => t.id.equals('x')))
        .write(DivesCompanion(name: Value('n')));
    await _db.customStatement('UPDATE dives SET name = ?', ['n']);
    await _db.customStatement('UPDATE dive_tanks_backup SET a = 1');
  }
''');
    expect(result.childWrites, 0);
    expect(result.violations, isEmpty);
  });

  test('a write in a top-level function is keyed by that function', () {
    final file = File(p.join(temp.path, 'top.dart'))
      ..writeAsStringSync('''
Future<void> fill(AppDatabase db) =>
    db.update(db.diveTanks).write(DiveTanksCompanion(volume: Value(1)));
''');
    final result = scanChildWrites(
      files: [file],
      tables: tables,
      relativize: p.basename,
    );
    expect(result.violations.single.key, 'top.dart::fill::diveTanks');
  });
}
