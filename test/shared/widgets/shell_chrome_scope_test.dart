import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:submersion/shared/widgets/shell_chrome_scope.dart';

/// Requests a hidden shell for as long as it is mounted: from initState and
/// dispose, which both run while the tree is locked.
class _Holder extends StatefulWidget {
  const _Holder();

  @override
  State<_Holder> createState() => _HolderState();
}

class _HolderState extends State<_Holder> {
  ShellChromeController? _controller;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _controller = ShellChromeScope.maybeOf(context);
    _controller?.requestHidden(this);
  }

  @override
  void dispose() {
    _controller?.releaseHidden(this);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => const SizedBox();
}

/// Rebuilds on every controller change and reports the state as text.
class _Host extends StatefulWidget {
  const _Host({required this.controller, required this.child});

  final ShellChromeController controller;
  final Widget child;

  @override
  State<_Host> createState() => _HostState();
}

class _HostState extends State<_Host> {
  void _changed() => setState(() {});

  @override
  void initState() {
    super.initState();
    widget.controller.addListener(_changed);
  }

  @override
  void dispose() {
    widget.controller.removeListener(_changed);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => ShellChromeScope(
    controller: widget.controller,
    child: Column(
      children: [
        Text(widget.controller.isHidden ? 'hidden' : 'shown'),
        widget.child,
      ],
    ),
  );
}

/// Every instance equals every other, the way two holders using the same
/// string or value object as a token would.
class _EqualToken {
  @override
  bool operator ==(Object other) => other is _EqualToken;

  @override
  int get hashCode => 0;
}

void main() {
  late ShellChromeController controller;

  setUp(() => controller = ShellChromeController());
  tearDown(() => controller.dispose());

  Widget app(Widget child) => MaterialApp(
    home: Scaffold(
      body: _Host(controller: controller, child: child),
    ),
  );

  testWidgets('a request hides and its release restores', (tester) async {
    await tester.pumpWidget(app(const SizedBox()));
    expect(find.text('shown'), findsOneWidget);

    final token = Object();
    controller.requestHidden(token);
    await tester.pump();
    expect(find.text('hidden'), findsOneWidget);

    controller.releaseHidden(token);
    await tester.pump();
    expect(find.text('shown'), findsOneWidget);
  });

  testWidgets('two holders do not release each other', (tester) async {
    await tester.pumpWidget(app(const SizedBox()));
    final a = Object();
    final b = Object();
    controller
      ..requestHidden(a)
      ..requestHidden(b);
    await tester.pump();

    controller.releaseHidden(a);
    await tester.pump();
    expect(find.text('hidden'), findsOneWidget);

    controller.releaseHidden(b);
    await tester.pump();
    expect(find.text('shown'), findsOneWidget);
  });

  testWidgets('equal but distinct tokens are still separate holders', (
    tester,
  ) async {
    await tester.pumpWidget(app(const SizedBox()));
    final a = _EqualToken();
    final b = _EqualToken();
    controller
      ..requestHidden(a)
      ..requestHidden(b);
    await tester.pump();

    controller.releaseHidden(a);
    await tester.pump();
    expect(find.text('hidden'), findsOneWidget);
  });

  testWidgets('releasing a token that was never requested is a no-op', (
    tester,
  ) async {
    await tester.pumpWidget(app(const SizedBox()));
    final held = Object();
    controller.requestHidden(held);
    await tester.pump();

    controller.releaseHidden(Object());
    await tester.pump();
    expect(find.text('hidden'), findsOneWidget);
  });

  testWidgets('requests made while the tree is locked apply after the frame', (
    tester,
  ) async {
    await tester.pumpWidget(app(const _Holder()));
    await tester.pump();
    expect(find.text('hidden'), findsOneWidget);
    expect(tester.takeException(), isNull);

    await tester.pumpWidget(app(const SizedBox()));
    await tester.pump();
    expect(find.text('shown'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('maybeOf is null outside a scope', (tester) async {
    ShellChromeController? found = controller;
    await tester.pumpWidget(
      MaterialApp(
        home: Builder(
          builder: (context) {
            found = ShellChromeScope.maybeOf(context);
            return const SizedBox();
          },
        ),
      ),
    );
    expect(found, isNull);
  });

  test('calls after dispose are ignored', () {
    final disposed = ShellChromeController()..dispose();
    expect(() => disposed.releaseHidden(Object()), returnsNormally);
    expect(() => disposed.requestHidden(Object()), returnsNormally);
  });
}
