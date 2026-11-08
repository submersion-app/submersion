import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';

import 'package:submersion/core/providers/provider.dart';
import 'package:submersion/features/dive_computer/data/services/reparse_batch_service.dart';
import 'package:submersion/features/dive_computer/presentation/providers/reparse_batch_provider.dart';
import 'package:submersion/features/dive_computer/presentation/providers/reparse_providers.dart';
import 'package:submersion/features/dive_computer/presentation/widgets/reparse_batch_dialog.dart';
import 'package:submersion/features/dive_log/domain/entities/dive.dart';
import 'package:submersion/features/settings/presentation/providers/settings_providers.dart';

import '../../../../helpers/mock_providers.dart';
import '../../../../helpers/test_app.dart';

/// Runs dive by dive, each dive waiting for its gate, so a test can stop the
/// run at any point.
class _GatedBatch implements ReparseBatchService {
  _GatedBatch(int count, {this.failing = const {}, this.errors = const {}})
    : gates = [for (var i = 0; i < count; i++) Completer<void>()];

  final List<Completer<void>> gates;
  final Set<String> failing;
  final Map<String, String> errors;
  String? computerId;

  void release(int index) => gates[index].complete();

  @override
  Future<ReparseBatchResult> run(
    List<String> diveIds, {
    required RawDiveParseFn parseFn,
    String? computerId,
    void Function(int done, int total)? onProgress,
    bool Function()? isCancelled,
  }) async {
    this.computerId = computerId;
    final failures = <ReparseDiveFailure>[];
    var notProcessed = 0;
    for (var i = 0; i < diveIds.length; i++) {
      if (isCancelled?.call() ?? false) {
        notProcessed = diveIds.length - i;
        break;
      }
      await gates[i].future;
      if (failing.contains(diveIds[i])) {
        failures.add(
          ReparseDiveFailure(
            diveId: diveIds[i],
            error: errors[diveIds[i]] ?? 'Exception: bad bytes',
          ),
        );
      }
      onProgress?.call(i + 1, diveIds.length);
    }
    final processed = diveIds.length - notProcessed;
    return ReparseBatchResult(
      total: diveIds.length,
      succeeded: processed - failures.length,
      skipped: 0,
      notProcessed: notProcessed,
      profilesPreserved: 0,
      failures: failures,
    );
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

/// A run that fails as a whole, before reaching any dive.
class _BrokenBatch extends _GatedBatch {
  _BrokenBatch() : super(0);

  @override
  Future<ReparseBatchResult> run(
    List<String> diveIds, {
    required RawDiveParseFn parseFn,
    String? computerId,
    void Function(int done, int total)? onProgress,
    bool Function()? isCancelled,
  }) async => throw StateError('database is closed');
}

void main() {
  late _GatedBatch batch;
  late List<Dive> knownDives;

  Future<void> pumpHost(WidgetTester tester, List<String> diveIds) async {
    final router = GoRouter(
      routes: [
        GoRoute(
          path: '/',
          builder: (context, state) => Scaffold(
            body: Consumer(
              builder: (context, ref, _) => TextButton(
                onPressed: () => runReparseBatch(context, ref, diveIds),
                child: const Text('Start'),
              ),
            ),
          ),
        ),
        GoRoute(
          path: '/dives/:id',
          builder: (context, state) =>
              Scaffold(body: Text('Dive page ${state.pathParameters['id']}')),
        ),
      ],
    );
    await tester.pumpWidget(
      testAppRouter(
        router: router,
        overrides: [
          settingsProvider.overrideWith((ref) => MockSettingsNotifier()),
          reparseBatchServiceProvider.overrideWithValue(batch),
          reparseParseFnProvider.overrideWithValue(
            (vendor, product, model, raw) => throw UnimplementedError(),
          ),
          reparseDiveLookupProvider.overrideWithValue(
            (ids) async => [
              for (final d in knownDives)
                if (ids.contains(d.id)) d,
            ],
          ),
        ],
      ),
    );
    await tester.tap(find.text('Start'));
    await tester.pump();
  }

  setUp(() => knownDives = const []);

  testWidgets('shows progress and count while running', (tester) async {
    batch = _GatedBatch(3);
    await pumpHost(tester, ['d1', 'd2', 'd3']);

    expect(find.text('Re-parsing dives'), findsOneWidget);
    expect(find.byType(LinearProgressIndicator), findsOneWidget);

    batch.release(0);
    await tester.pump();
    expect(find.text('Re-parsing 1 of 3 dives'), findsOneWidget);

    batch
      ..release(1)
      ..release(2);
    await tester.pumpAndSettle();
  });

  testWidgets('cancel disables the button and shows Cancelling', (
    tester,
  ) async {
    batch = _GatedBatch(3);
    await pumpHost(tester, ['d1', 'd2', 'd3']);

    await tester.tap(find.widgetWithText(TextButton, 'Cancel'));
    await tester.pump();

    final button = tester.widget<TextButton>(
      find.widgetWithText(TextButton, 'Cancelling...'),
    );
    expect(button.onPressed, isNull);

    batch.release(0);
    await tester.pumpAndSettle();
    expect(find.text('Re-parse cancelled'), findsOneWidget);
    expect(find.text('Not processed (cancelled): 2'), findsOneWidget);
  });

  testWidgets('cancel during the last dive still ends in results', (
    tester,
  ) async {
    batch = _GatedBatch(3);
    await pumpHost(tester, ['d1', 'd2', 'd3']);
    batch
      ..release(0)
      ..release(1);
    await tester.pump();

    await tester.tap(find.widgetWithText(TextButton, 'Cancel'));
    await tester.pump();
    batch.release(2);
    await tester.pumpAndSettle();

    expect(find.text('Re-parse finished'), findsOneWidget);
    expect(find.text('Re-parsed 3 of 3 dives.'), findsOneWidget);
    expect(find.textContaining('Not processed'), findsNothing);
  });

  testWidgets('results list failed dives and tapping one opens the dive', (
    tester,
  ) async {
    batch = _GatedBatch(2, failing: {'d2'});
    knownDives = [
      Dive(id: 'd2', diveNumber: 12, dateTime: DateTime.utc(2026, 5, 3, 9)),
    ];
    await pumpHost(tester, ['d1', 'd2']);
    batch
      ..release(0)
      ..release(1);
    await tester.pumpAndSettle();

    expect(find.text('Re-parsed 1 of 2 dives.'), findsOneWidget);
    expect(find.text('Failed: 1'), findsOneWidget);
    expect(find.text('Failed dives'), findsOneWidget);
    expect(find.text('Dive #12'), findsOneWidget);
    expect(find.textContaining('bad bytes'), findsOneWidget);

    await tester.tap(find.text('Dive #12'));
    await tester.pumpAndSettle();

    expect(find.text('Dive page d2'), findsOneWidget);
    expect(find.text('Re-parse finished'), findsNothing);
  });

  testWidgets('a failed dive missing from the log renders without details', (
    tester,
  ) async {
    batch = _GatedBatch(1, failing: {'gone'});
    await pumpHost(tester, ['gone']);
    batch.release(0);
    await tester.pumpAndSettle();

    expect(find.text('Unnumbered dive'), findsOneWidget);
    expect(find.textContaining('--'), findsOneWidget);
  });

  testWidgets('missing descriptors show the translated message', (
    tester,
  ) async {
    batch = _GatedBatch(
      1,
      failing: {'d1'},
      errors: {'d1': missingDescriptorsError},
    );
    await pumpHost(tester, ['d1']);
    batch.release(0);
    await tester.pumpAndSettle();

    expect(find.textContaining('Missing dive computer details'), findsOne);
  });

  testWidgets('back does not close the dialog while running', (tester) async {
    batch = _GatedBatch(2);
    await pumpHost(tester, ['d1', 'd2']);

    await tester.binding.handlePopRoute();
    await tester.pump();
    expect(find.text('Re-parsing dives'), findsOneWidget);

    batch
      ..release(0)
      ..release(1);
    await tester.pumpAndSettle();
    await tester.tap(find.widgetWithText(FilledButton, 'Done'));
    await tester.pumpAndSettle();
    expect(find.text('Re-parse finished'), findsNothing);
  });

  testWidgets('a run that fails as a whole still ends in results', (
    tester,
  ) async {
    batch = _BrokenBatch();
    await pumpHost(tester, ['d1', 'd2']);
    await tester.pumpAndSettle();

    // Not a cancellation: the diver never pressed Cancel.
    expect(find.text('Re-parse stopped by an error'), findsOneWidget);
    expect(find.text('Re-parse cancelled'), findsNothing);
    expect(find.textContaining('database is closed'), findsOneWidget);
    expect(find.text('Not processed: 2'), findsOneWidget);
    expect(find.textContaining('(cancelled)'), findsNothing);
    expect(find.textContaining('Re-parsed'), findsNothing);

    await tester.tap(find.widgetWithText(FilledButton, 'Done'));
    await tester.pumpAndSettle();
    expect(find.byType(AlertDialog), findsNothing);
  });
}
