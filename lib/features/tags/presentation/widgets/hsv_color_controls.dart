import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';

import 'package:submersion/l10n/l10n_extension.dart';

/// Picks saturation (left to right) and brightness (bottom to top) for the
/// hue of [color] (issue #4384). Taps and drags both report, clamped to the
/// square, so a drag that leaves it pins to the edge rather than stopping.
///
/// Pointer and touch only: keyboard and screen-reader users set a colour
/// through the custom colour dialog's code field.
class SaturationValueSquare extends StatelessWidget {
  const SaturationValueSquare({
    super.key,
    required this.color,
    required this.onChanged,
  });

  final HSVColor color;
  final ValueChanged<HSVColor> onChanged;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      container: true,
      label: context.l10n.tags_color_squareLabel,
      child: LayoutBuilder(
        builder: (context, constraints) {
          final size = constraints.biggest;
          void report(Offset p) => onChanged(
            color
                .withSaturation((p.dx / size.width).clamp(0.0, 1.0))
                .withValue(1 - (p.dy / size.height).clamp(0.0, 1.0)),
          );
          return _EagerPointer(
            onPosition: report,
            child: CustomPaint(size: size, painter: _SquarePainter(color)),
          );
        },
      ),
    );
  }
}

class _SquarePainter extends CustomPainter {
  _SquarePainter(this.color);

  final HSVColor color;

  @override
  void paint(Canvas canvas, Size size) {
    final rect = Offset.zero & size;
    final clip = RRect.fromRectAndRadius(rect, const Radius.circular(8));
    canvas.save();
    canvas.clipRRect(clip);
    canvas.drawRect(
      rect,
      Paint()..color = HSVColor.fromAHSV(1, color.hue, 1, 1).toColor(),
    );
    canvas.drawRect(
      rect,
      Paint()
        ..shader = const LinearGradient(
          colors: [Colors.white, Color(0x00FFFFFF)],
        ).createShader(rect),
    );
    canvas.drawRect(
      rect,
      Paint()
        ..shader = const LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [Color(0x00000000), Colors.black],
        ).createShader(rect),
    );
    canvas.restore();
    _paintThumb(
      canvas,
      Offset(color.saturation * size.width, (1 - color.value) * size.height),
    );
  }

  @override
  bool shouldRepaint(_SquarePainter old) => old.color != color;
}

/// Picks the hue of [color], 0 to 360 left to right, keeping its saturation
/// and brightness.
class HueSlider extends StatelessWidget {
  const HueSlider({super.key, required this.color, required this.onChanged});

  final HSVColor color;
  final ValueChanged<HSVColor> onChanged;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      container: true,
      label: context.l10n.tags_color_hueLabel,
      child: LayoutBuilder(
        builder: (context, constraints) {
          final size = Size(constraints.maxWidth, 28);
          void report(Offset p) => onChanged(
            color.withHue((p.dx / size.width).clamp(0.0, 1.0) * 360),
          );
          return _EagerPointer(
            onPosition: report,
            child: CustomPaint(size: size, painter: _HuePainter(color.hue)),
          );
        },
      ),
    );
  }
}

class _HuePainter extends CustomPainter {
  _HuePainter(this.hue);

  final double hue;

  static final List<Color> _spectrum = [
    for (var h = 0; h <= 360; h += 60)
      HSVColor.fromAHSV(1, h % 360, 1, 1).toColor(),
  ];

  @override
  void paint(Canvas canvas, Size size) {
    final track = Rect.fromLTWH(0, size.height / 2 - 7, size.width, 14);
    canvas.drawRRect(
      RRect.fromRectAndRadius(track, const Radius.circular(7)),
      Paint()..shader = LinearGradient(colors: _spectrum).createShader(track),
    );
    _paintThumb(canvas, Offset(hue / 360 * size.width, size.height / 2));
  }

  @override
  bool shouldRepaint(_HuePainter old) => old.hue != hue;
}

/// A white ring with a dark edge, visible on any colour under it.
void _paintThumb(Canvas canvas, Offset at) {
  canvas.drawCircle(
    at,
    9,
    Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 4
      ..color = Colors.black54,
  );
  canvas.drawCircle(
    at,
    9,
    Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2.5
      ..color = Colors.white,
  );
}

/// Reports every press and move of a pointer on [child], and keeps the
/// gesture from a scrolling ancestor.
///
/// A plain pan loses a vertical drag to the dialog's scroll view whenever the
/// dialog scrolls (the keyboard is up, or a phone is on its side), and the
/// square then stops answering up and down. Winning the gesture arena on
/// pointer down keeps every drag that starts here on the control.
class _EagerPointer extends StatelessWidget {
  const _EagerPointer({required this.onPosition, required this.child});

  final ValueChanged<Offset> onPosition;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return RawGestureDetector(
      behavior: HitTestBehavior.opaque,
      gestures: {
        EagerGestureRecognizer:
            GestureRecognizerFactoryWithHandlers<EagerGestureRecognizer>(
              EagerGestureRecognizer.new,
              (_) {},
            ),
      },
      child: Listener(
        behavior: HitTestBehavior.opaque,
        onPointerDown: (e) => onPosition(e.localPosition),
        onPointerMove: (e) => onPosition(e.localPosition),
        child: child,
      ),
    );
  }
}
