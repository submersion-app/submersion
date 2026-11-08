import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:submersion/core/providers/provider.dart';
import 'package:submersion/features/dive_computer/data/services/reparse_batch_service.dart';
import 'package:submersion/features/dive_computer/presentation/helpers/reparse_selected_dives.dart';
import 'package:submersion/features/dive_computer/presentation/providers/reparse_batch_provider.dart';
import 'package:submersion/features/dive_computer/presentation/providers/reparse_providers.dart';
import 'package:submersion/features/settings/presentation/providers/settings_providers.dart';
import 'package:submersion/shared/selection/bulk_action.dart';

import '../../../../helpers/mock_providers.dart';
import '../../../../helpers/test_app.dart';

/// Treats [withData] as the dives holding raw data and records each run.
class _FakeBatch implements ReparseBatchService {
  _FakeBatch(this.withData);

  final Set<String> withData;
  final runs = <List<String>>[];

  @override
  Future<List<String>> withRawData(List<String> diveIds) async => [
    for (final id in diveIds)
      if (withData.contains(id)) id,
  ];

  @override
  Future<ReparseBatchResult> run(
    List<String> diveIds, {
    required RawDiveParseFn parseFn,
    String? computerId,
    void Function(int done, int total)? onProgress,
    bool Function()? isCancelled,
  }) async {
    runs.add(diveIds);
    return ReparseBatchResult(
      total: diveIds.length,
      succeeded: diveIds.length,
      skipped: 0,
      notProcessed: 0,
      profilesPreserved: 0,
      failures: const [],
    );
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

void main() {
  late _FakeBatch batch;
  BulkActionOutcome? outcome;

  Future<void> pumpAndInvoke(WidgetTester tester, List<String> selected) async {
    outcome = null;
    await tester.pumpWidget(
      testApp(
        locale: const Locale('en'),
        overrides: [
          settingsProvider.overrideWith((ref) => MockSettingsNotifier()),
          reparseBatchServiceProvider.overrideWithValue(batch),
          reparseParseFnProvider.overrideWithValue(
            (vendor, product, model, raw) => throw UnimplementedError(),
          ),
          reparseDiveLookupProvider.overrideWithValue((ids) async => []),
        ],
        child: Consumer(
          builder: (context, ref, _) => TextButton(
            onPressed: () async =>
                outcome = await reparseSelectedDives(context, ref, selected),
            child: const Text('Invoke'),
          ),
        ),
      ),
    );
    await tester.tap(find.text('Invoke'));
    await tester.pumpAndSettle();
  }

  testWidgets('a selection with no raw data says so and runs nothing', (
    tester,
  ) async {
    batch = _FakeBatch({});
    await pumpAndInvoke(tester, ['manual-1', 'manual-2']);

    expect(
      find.text('None of the selected dives have stored raw data to re-parse.'),
      findsOneWidget,
    );
    expect(find.byType(AlertDialog), findsNothing);
    expect(batch.runs, isEmpty);
    expect(outcome, BulkActionOutcome.cancelled);
  });

  testWidgets('confirms with the skipped count, then runs dives with data', (
    tester,
  ) async {
    batch = _FakeBatch({'d1', 'd3'});
    await pumpAndInvoke(tester, ['d1', 'd2', 'd3']);

    expect(find.text('Re-parse dives'), findsOneWidget);
    expect(find.textContaining('on 2 dives'), findsOneWidget);
    expect(
      find.text('Selected dives without raw data (skipped): 1'),
      findsOneWidget,
    );

    await tester.tap(find.widgetWithText(FilledButton, 'Re-parse'));
    await tester.pumpAndSettle();

    expect(batch.runs, [
      ['d1', 'd3'],
    ]);
    expect(find.text('Re-parse finished'), findsOneWidget);
    await tester.tap(find.widgetWithText(FilledButton, 'Done'));
    await tester.pumpAndSettle();
    expect(outcome, BulkActionOutcome.completed);
  });

  testWidgets('no skipped line when every selected dive has raw data', (
    tester,
  ) async {
    batch = _FakeBatch({'d1'});
    await pumpAndInvoke(tester, ['d1']);

    expect(find.textContaining('skipped'), findsNothing);
  });

  testWidgets('cancelling the confirmation runs nothing', (tester) async {
    batch = _FakeBatch({'d1'});
    await pumpAndInvoke(tester, ['d1']);

    await tester.tap(find.widgetWithText(TextButton, 'Cancel'));
    await tester.pumpAndSettle();

    expect(batch.runs, isEmpty);
    expect(outcome, BulkActionOutcome.cancelled);
  });
}
