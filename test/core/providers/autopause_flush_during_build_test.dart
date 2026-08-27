// Guard test for the Riverpod behaviour the whole app depends on: flushing a
// stale provider from inside a widget build must not schedule a provider
// refresh, because that refresh calls setState() on UncontrolledProviderScope
// and Flutter forbids setState() during build.
//
// The failure this pins down (seen on the Home page, GaugeStrip watching
// dashboardGaugesProvider) needs three things to line up:
//
//   1. A Consumer goes off-screen, so Riverpod 3 auto-pause pauses its
//      subscriptions and the providers it watches become inactive.
//   2. Something invalidates one of those providers while it is inactive.
//      ProviderScheduler._performRefresh() only flushes elements that are
//      active, then clears its queue, so the element stays dirty forever.
//   3. A Consumer mounts (or rebuilds) and reads a descendant of that stale
//      element. ref.watch flushes it synchronously mid-build, the rebuilt
//      ancestor notifies the descendant, and the descendant calls
//      invalidateSelf() -> scheduleProviderRefresh() -> setState() during
//      build.
//
// Riverpod 3.4.0/3.4.2 fixed it by guarding invalidateSelf() with
// `!_isFlushing && isActive`. Riverpod 3.3.2 and earlier throw here.
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

// A new identity on every build, so a rebuild always notifies listeners.
final _upstreamProvider = Provider<Object>((ref) => Object());

final _downstreamProvider = Provider<Object>((ref) {
  ref.watch(_upstreamProvider);
  return Object();
});

class _Harness extends StatefulWidget {
  const _Harness();

  @override
  State<_Harness> createState() => _HarnessState();
}

class _HarnessState extends State<_Harness> {
  bool tickerEnabled = true;
  bool showSecondConsumer = false;

  /// Drives the consumer off-screen, pausing its subscriptions.
  void park() => setState(() => tickerEnabled = false);

  /// Mounts a second, live consumer on the stale provider chain.
  void addConsumer() => setState(() => showSecondConsumer = true);

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        // Parking this one pauses its subscriptions, which is what makes
        // both providers inactive.
        TickerMode(
          enabled: tickerEnabled,
          child: Consumer(
            builder: (context, ref, _) {
              ref.watch(_downstreamProvider);
              return const SizedBox(height: 1);
            },
          ),
        ),
        if (showSecondConsumer)
          Consumer(
            builder: (context, ref, _) {
              ref.watch(_downstreamProvider);
              return const SizedBox(height: 1);
            },
          ),
      ],
    );
  }
}

void main() {
  testWidgets('flushing a provider invalidated while paused does not setState '
      'during build', (tester) async {
    final container = ProviderContainer();
    addTearDown(container.dispose);

    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: const MaterialApp(home: Scaffold(body: _Harness())),
      ),
    );

    final state = tester.state<_HarnessState>(find.byType(_Harness));

    // 1. Park the only consumer: both providers go inactive.
    state.park();
    await tester.pump();

    // 2. Invalidate the upstream provider while it is inactive. The
    //    scheduler queues it, skips it because it is not active, then
    //    drops the queue.
    container.invalidate(_upstreamProvider);
    await tester.pump();

    // 3. Mount a live consumer that reads the stale chain during build.
    state.addConsumer();
    await tester.pump();

    expect(tester.takeException(), isNull);
  });
}
