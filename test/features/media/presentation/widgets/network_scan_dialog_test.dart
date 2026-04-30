// Widget tests for the Network scan progress dialog (Phase 3c, Task 9).
//
// Adapted from plan
// `docs/superpowers/plans/2026-04-28-media-source-extension-phase3c.md`
// Task 9. The hand-rolled `_FakeScan` mirrors the pattern in
// Tasks 6/7/8: implementing `NetworkScanService` directly is supported
// because the only public surface used by the dialog is `scanAll()` and
// `lastReport`.
import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:submersion/features/media/data/services/network_scan_service.dart';
import 'package:submersion/features/media/domain/value_objects/network_scan_progress.dart';
import 'package:submersion/features/media/presentation/providers/network_sources_providers.dart';
import 'package:submersion/features/media/presentation/widgets/network_scan_dialog.dart';

class _FakeScan implements NetworkScanService {
  _FakeScan(this.events);
  final List<NetworkScanProgress> events;
  NetworkScanReport? _report;
  @override
  NetworkScanReport? get lastReport => _report;
  @override
  Stream<NetworkScanProgress> scanAll() async* {
    for (final e in events) {
      await Future<void>.delayed(const Duration(milliseconds: 1));
      if (e.phase == NetworkScanPhase.finished) {
        _report = NetworkScanReport.fromProgress(
          e,
          skippedNoUrl: 0,
          durationMs: 100,
        );
      }
      yield e;
    }
  }

  @override
  dynamic noSuchMethod(Invocation invocation) =>
      throw UnimplementedError('${invocation.memberName} not stubbed');
}

void main() {
  testWidgets('shows progress and final summary', (tester) async {
    final fake = _FakeScan([
      NetworkScanProgress.starting(total: 2),
      const NetworkScanProgress(
        phase: NetworkScanPhase.scanning,
        total: 2,
        done: 1,
        available: 1,
        unreachable: 0,
      ),
      const NetworkScanProgress(
        phase: NetworkScanPhase.finished,
        total: 2,
        done: 2,
        available: 1,
        unreachable: 1,
      ),
    ]);

    await tester.pumpWidget(
      ProviderScope(
        overrides: [networkScanServiceProvider.overrideWithValue(fake)],
        child: const MaterialApp(home: Scaffold(body: _Launcher())),
      ),
    );

    await tester.tap(find.text('Open scan'));
    await tester.pumpAndSettle();

    expect(find.byType(NetworkScanDialog), findsOneWidget);
    // Drain stream events.
    await tester.pump(const Duration(milliseconds: 50));
    await tester.pumpAndSettle();

    // After `finished`, the dialog renders the summary line built from
    // `lastReport`, not the in-flight "X / Y items" running counter.
    expect(find.textContaining('Scanned 2 items'), findsOneWidget);
    expect(find.textContaining('1 reachable'), findsOneWidget);
    expect(find.textContaining('1 unreachable'), findsOneWidget);
    expect(find.text('Done'), findsOneWidget);
  });

  testWidgets('Cancel closes the dialog without waiting', (tester) async {
    final controller = StreamController<NetworkScanProgress>();
    final fake = _FakeScan(const []); // ignored — we override scanAll below.

    await tester.pumpWidget(
      ProviderScope(
        overrides: [networkScanServiceProvider.overrideWithValue(fake)],
        child: MaterialApp(
          home: Scaffold(
            body: Builder(
              builder: (context) {
                return Center(
                  child: ElevatedButton(
                    onPressed: () => showDialog<void>(
                      context: context,
                      barrierDismissible: false,
                      builder: (_) =>
                          NetworkScanDialog.test(stream: controller.stream),
                    ),
                    child: const Text('Open'),
                  ),
                );
              },
            ),
          ),
        ),
      ),
    );

    await tester.tap(find.text('Open'));
    await tester.pumpAndSettle();
    expect(find.byType(NetworkScanDialog), findsOneWidget);

    await tester.tap(find.text('Cancel'));
    await tester.pumpAndSettle();
    expect(find.byType(NetworkScanDialog), findsNothing);

    // Don't await — the dialog has already cancelled its subscription on
    // dispose; closing here is just hygiene and the await can deadlock
    // waiting for a subscription that's already gone.
    unawaited(controller.close());
  });
}

class _Launcher extends ConsumerWidget {
  const _Launcher();
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Center(
      child: ElevatedButton(
        onPressed: () => showDialog<void>(
          context: context,
          barrierDismissible: false,
          builder: (_) => const NetworkScanDialog(),
        ),
        child: const Text('Open scan'),
      ),
    );
  }
}
