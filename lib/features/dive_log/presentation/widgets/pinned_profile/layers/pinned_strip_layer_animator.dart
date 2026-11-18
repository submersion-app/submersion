import 'dart:math' as math;

import 'package:flutter/material.dart';

import 'package:submersion/core/constants/dive_detail_sections.dart';
import 'package:submersion/features/dive_log/presentation/widgets/pinned_profile/layers/strip_layer.dart';
import 'package:submersion/features/dive_log/presentation/widgets/pinned_profile/layers/strip_layer_data.dart';

/// How long a layer takes to fade in or out, and the strip to grow.
const Duration kStripLayerFade = Duration(milliseconds: 250);

/// What the pinned strip draws of its card layers this frame (issue #4562):
/// the [data], each layer's eased [strengths] from 0 (hidden) to 1, and how
/// far the strip has [grow]n toward its taller height.
@immutable
class StripLayerState {
  const StripLayerState({
    required this.data,
    required this.strengths,
    required this.grow,
    required this.active,
    this.growTarget = 0,
  });

  static const none = StripLayerState(
    data: PinnedStripLayerData.empty,
    strengths: {},
    grow: 0,
    active: {},
  );

  final PinnedStripLayerData data;
  final Map<StripLayer, double> strengths;
  final double grow;

  /// The layers heading in: their card is in view and they have data. A
  /// layer fading out is drawn but not active, so it reads no tooltip row.
  final Set<StripLayer> active;

  /// Where [grow] is heading: 1 while a card in view adds a line, else 0.
  final double growTarget;

  double strengthOf(StripLayer layer) => strengths[layer] ?? 0;

  /// This state for a strip [morph] of the way through its hand-over: what
  /// is left of the growth runs with the morph, so the strip reaches its
  /// target height as it settles however fast the page was scrolled, and
  /// never grows or shrinks after (#4579). Settled ([morph] 1), the growth
  /// is the animator's own, completed as it settled and eased from there as
  /// cards come and go.
  StripLayerState condensedBy(double morph) {
    if (morph >= 1) return this;
    final carried = growTarget >= 1
        ? math.max(grow, morph)
        : math.min(grow, 1 - morph);
    if (carried == grow) return this;
    return StripLayerState(
      data: data,
      strengths: strengths,
      grow: carried,
      active: active,
      growTarget: growTarget,
    );
  }
}

/// Eases each card layer of the pinned strip in while its card is in view
/// and out when it leaves, and the strip's growth with the line layers, then
/// builds with the result.
///
/// A layer heads in when the strip is [settled], its card is one of
/// [cardsInView] and [data] has something for it. The strip grows for such
/// a line layer whether or not it has settled. Turning round mid-fade
/// carries on from where it is. With the platform's reduce-motion setting
/// on, every change applies at once.
class PinnedStripLayerAnimator extends StatefulWidget {
  const PinnedStripLayerAnimator({
    super.key,
    required this.data,
    required this.cardsInView,
    required this.settled,
    required this.builder,
  });

  final PinnedStripLayerData data;
  final Set<DiveDetailSectionId> cardsInView;
  final bool settled;
  final Widget Function(BuildContext context, StripLayerState layers) builder;

  @override
  State<PinnedStripLayerAnimator> createState() =>
      _PinnedStripLayerAnimatorState();
}

class _PinnedStripLayerAnimatorState extends State<PinnedStripLayerAnimator>
    with TickerProviderStateMixin {
  final Map<StripLayer, AnimationController> _layers = {};
  late final AnimationController _grow = _controller();
  Set<StripLayer> _active = const {};
  bool _growOn = false;

  AnimationController _controller() =>
      AnimationController(vsync: this, duration: kStripLayerFade)
        ..addListener(_tick);

  void _tick() => setState(() {});

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _retarget();
  }

  @override
  void didUpdateWidget(PinnedStripLayerAnimator oldWidget) {
    super.didUpdateWidget(oldWidget);
    _retarget(settling: widget.settled && !oldWidget.settled);
  }

  /// [settling] is set as the strip settles: the hand-over has carried the
  /// growth to its target by then ([StripLayerState.condensedBy]), so the
  /// growth is completed with it rather than left to run on.
  void _retarget({bool settling = false}) {
    final available = {
      for (final layer in stripLayersFor(widget.cardsInView))
        if (widget.data.hasData(layer)) layer,
    };
    final active = widget.settled ? available : const <StripLayer>{};
    _active = active;
    final instant = MediaQuery.maybeDisableAnimationsOf(context) ?? false;
    for (final layer in StripLayer.values) {
      final on = active.contains(layer);
      final controller = _layers[layer] ?? (on ? _controller() : null);
      if (controller == null) continue;
      _layers[layer] = controller;
      _drive(controller, on: on, instant: instant);
    }
    // The strip grows for the cards in view while it is still condensing,
    // so it condenses straight to the height it settles at instead of
    // reaching its normal height and growing again (issue #4579).
    _growOn = available.any((l) => l.isLine);
    _drive(_grow, on: _growOn, instant: instant || settling);
  }

  void _drive(
    AnimationController controller, {
    required bool on,
    required bool instant,
  }) {
    if (instant) {
      controller.value = on ? 1 : 0;
    } else if (on && controller.status != AnimationStatus.forward) {
      // Turned back on before its fade-out has ticked, it is still at 1 but
      // heading out; forward() from 1 would not stop it, so it is held there.
      if (controller.value < 1) {
        controller.forward();
      } else {
        controller.value = 1;
      }
    } else if (!on && controller.status != AnimationStatus.reverse) {
      // Turned off before its fade has ticked, it is still at 0 but heading
      // in; reverse() from 0 would not stop it, so it is put back at rest.
      if (controller.value > 0) {
        controller.reverse();
      } else {
        controller.reset();
      }
    }
  }

  double _eased(AnimationController c) => Curves.easeInOut.transform(c.value);

  @override
  void dispose() {
    for (final c in _layers.values) {
      c.dispose();
    }
    _grow.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => widget.builder(
    context,
    StripLayerState(
      data: widget.data,
      strengths: {
        for (final MapEntry(key: layer, value: c) in _layers.entries)
          if (c.value > 0) layer: _eased(c),
      },
      grow: _eased(_grow),
      active: _active,
      growTarget: _growOn ? 1 : 0,
    ),
  );
}
