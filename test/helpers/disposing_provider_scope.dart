import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// An [UncontrolledProviderScope] that disposes [container] when the tree
/// unmounts.
///
/// flutter_test unmounts the tree at the end of a `testWidgets` body, then
/// fails the test on any fake timer still pending, and only after that runs
/// `addTearDown`. A provider that holds itself for a while after its last
/// listener leaves (`retainUntilIdle`, #4254) starts that timer during the
/// unmount, so a container disposed in `addTearDown` is disposed too late to
/// cancel it. Flutter unmounts children before their ancestors, so disposing
/// here runs after every widget has let go and before the timer audit.
class DisposingProviderScope extends StatefulWidget {
  const DisposingProviderScope({
    super.key,
    required this.container,
    required this.child,
  });

  final ProviderContainer container;
  final Widget child;

  @override
  State<DisposingProviderScope> createState() => _DisposingProviderScopeState();
}

class _DisposingProviderScopeState extends State<DisposingProviderScope> {
  @override
  void didUpdateWidget(DisposingProviderScope oldWidget) {
    super.didUpdateWidget(oldWidget);
    // Only the container in place at unmount is disposed, so a replaced one
    // would keep its retention timers and fail the pending-timer audit with
    // an error naming a provider rather than this scope.
    assert(
      identical(oldWidget.container, widget.container),
      'DisposingProviderScope owns one container for its lifetime; give a '
      'new container its own scope (a new key) instead of swapping it.',
    );
  }

  @override
  void dispose() {
    widget.container.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => UncontrolledProviderScope(
    container: widget.container,
    child: widget.child,
  );
}
