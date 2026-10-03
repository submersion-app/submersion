import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as p;

import 'provider_tick_scanner.dart';

/// Guards the change-tick contract statically: no `Stream<void> watch*` tick
/// in lib/ may be built on a Drift query stream, which emits on subscribe and
/// loops any provider that feeds it to `Ref.invalidateSelfWhen` (#1175,
/// #2835). Unlike the "silence before a write" group in
/// `repository_tick_stream_test.dart`, this covers every tick without anyone
/// having to enroll it.
void main() {
  group('queryStreamTicks', () {
    test('flags a tick built on watchSingle', () {
      const source = '''
class R {
  Stream<void> watchChanges() {
    final count = countAll();
    return (_db.selectOnly(_db.t)..addColumns([count]))
        .watchSingle()
        .map((_) {});
  }
}
''';
      expect(queryStreamTicks(source), ['watchChanges']);
    });

    test('flags an expression-bodied tick built on watch', () {
      const source = '''
class R {
  Stream<void> watchThingsChanges() => _db.select(_db.t).watch().map((_) {});
}
''';
      expect(queryStreamTicks(source), ['watchThingsChanges']);
    });

    test('flags a tick that maps a same-file helper built on a query', () {
      const source = '''
class R {
  Stream<void> watchChanges() => _albumCount().map((_) {});

  Stream<int> _albumCount() =>
      (_db.selectOnly(_db.t)..addColumns([count])).watchSingle().map((r) => 0);
}
''';
      expect(queryStreamTicks(source), ['watchChanges']);
    });

    test('flags a tick that returns a field built on a query', () {
      const source = '''
class R {
  late final Stream<void> _changes = _db.select(_db.t).watch().map((_) {});

  Stream<void> watchChanges() => _changes;
}
''';
      expect(queryStreamTicks(source), ['watchChanges']);
    });

    test('passes a tick built on tableUpdates', () {
      const source = '''
class R {
  Stream<void> watchChanges() =>
      _db.tableUpdates(TableUpdateQuery.onTable(_db.t));
}
''';
      expect(queryStreamTicks(source), isEmpty);
    });

    test('ignores a Riverpod watch, whatever the ref is called', () {
      const source = '''
class N {
  Stream<void> watchScope() {
    final repo = _ref.watch(repoProvider);
    return repo.watchChanges();
  }
}

Stream<void> watchOther(Ref ref) => ref.watch(repoProvider).watchChanges();
''';
      expect(queryStreamTicks(source), isEmpty);
    });

    test('ignores a data stream, which is meant to deliver rows', () {
      const source = '''
class R {
  Stream<List<Row>> watchAll() => _db.select(_db.t).watch();
}
''';
      expect(queryStreamTicks(source), isEmpty);
    });
  });

  test('no change tick in lib/ is built on a query stream', () {
    final violations = <String>[];
    final files = Directory('lib')
        .listSync(recursive: true)
        .whereType<File>()
        .where((f) => f.path.endsWith('.dart') && !f.path.endsWith('.g.dart'));
    for (final file in files) {
      for (final name in queryStreamTicks(file.readAsStringSync())) {
        violations.add('${p.relative(file.path)}::$name');
      }
    }

    expect(
      violations,
      isEmpty,
      reason:
          'These change ticks are built on a Drift query stream, which emits '
          'on subscribe. Fed to Ref.invalidateSelfWhen, that rebuilds the '
          'provider forever (#1175, #2835). Build the tick on '
          'tableUpdates(TableUpdateQuery.onTable(...)) instead.',
    );
  });
}
