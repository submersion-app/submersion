import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/features/dive_log/domain/entities/dive_summary.dart';
import 'package:submersion/features/trim_calculator/presentation/providers/trim_calculator_providers.dart';

/// Which dive the trim calculator opens on (issue #5028).
void main() {
  final when = DateTime.utc(2026, 11, 22);
  DiveSummary summary(
    String id, {
    bool planned = false,
    bool openDraft = false,
  }) => DiveSummary(
    id: id,
    dateTime: when,
    sortTimestamp: when.millisecondsSinceEpoch,
    isPlanned: planned,
    isDraft: openDraft,
    isOpenDraft: openDraft,
  );

  test('skips plans and open drafts for the latest logged dive', () {
    expect(
      latestLoggedDiveId([
        summary('plan', planned: true),
        summary('open', openDraft: true),
        summary('logged'),
      ]),
      'logged',
    );
  });

  test('null when the log holds only plans', () {
    expect(latestLoggedDiveId([summary('plan', planned: true)]), isNull);
    expect(latestLoggedDiveId(const []), isNull);
  });

  test('pages past a run of plans to find the latest logged dive', () async {
    final after = <String?>[];
    final id = await findLatestLoggedDiveId((cursor) async {
      after.add(cursor?.id);
      final page = after.length - 1;
      if (page < 2) {
        return [
          for (var i = 0; i < kTrimLatestDiveScan; i++)
            summary('plan-$page-$i', planned: true),
        ];
      }
      return [summary('logged')];
    });
    expect(id, 'logged');
    // Each page reads on from the last row of the one before.
    expect(after, [null, 'plan-0-49', 'plan-1-49']);
  });

  test('stops at the end of the log', () async {
    final id = await findLatestLoggedDiveId(
      (cursor) async => cursor == null ? [summary('plan', planned: true)] : [],
    );
    expect(id, isNull);
  });

  test('the picker offers logged dives only', () {
    expect(
      loggedDives([
        summary('plan', planned: true),
        summary('open', openDraft: true),
        summary('logged'),
      ]).map((d) => d.id),
      ['logged'],
    );
  });
}
