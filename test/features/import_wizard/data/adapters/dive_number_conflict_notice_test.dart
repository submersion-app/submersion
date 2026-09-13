import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/features/dive_log/data/repositories/dive_repository_impl.dart';
import 'package:submersion/features/import_wizard/data/adapters/dive_number_conflict_notice.dart';
import 'package:submersion/features/import_wizard/domain/models/import_notice.dart';

class _CountingRepository extends Fake implements DiveRepository {
  _CountingRepository(this._answer);

  final Future<int> Function() _answer;
  final calls = <List<String>>[];

  @override
  Future<int> countDivesSharingDiveNumber(List<String> diveIds) {
    calls.add(diveIds);
    return _answer();
  }
}

void main() {
  group('diveNumberConflictNotice (issue #1832)', () {
    test('reports how many imported dives clash', () async {
      final repo = _CountingRepository(() async => 2);

      final notice = await diveNumberConflictNotice(
        retainSourceDiveNumbers: true,
        diveRepository: repo,
        importedDiveIds: const ['a', 'b'],
      );

      expect(notice?.kind, ImportNoticeKind.diveNumberConflict);
      expect(notice?.affectedDives, 2);
      expect(repo.calls, [
        ['a', 'b'],
      ]);
    });

    test('reports nothing when no dive clashes', () async {
      final notice = await diveNumberConflictNotice(
        retainSourceDiveNumbers: true,
        diveRepository: _CountingRepository(() async => 0),
        importedDiveIds: const ['a'],
      );

      expect(notice, isNull);
    });

    test(
      'does not query when auto-numbering or nothing was imported',
      () async {
        final repo = _CountingRepository(() async => 5);

        expect(
          await diveNumberConflictNotice(
            retainSourceDiveNumbers: false,
            diveRepository: repo,
            importedDiveIds: const ['a'],
          ),
          isNull,
        );
        expect(
          await diveNumberConflictNotice(
            retainSourceDiveNumbers: true,
            diveRepository: repo,
            importedDiveIds: const [],
          ),
          isNull,
        );
        expect(repo.calls, isEmpty);
      },
    );

    test(
      'a failed check never fails an import that already saved its dives',
      () async {
        final notice = await diveNumberConflictNotice(
          retainSourceDiveNumbers: true,
          diveRepository: _CountingRepository(
            () async => throw StateError('database is locked'),
          ),
          importedDiveIds: const ['a'],
        );

        expect(notice, isNull);
      },
    );
  });
}
