import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as p;

import 'package:submersion/core/services/sync/sync_data_serializer.dart';

import 'child_clock_scanner.dart';

/// Guards the rule that an UPDATE of an existing parent-gated child row
/// restamps the row's clock (issue #2644).
///
/// Since #2644 a peer's copy of a child whose clock is strictly newer writes
/// its explicit nulls. A value set here without a fresh clock can therefore
/// be cleared by the next such copy, still lacking it; and a null set here
/// never reaches a peer at all, since every copy of the row ties.
///
/// The sync layer is left out (it applies peers' rows under their own
/// clocks), and so is `lib/core/database`, whose migrations and open-time
/// backstops run the same way on every device.
void main() {
  bool under(File f, List<String> parts) =>
      p.isWithin(p.joinAll(parts), f.path);

  final dartFiles = Directory('lib')
      .listSync(recursive: true)
      .whereType<File>()
      .where((f) => f.path.endsWith('.dart') && !f.path.endsWith('.g.dart'))
      .where(
        (f) =>
            !under(f, ['lib', 'core', 'services', 'sync']) &&
            !under(f, ['lib', 'core', 'database']),
      )
      .toList();

  final result = scanChildWrites(
    files: dartFiles,
    tables: SyncDataSerializer.parentGatedTables,
    relativize: (path) => p.relative(path),
  );

  test('every parent-gated entity type is also its Drift getter', () {
    // The scan recognizes a Drift update by the getter inside update(...),
    // so a type whose getter differs would never be checked.
    final generated = File(
      p.join('lib', 'core', 'database', 'database.g.dart'),
    ).readAsStringSync();
    for (final type in SyncDataSerializer.parentGatedTables.keys) {
      expect(
        RegExp('Table\\s+$type\\s*=').hasMatch(generated),
        isTrue,
        reason: 'no Drift getter named $type',
      );
    }
  });

  test('the scan found child writes, so it cannot pass vacuously', () {
    expect(dartFiles.length, greaterThan(1000));
    expect(result.childWrites, greaterThanOrEqualTo(30));
  });

  test('every update of a parent-gated child restamps it', () {
    expect(
      result.violations,
      isEmpty,
      reason:
          'Each write below updates an existing parent-gated child row and '
          'leaves its clock where it was, so a peer\'s newer copy can clear '
          'the value, and a null written here never reaches a peer.\n\n'
          'Fix by stamping the row in the same write:\n'
          '  hlc: Value(await syncRepository.issueRowClock())\n'
          '(or `hlc = ?` in raw SQL), or by marking the same child pending in '
          'the same member:\n'
          '  markRecordPending(entityType: \'<type>\', recordId: id, ...)\n'
          'Mark the child, never only its parent dive (#1769).\n\n'
          'If the row is stamped somewhere this scan cannot see, say where:\n'
          '  // child-clock: <where the row is stamped>\n\n'
          '${result.violations.join('\n')}',
    );
  });
}
