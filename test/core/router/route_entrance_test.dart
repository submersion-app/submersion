import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:submersion/core/router/route_entrance.dart';

/// A page that shows whether its route's entrance has settled.
class _Probe extends StatefulWidget {
  const _Probe();

  @override
  State<_Probe> createState() => _ProbeState();
}

class _ProbeState extends State<_Probe> with RouteEntranceSettled<_Probe> {
  @override
  Widget build(BuildContext context) =>
      Text(isRouteEntranceSettled ? 'SETTLED' : 'ENTERING');
}

void main() {
  testWidgets('a page that is the initial route is settled at once', (
    tester,
  ) async {
    await tester.pumpWidget(const MaterialApp(home: _Probe()));

    expect(find.text('SETTLED'), findsOneWidget);
  });

  testWidgets('a pushed page is entering while its slide starts', (
    tester,
  ) async {
    final navigator = GlobalKey<NavigatorState>();
    await tester.pumpWidget(
      MaterialApp(navigatorKey: navigator, home: const Text('HOME')),
    );

    navigator.currentState!.push(
      MaterialPageRoute<void>(builder: (_) => const _Probe()),
    );
    // The app's hero controller builds the pushed route offstage for its
    // first frame, with an animation that reads complete. That frame is
    // still part of the entrance.
    await tester.pump();
    expect(find.text('ENTERING', skipOffstage: false), findsOneWidget);
    expect(find.text('SETTLED', skipOffstage: false), findsNothing);

    await tester.pump(const Duration(milliseconds: 100));
    expect(find.text('ENTERING'), findsOneWidget);

    await tester.pumpAndSettle();
    expect(find.text('SETTLED'), findsOneWidget);
  });

  testWidgets('a pushed page settles halfway through its slide', (
    tester,
  ) async {
    final navigator = GlobalKey<NavigatorState>();
    late Animation<double> entrance;
    await tester.pumpWidget(
      MaterialApp(navigatorKey: navigator, home: const Text('HOME')),
    );
    navigator.currentState!.push(
      PageRouteBuilder<void>(
        transitionDuration: const Duration(milliseconds: 400),
        pageBuilder: (_, animation, _) {
          entrance = animation;
          return const _Probe();
        },
      ),
    );
    await tester.pump();

    // A quarter of the way through its time: still on the move.
    await tester.pump(const Duration(milliseconds: 100));
    expect(find.text('ENTERING'), findsOneWidget);

    // Past halfway the slide's curves have the page all but across, so the
    // page builds the rest while the slide finishes.
    await tester.pump(const Duration(milliseconds: 120));
    expect(entrance.status, AnimationStatus.forward);
    expect(find.text('SETTLED'), findsOneWidget);
  });

  testWidgets('a page pushed without a transition is settled at once', (
    tester,
  ) async {
    final navigator = GlobalKey<NavigatorState>();
    await tester.pumpWidget(
      MaterialApp(navigatorKey: navigator, home: const Text('HOME')),
    );

    navigator.currentState!.push(
      PageRouteBuilder<void>(
        transitionDuration: Duration.zero,
        reverseTransitionDuration: Duration.zero,
        pageBuilder: (_, _, _) => const _Probe(),
      ),
    );
    await tester.pump();

    expect(find.text('SETTLED'), findsOneWidget);
  });

  testWidgets('a settled page stays settled while it slides out', (
    tester,
  ) async {
    final navigator = GlobalKey<NavigatorState>();
    await tester.pumpWidget(
      MaterialApp(navigatorKey: navigator, home: const Text('HOME')),
    );
    navigator.currentState!.push(
      MaterialPageRoute<void>(builder: (_) => const _Probe()),
    );
    await tester.pumpAndSettle();
    expect(find.text('SETTLED'), findsOneWidget);

    navigator.currentState!.pop();
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 100));

    expect(find.text('SETTLED'), findsOneWidget);
    expect(find.text('ENTERING'), findsNothing);
  });

  testWidgets('a page popped before it arrives never settles on the way out', (
    tester,
  ) async {
    final navigator = GlobalKey<NavigatorState>();
    await tester.pumpWidget(
      MaterialApp(navigatorKey: navigator, home: const Text('HOME')),
    );
    navigator.currentState!.push(
      MaterialPageRoute<void>(builder: (_) => const _Probe()),
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 100));
    expect(find.text('ENTERING'), findsOneWidget);

    navigator.currentState!.pop();
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 50));

    expect(find.text('ENTERING'), findsOneWidget);
    expect(find.text('SETTLED'), findsNothing);
  });

  testWidgets('a page outside any route counts as settled', (tester) async {
    await tester.pumpWidget(
      const Directionality(textDirection: TextDirection.ltr, child: _Probe()),
    );

    expect(find.text('SETTLED'), findsOneWidget);
  });
}
