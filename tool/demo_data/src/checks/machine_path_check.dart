import 'dart:io';

import 'package:drift/drift.dart' show DriftSqlType, Variable;
import 'package:path/path.dart' as p;
import 'package:submersion/core/database/database.dart';

/// No value in the published logbook may name a folder on the machine that
/// built it (issue #3708): such a path carries the builder's user name and
/// folder layout into a public file. Photo paths are written relative to the
/// package and relinked on the device that opens it.
class MachinePathCheck {
  MachinePathCheck._();

  /// The text columns, as `table.column`, holding a value that contains one
  /// of [folders] or the current user's home folder.
  static Future<List<String>> run(
    AppDatabase db,
    Iterable<String> folders,
  ) async {
    final home =
        Platform.environment['HOME'] ?? Platform.environment['USERPROFILE'];
    final needles = {
      for (final f in [...folders, ?home])
        if (f.isNotEmpty) p.normalize(p.absolute(f)),
    };
    final found = <String>[];
    for (final t in db.allTables) {
      for (final c in t.$columns) {
        if (c.type != DriftSqlType.string) continue;
        for (final needle in needles) {
          final hit = await db
              .customSelect(
                'SELECT 1 FROM "${t.actualTableName}" '
                'WHERE instr("${c.name}", ?) > 0 LIMIT 1',
                variables: [Variable.withString(needle)],
              )
              .getSingleOrNull();
          if (hit != null) {
            found.add('${t.actualTableName}.${c.name}');
            break;
          }
        }
      }
    }
    return found;
  }
}
