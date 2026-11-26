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
}
