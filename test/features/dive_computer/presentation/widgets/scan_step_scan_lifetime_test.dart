import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'scan_step_test_support.dart';

class _StopCountingNotifier extends TestDiscoveryNotifier {
  int stops = 0;

  @override
  Future<void> stopScanOwnedBy(Object? owner) async => stops++;
}

void main() {
  testWidgets('leaving the step leaves the scan running: the wizard moves '
      'past it to connect, which needs that on Android (issue #3369)', (
    tester,
  ) async {
    final notifier = _StopCountingNotifier();
    await tester.pumpWidget(
      buildScanStepTestWidget(discoveryNotifier: () => notifier),
    );
    await tester.pump();

    await tester.pumpWidget(const SizedBox());
    await tester.pump();

    expect(notifier.stops, 0);
  });
}
