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

  double strengthOf(StripLayer layer) => strengths[layer] ?? 0;
}

/// Eases each card layer of the pinned strip in while its card is in view
/// and out when it leaves, and the strip's growth with the line layers, then
/// builds with the result.
///
/// A layer heads in when the strip is [settled], its card is one of
/// [cardsInView] and [data] has something for it. Turning round mid-fade
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
    _retarget();
  }

  void _retarget() {
    final wanted = widget.settled
        ? stripLayersFor(widget.cardsInView)
        : const <StripLayer>{};
    final active = {
      for (final layer in wanted)
        if (widget.data.hasData(layer)) layer,
    };
    _active = active;
    final instant = MediaQuery.maybeDisableAnimationsOf(context) ?? false;
    for (final layer in StripLayer.values) {
      final on = active.contains(layer);
      final controller = _layers[layer] ?? (on ? _controller() : null);
      if (controller == null) continue;
      _layers[layer] = controller;
      _drive(controller, on: on, instant: instant);
    }
    _drive(_grow, on: active.any((l) => l.isLine), instant: instant);
  }

  void _drive(
    AnimationController controller, {
    required bool on,
    required bool instant,
  }) {
    if (instant) {
      controller.value = on ? 1 : 0;
    } else if (on && controller.status != AnimationStatus.forward) {
      if (controller.value < 1) controller.forward();
    } else if (!on && controller.status != AnimationStatus.reverse) {
      if (controller.value > 0) controller.reverse();
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
    ),
  );
}
