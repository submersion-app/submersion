import 'dart:async';

import 'package:clock/clock.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';

/// The shared slow clock behind every summary-pane scene.
///
/// Publishes elapsed seconds to [builder] a few times a second from a
/// periodic timer rather than a vsync ticker, so an idle app is not asked
/// for a frame on every display refresh (compare #3044 on the ocean hero).
///
/// It runs only while the scene can be seen and motion is wanted: the app
/// is resumed (a null lifecycle state counts as resumed), the route's
/// tickers are enabled, and reduce motion is off. Otherwise it stops and the
/// scene keeps its last frame, resuming from where it stopped. Under reduce
/// motion it publishes [stillSeconds] once and never changes.
class SceneClock extends StatefulWidget {
  const SceneClock({
    super.key,
    required this.builder,
    this.framesPerSecond = 24,
  });

  /// Builds the scene for the current clock value, in seconds.
  final Widget Function(BuildContext context, double seconds) builder;

  /// How often the clock publishes a new value while it runs.
  final int framesPerSecond;

  /// The clock value a scene shows under reduce motion: far enough in that
  /// every drifting element has left its starting position.
  static const double stillSeconds = 7.0;

  @override
  State<SceneClock> createState() => _SceneClockState();
}

class _SceneClockState extends State<SceneClock> with WidgetsBindingObserver {
  /// Built from [clock] so tests can drive it with fake time.
  final _stopwatch = clock.stopwatch();
  final _seconds = ValueNotifier<double>(0);
  Timer? _timer;

  AppLifecycleState? _lifecycleState;
  bool _tickersEnabled = true;
  bool _disableAnimations = false;

  @override
  void initState() {
    super.initState();
    _lifecycleState = WidgetsBinding.instance.lifecycleState;
    WidgetsBinding.instance.addObserver(this);
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _tickersEnabled = TickerMode.valuesOf(context).enabled;
    _disableAnimations = MediaQuery.maybeDisableAnimationsOf(context) ?? false;
    _sync();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    _lifecycleState = state;
    _sync();
  }

  bool get _shouldRun =>
      (_lifecycleState == null ||
          _lifecycleState == AppLifecycleState.resumed) &&
      _tickersEnabled &&
      !_disableAnimations;

  void _sync() {
    if (_disableAnimations) {
      _stop();
      _seconds.value = SceneClock.stillSeconds;
      return;
    }
    if (_shouldRun) {
      if (_timer != null) return;
      _stopwatch.start();
      _timer = Timer.periodic(
        Duration(microseconds: 1000000 ~/ widget.framesPerSecond),
        (_) => _seconds.value = _stopwatch.elapsedMicroseconds / 1000000,
      );
    } else {
      _stop();
    }
  }

  void _stop() {
    _timer?.cancel();
    _timer = null;
    _stopwatch.stop();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _stop();
    _seconds.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return SceneTime(
      seconds: _seconds,
      child: ValueListenableBuilder<double>(
        valueListenable: _seconds,
        builder: (context, seconds, _) => widget.builder(context, seconds),
      ),
    );
  }
}

/// The running scene clock, for a painter inside a scene's facts layer that
/// moves (a pulsing mark) without rebuilding the text around it.
///
/// Hand [of]'s listenable to a `CustomPainter`'s `repaint:` so the painter
/// repaints on every clock value while the widgets stay as they are.
class SceneTime extends InheritedWidget {
  const SceneTime({super.key, required this.seconds, required super.child});

  /// Elapsed scene time, published by the nearest [SceneClock].
  final ValueListenable<double> seconds;

  static final ValueListenable<double> _still = ValueNotifier<double>(
    SceneClock.stillSeconds,
  );

  /// The nearest scene clock, or a clock held at [SceneClock.stillSeconds]
  /// outside a scene.
  static ValueListenable<double> of(BuildContext context) =>
      context.dependOnInheritedWidgetOfExactType<SceneTime>()?.seconds ??
      _still;

  @override
  bool updateShouldNotify(SceneTime oldWidget) =>
      !identical(oldWidget.seconds, seconds);
}
