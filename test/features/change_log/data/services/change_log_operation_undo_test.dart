import 'package:flutter_test/flutter_test.dart';

import 'package:submersion/features/change_log/data/repositories/change_log_repository.dart';
import 'package:submersion/features/change_log/data/services/change_log_operation_undo.dart';

/// A change log that cannot settle, as with a locked database.
class _BrokenLog extends ChangeLogRepository {
  @override
  Future<void> settleAll({Duration budget = Duration.zero}) async =>
      throw StateError('database is locked');
}

/// The Undo every change log operation shares (issue #4393).
void main() {
  test('no operation means nothing to undo', () async {
    expect(await undoChangeLogOperation(null), isFalse);
  });

  test('a failure reports an incomplete undo instead of throwing', () async {
    expect(
      await undoChangeLogOperation('op-1', changeLog: _BrokenLog()),
      isFalse,
    );
  });
}
