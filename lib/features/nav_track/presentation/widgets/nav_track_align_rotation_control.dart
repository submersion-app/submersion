import 'package:flutter/material.dart';

import 'package:submersion/l10n/l10n_extension.dart';

/// The rotation control: the existing +/- stepper (0.5 degree steps)
/// alongside a directly editable numeric field, so a diver who knows the
/// exact declination correction they want does not have to click a button
/// dozens of times. Values are clamped to [_min, _max] -- the same range a
/// diver could reach one 0.5-degree step at a time is unbounded in
/// principle, but a rotation outside +/-180 degrees is never meaningful
/// (it is equivalent to a smaller rotation the other way), so that is the
/// sensible bound for typed input.
class NavTrackRotationControl extends StatefulWidget {
  const NavTrackRotationControl({
    super.key,
    required this.headingOffsetDeg,
    required this.onChanged,
  });

  final double headingOffsetDeg;
  final ValueChanged<double> onChanged;

  @override
  State<NavTrackRotationControl> createState() =>
      _NavTrackRotationControlState();
}

class _NavTrackRotationControlState extends State<NavTrackRotationControl> {
  static const double _min = -180;
  static const double _max = 180;

  late final TextEditingController _controller;
  late final FocusNode _focusNode;

  @override
  void initState() {
    super.initState();
    _controller = TextEditingController(text: _format(widget.headingOffsetDeg));
    _focusNode = FocusNode()..addListener(_onFocusChange);
  }

  @override
  void didUpdateWidget(covariant NavTrackRotationControl oldWidget) {
    super.didUpdateWidget(oldWidget);
    // Re-seed only when the stored value actually moved (a stepper tap, a
    // reset, or this field's own commit) and the diver isn't mid-edit --
    // otherwise every keystroke elsewhere on the page would overwrite what
    // they just typed.
    if (!_focusNode.hasFocus &&
        oldWidget.headingOffsetDeg != widget.headingOffsetDeg) {
      _controller.text = _format(widget.headingOffsetDeg);
    }
  }

  @override
  void dispose() {
    _focusNode.removeListener(_onFocusChange);
    _focusNode.dispose();
    _controller.dispose();
    super.dispose();
  }

  static String _format(double value) => value.toStringAsFixed(1);

  void _onFocusChange() {
    if (!_focusNode.hasFocus) _commit();
  }

  /// Parses the field, clamps it, and reports it -- or, when the text is
  /// not a valid number, leaves [widget.headingOffsetDeg] unchanged and
  /// restores the field to it rather than crashing or silently zeroing it.
  void _commit() {
    final parsed = double.tryParse(_controller.text.trim());
    if (parsed == null || !parsed.isFinite) {
      _controller.text = _format(widget.headingOffsetDeg);
      return;
    }
    final clamped = parsed.clamp(_min, _max);
    _controller.text = _format(clamped);
    if (clamped != widget.headingOffsetDeg) widget.onChanged(clamped);
  }

  void _step(double delta) {
    final next = (widget.headingOffsetDeg + delta).clamp(_min, _max);
    widget.onChanged(next);
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    return Row(
      children: [
        Text(l10n.navTrack_align_rotationLabel),
        IconButton(
          key: const ValueKey('nav-track-align-rotate-down'),
          icon: const Icon(Icons.remove),
          onPressed: () => _step(-0.5),
        ),
        SizedBox(
          width: 80,
          child: TextField(
            key: const ValueKey('nav-track-align-rotation-field'),
            controller: _controller,
            focusNode: _focusNode,
            keyboardType: const TextInputType.numberWithOptions(
              decimal: true,
              signed: true,
            ),
            textInputAction: TextInputAction.done,
            decoration: const InputDecoration(suffixText: '°', isDense: true),
            onTapOutside: (_) => _focusNode.unfocus(),
            onEditingComplete: _focusNode.unfocus,
            onSubmitted: (_) => _focusNode.unfocus(),
          ),
        ),
        IconButton(
          key: const ValueKey('nav-track-align-rotate-up'),
          icon: const Icon(Icons.add),
          onPressed: () => _step(0.5),
        ),
      ],
    );
  }
}
