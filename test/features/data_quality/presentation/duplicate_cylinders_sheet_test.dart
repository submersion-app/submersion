import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:submersion/features/data_quality/data/services/duplicate_cylinder_service.dart';
import 'package:submersion/features/data_quality/presentation/widgets/duplicate_cylinders_sheet.dart';

import '../../../helpers/test_app.dart';

const _preview = CylinderMergePreview(
  diveId: 'd1',
  survivorId: 'a',
  duplicateIds: ['b'],
  cylinders: [
    CylinderSummary(id: 'a', order: 0, name: null, o2: 32, he: 0),
    CylinderSummary(id: 'b', order: 2, name: null, o2: 32, he: 0),
  ],
  findingIds: ['f1'],
);

/// The bulk duplicate cylinder sheet (issue #4393).
void main() {
  testWidgets('the sheet cannot be dismissed while the run is going', (
    tester,
  ) async {
    final gate = Completer<DuplicateRemovalResult>();
    DuplicateRemovalResult? result;
    var closed = false;
    await tester.pumpWidget(
      testApp(
        locale: const Locale('en'),
        child: Builder(
          builder: (context) => TextButton(
            onPressed: () async {
              result = await showDuplicateCylindersSheet(
                context,
                previews: const [_preview],
                identityOf: (_) => null,
                run: (onProgress) => gate.future,
              );
              closed = true;
            },
            child: const Text('open'),
          ),
        ),
      ),
    );
    await tester.tap(find.text('open'));
    await tester.pumpAndSettle();

    await tester.tap(find.text('Remove'));
    await tester.pump();
    // A tap on the barrier and a Back would both close an idle sheet.
    await tester.tapAt(const Offset(10, 10));
    await tester.pump();
    final navigator = tester.state<NavigatorState>(find.byType(Navigator));
    await navigator.maybePop();
    await tester.pump();

    expect(closed, isFalse);
    expect(find.byType(LinearProgressIndicator), findsOneWidget);

    gate.complete(
      const DuplicateRemovalResult(
        merged: 1,
        skippedMixes: 0,
        failed: 0,
        operationId: 'op',
      ),
    );
    await tester.pumpAndSettle();
    expect(closed, isTrue);
    expect(result?.merged, 1);
  });

  testWidgets('a run that throws closes the sheet and reports the failure', (
    tester,
  ) async {
    DuplicateRemovalResult? result;
    var closed = false;
    await tester.pumpWidget(
      testApp(
        locale: const Locale('en'),
        child: Builder(
          builder: (context) => TextButton(
            onPressed: () async {
              result = await showDuplicateCylindersSheet(
                context,
                previews: const [_preview],
                identityOf: (_) => null,
                run: (onProgress) async => throw StateError('disk full'),
              );
              closed = true;
            },
            child: const Text('open'),
          ),
        ),
      ),
    );
    await tester.tap(find.text('open'));
    await tester.pumpAndSettle();

    await tester.tap(find.text('Remove'));
    await tester.pumpAndSettle();

    expect(closed, isTrue);
    expect(result?.merged, 0);
    expect(result?.failed, 1);
  });
}
