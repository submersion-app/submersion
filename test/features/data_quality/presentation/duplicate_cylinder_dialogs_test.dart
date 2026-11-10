import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:submersion/features/data_quality/data/services/duplicate_cylinder_service.dart';
import 'package:submersion/features/data_quality/presentation/widgets/duplicate_cylinder_dialogs.dart';
import 'package:submersion/l10n/arb/app_localizations.dart';

import '../../../helpers/test_app.dart';

typedef _Mix = ({double o2, double he});

/// The duplicate cylinder dialogs and summary (issue #4393).
void main() {
  final l10n = lookupAppLocalizations(const Locale('en'));

  DuplicateRemovalResult result({
    int merged = 0,
    int skippedMixes = 0,
    int failed = 0,
  }) => DuplicateRemovalResult(
    merged: merged,
    skippedMixes: skippedMixes,
    failed: failed,
    operationId: 'op',
  );

  test('a run that changed nothing has no summary', () {
    expect(duplicateRemovalSummary(l10n, result()), isNull);
  });

  test('the summary names merges, skips and failures', () {
    expect(
      duplicateRemovalSummary(
        l10n,
        result(merged: 2, skippedMixes: 1, failed: 1),
      ),
      'Removed on 2 dives. 1 skipped: gas mixes differ. 1 failed',
    );
  });

  testWidgets('the mix question always starts with the kept mix chosen', (
    tester,
  ) async {
    const preview = CylinderMergePreview(
      diveId: 'd1',
      survivorId: 'a',
      duplicateIds: ['b', 'c'],
      // b comes first in dive order and is within tolerance of the kept a.
      cylinders: [
        CylinderSummary(id: 'b', order: 0, name: null, o2: 32.04, he: 0),
        CylinderSummary(id: 'a', order: 1, name: null, o2: 32, he: 0),
        CylinderSummary(id: 'c', order: 2, name: null, o2: 21, he: 0),
      ],
      findingIds: ['f1'],
    );
    await tester.pumpWidget(
      testApp(
        locale: const Locale('en'),
        child: Builder(
          builder: (context) => TextButton(
            onPressed: () => confirmRemoveDuplicate(context, preview),
            child: const Text('open'),
          ),
        ),
      ),
    );
    await tester.tap(find.text('open'));
    await tester.pumpAndSettle();

    final group = tester.widget<RadioGroup<_Mix>>(
      find.byType(RadioGroup<_Mix>),
    );
    final values = [
      for (final tile in tester.widgetList<RadioListTile<_Mix>>(
        find.byType(RadioListTile<_Mix>),
      ))
        tile.value,
    ];
    expect(values, contains(group.groupValue));
  });
}
