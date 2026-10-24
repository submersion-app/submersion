import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:submersion/core/providers/provider.dart';
import 'package:submersion/shared/widgets/master_detail/list_position_restorer.dart';

final _source = StateProvider<int>((ref) => 0);

/// A list that restores through [ListPositionRestorer], counting attempts.
class _Harness extends ConsumerStatefulWidget {
  const _Harness({required this.results});

  /// What each attempt returns, in order; the last one repeats.
  final List<bool> results;

  @override
  ConsumerState<_Harness> createState() => _HarnessState();
}

class _HarnessState extends ConsumerState<_Harness> {
  final controller = ScrollController();
  late final ListPositionRestorer restorer;
  int attempts = 0;

  @override
  void initState() {
    super.initState();
    restorer = ListPositionRestorer(
      controller: controller,
      attempt: () {
        final result =
            widget.results[attempts.clamp(0, widget.results.length - 1)];
        attempts++;
        return result;
      },
    )..start(ref, _source);
  }

  @override
  void dispose() {
    restorer.dispose();
    controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => ListView.builder(
    controller: controller,
    itemCount: 100,
    itemBuilder: (_, i) => SizedBox(height: 50, child: Text('Row $i')),
  );
}

void main() {
  late ProviderContainer container;

  Future<_HarnessState> pump(WidgetTester tester, List<bool> results) async {
    container = ProviderContainer();
    addTearDown(container.dispose);
    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: MaterialApp(home: _Harness(results: results)),
      ),
    );
    await tester.pump();
    return tester.state<_HarnessState>(find.byType(_Harness));
  }

  Future<void> bump(WidgetTester tester) async {
    container.read(_source.notifier).state++;
    await tester.pump();
  }

  testWidgets('attempts once after the first frame', (tester) async {
    final state = await pump(tester, [true]);

    expect(state.attempts, 1);
    expect(state.restorer.isDone, isTrue);
  });

  testWidgets('retries on each source change until an attempt succeeds', (
    tester,
  ) async {
    final state = await pump(tester, [false, false, true]);
    expect(state.attempts, 1);

    await bump(tester);
    expect(state.attempts, 2);
    await bump(tester);
    expect(state.attempts, 3);
    expect(state.restorer.isDone, isTrue);

    await bump(tester);
    expect(state.attempts, 3);
  });

  testWidgets('a scroll by the diver abandons the restore', (tester) async {
    final state = await pump(tester, [false]);

    await tester.drag(find.byType(ListView), const Offset(0, -300));
    await tester.pumpAndSettle();
    expect(state.restorer.isDone, isTrue);

    await bump(tester);
    expect(state.attempts, 1);
  });

  testWidgets('a keyboard scroll abandons the restore too', (tester) async {
    final state = await pump(tester, [false]);

    // Page Down and the arrow keys scroll by animating, which leaves the
    // user scroll direction idle.
    unawaited(
      state.controller.animateTo(
        400,
        duration: const Duration(milliseconds: 200),
        curve: Curves.linear,
      ),
    );
    await tester.pumpAndSettle();
    expect(state.restorer.isDone, isTrue);
  });

  testWidgets('stops listening once the list is gone', (tester) async {
    final state = await pump(tester, [false]);
    final restorer = state.restorer;
    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: const MaterialApp(home: SizedBox()),
      ),
    );

    await bump(tester);
    expect(restorer.isDone, isTrue);
  });
}
