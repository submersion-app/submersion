import 'package:flutter/scheduler.dart';
import 'package:flutter/widgets.dart';

/// Hide requests for the app shell's own chrome: its navigation rail or
/// bottom bar, the update banner and the GPS-recording strip.
///
/// A page asks with any token it owns (its State is the usual one) and the
/// chrome stays hidden until every token is released, so two pages can never
/// cancel each other's request. The shell knows nothing about who asks.
class ShellChromeController extends ChangeNotifier {
  // Identity, not ==: two holders that happen to use equal tokens (the same
  // string, say) must still release independently.
  final Set<Object> _tokens = Set.identity();
  bool _disposed = false;

  bool get isHidden => _tokens.isNotEmpty;

  void requestHidden(Object token) {
    if (_disposed) return;
    final wasHidden = isHidden;
    if (_tokens.add(token) && !wasHidden) _notify();
  }

  void releaseHidden(Object token) {
    if (_disposed) return;
    if (_tokens.remove(token) && !isHidden) _notify();
  }

  /// Holders request from didChangeDependencies and release from dispose,
  /// both of which run while the tree is locked; a listener calling setState
  /// then would throw, so the notification waits for the end of the frame.
  void _notify() {
    final binding = SchedulerBinding.instance;
    if (binding.schedulerPhase == SchedulerPhase.persistentCallbacks) {
      binding.addPostFrameCallback((_) {
        if (!_disposed) notifyListeners();
      });
      return;
    }
    notifyListeners();
  }

  @override
  void dispose() {
    _disposed = true;
    super.dispose();
  }
}

/// Hands the shell's [ShellChromeController] to the page below it.
class ShellChromeScope extends InheritedWidget {
  const ShellChromeScope({
    super.key,
    required this.controller,
    required super.child,
  });

  final ShellChromeController controller;

  /// The nearest shell's controller, or null when the caller sits outside
  /// the shell (a route pushed on the root navigator, or a test pumping the
  /// page as home). Registers no dependency, so it is safe from
  /// didChangeDependencies and callbacks; cache the result for dispose.
  static ShellChromeController? maybeOf(BuildContext context) =>
      context.getInheritedWidgetOfExactType<ShellChromeScope>()?.controller;

  @override
  bool updateShouldNotify(ShellChromeScope oldWidget) =>
      controller != oldWidget.controller;
}
