import 'package:flutter/widgets.dart';

/// Tells a page whether the route holding it has finished sliding in.
///
/// A route animation advances by elapsed time, so a page that builds
/// everything in the opening frames of its slide makes that slide jump: the
/// next frame lands already part of the way across (issue #3489). A heavy
/// page builds what it can afford during the slide and the rest once
/// [isRouteEntranceSettled] turns true.
///
/// That happens halfway through the slide's time, not at its end. The
/// platforms' slide curves have the page 92 to 95 percent of the way across
/// by then, so the second half moves it too little for a long frame to
/// show, and waiting it out only made the page slower to fill in.
///
/// A page with no slide to wait for (the initial route, a deep link, a page
/// with no transition, or one outside any route) is settled from its first
/// build. Once settled it stays settled, so sliding back out never tears the
/// page down again.
mixin RouteEntranceSettled<T extends StatefulWidget> on State<T> {
  /// How far through its time a slide has run when the page settles.
  static const double settleFraction = 0.5;

  ModalRoute<Object?>? _route;
  Animation<double>? _entrance;
  bool _settled = false;

  /// Whether the route's entrance has run far enough to build everything.
  bool get isRouteEntranceSettled => _settled;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_settled) return;
    final route = ModalRoute.of(context);
    final entrance = route?.animation;
    if (route == null || entrance == null) {
      _stopListening();
      _settled = true;
      return;
    }
    _route = route;
    if (!identical(entrance, _entrance)) {
      _stopListening();
      _entrance = entrance
        ..addListener(_onEntranceTick)
        ..addStatusListener(_onEntranceStatus);
    }
    _settled = !_isEntering(entrance.status) || _hasArrived(entrance);
    if (_settled) _stopListening();
  }

  /// Whether the route is still on its way in. A hero controller builds a
  /// pushed route offstage for its first frame, its animation reading
  /// complete, to measure where heroes land; the slide only starts once the
  /// route comes back onstage.
  bool _isEntering(AnimationStatus status) =>
      (_route?.offstage ?? false) || status == AnimationStatus.forward;

  /// Whether [entrance] has arrived far enough to settle. Only a slide that
  /// is still coming in counts: one that turns back, because the page was
  /// popped or a back swipe began mid-entrance, builds nothing on its way
  /// out, and one that a cancelled swipe sends forward again still arrives.
  bool _hasArrived(Animation<double> entrance) {
    if (_route?.offstage ?? false) return false;
    return switch (entrance.status) {
      AnimationStatus.completed => true,
      AnimationStatus.forward => entrance.value >= settleFraction,
      AnimationStatus.reverse || AnimationStatus.dismissed => false,
    };
  }

  void _onEntranceTick() => _settleIfArrived();

  void _onEntranceStatus(AnimationStatus _) => _settleIfArrived();

  void _settleIfArrived() {
    final entrance = _entrance;
    if (entrance == null || !_hasArrived(entrance)) return;
    _stopListening();
    if (mounted) setState(() => _settled = true);
  }

  void _stopListening() {
    _entrance
      ?..removeListener(_onEntranceTick)
      ..removeStatusListener(_onEntranceStatus);
    _entrance = null;
  }

  @override
  void dispose() {
    _stopListening();
    super.dispose();
  }
}
