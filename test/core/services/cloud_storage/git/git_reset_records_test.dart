import 'package:flutter_test/flutter_test.dart';

import 'package:submersion/core/services/cloud_storage/git/git_reset_records.dart';

void main() {
  late GitResetRecords records;

  setUp(() {
    records = GitResetRecords();
    addTearDown(records.dispose);
  });

  test('an endpoint with nothing recorded has no reset and no refusal', () {
    expect(records.statusFor('repo|main'), GitResetRecords.none);
  });

  test('a refusal is reported for its endpoint only', () async {
    final changed = <String>[];
    records.changes.listen(changed.add);

    records.noteRefused('repo|main', refused: true);
    await pumpEventQueue();

    expect(records.statusFor('repo|main').refused, isTrue);
    expect(records.statusFor('repo|other').refused, isFalse);
    expect(changed, ['repo|main']);
  });

  test('a reset is recorded and reported', () async {
    final changed = <String>[];
    records.changes.listen(changed.add);
    final at = DateTime.utc(2026, 10, 19);

    records.noteReset('repo|main', at);
    await pumpEventQueue();

    expect(records.statusFor('repo|main').lastResetAt, at);
    expect(changed, ['repo|main']);
  });

  test('recording what is already known reports nothing', () async {
    final at = DateTime.utc(2026, 10, 19);
    records.noteReset('repo|main', at);
    records.noteRefused('repo|main', refused: true);
    final changed = <String>[];
    records.changes.listen(changed.add);

    records.noteReset('repo|main', at);
    records.noteRefused('repo|main', refused: true);
    records.noteRefused('repo|other', refused: false);
    await pumpEventQueue();

    expect(changed, isEmpty);
  });

  test('a later successful reset clears the refusal', () async {
    records.noteRefused('repo|main', refused: true);
    final changed = <String>[];
    records.changes.listen(changed.add);

    records.noteRefused('repo|main', refused: false);
    await pumpEventQueue();

    expect(records.statusFor('repo|main').refused, isFalse);
    expect(changed, ['repo|main']);
  });

  test('recording after dispose keeps the outcome without throwing', () {
    records.dispose();

    records.noteRefused('repo|main', refused: true);
    records.noteReset('repo|main', DateTime.utc(2026, 10, 19));

    expect(records.statusFor('repo|main').refused, isTrue);
  });
}
