import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:submersion/core/services/cloud_storage/git/git_reset_records.dart';
import 'package:submersion/features/settings/presentation/providers/git_providers.dart';

void main() {
  late GitResetRecords records;
  late ProviderContainer container;

  setUp(() {
    records = GitResetRecords();
    container = ProviderContainer(
      overrides: [gitResetRecordsProvider.overrideWithValue(records)],
    );
    addTearDown(container.dispose);
    addTearDown(records.dispose);
  });

  test('gitResetStatusProvider starts from what is already recorded', () {
    records.noteRefused('repo|main', refused: true);

    expect(container.read(gitResetStatusProvider('repo|main')).refused, isTrue);
  });

  test('gitResetStatusProvider follows changes to its own endpoint', () async {
    final seen = <GitResetStatus>[];
    container.listen(
      gitResetStatusProvider('repo|main'),
      (_, next) => seen.add(next),
    );
    final at = DateTime.utc(2026, 10, 19);

    records.noteRefused('repo|other', refused: true);
    records.noteReset('repo|main', at);
    await pumpEventQueue();

    expect(seen, [(lastResetAt: at, refused: false)]);
  });
}
