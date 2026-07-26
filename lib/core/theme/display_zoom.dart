import 'package:flutter/material.dart';

/// App-wide display zoom constants and value clamping.
///
/// Zoom is a pure scale factor: 1.0 is the design size, values below 1.0 fit
/// more content on screen, values above 1.0 make everything larger.
class DisplayZoom {
  DisplayZoom._();

  /// Smallest supported zoom factor.
  static const double min = 0.70;

  /// Largest supported zoom factor.
  static const double max = 1.40;

  /// Increment used by the slider and the keyboard shortcuts.
  static const double step = 0.05;

  /// The unzoomed design size.
  static const double defaultValue = 1.0;

  /// Slider divisions across [min]..[max] at [step] granularity.
  static const int divisions = 14;

  static const int _minPercent = 70;
  static const int _maxPercent = 140;
  static const int _stepPercent = 5;

  /// Clamps a stored or computed value into range and snaps it to the nearest
  /// supported level.
  ///
  /// Clamping guards against a corrupt preference producing a zero or NaN
  /// scale, which would divide by zero in the layout and blank the app.
  ///
  /// Snapping matters just as much. Repeated `+/- 0.05` arithmetic drifts:
  /// stepping down past the [min] floor and back up lands on
  /// 1.0000000000000002, which renders as "100%" but is not `== 1.0`. That
  /// would leave the Reset button visible and make DisplayZoomScope build a
  /// transform layer at nominal 100%, defeating its no-op fast path. Snapping
  /// happens in integer-percent space so it cannot itself accumulate error,
  /// and it guarantees the stored value always equals the displayed
  /// percentage divided by 100.
  static double normalize(double value) {
    if (!value.isFinite) return defaultValue;
    final percent = (value * 100).round().clamp(_minPercent, _maxPercent);
    final snapped = (percent / _stepPercent).round() * _stepPercent;
    return snapped / 100;
  }
}

/// Applies an app-wide zoom factor to everything below it.
///
/// Lays the child out in a logical space divided by [zoom], then scales that
/// space back up by [zoom] to fill the physical area. The result is true
/// browser-style zoom: text, icons, spacing, and custom painters all change
/// size together, and because [MediaQuery] is inherited, responsive
/// breakpoints below this widget see the zoomed logical width.
class DisplayZoomScope extends StatelessWidget {
  const DisplayZoomScope({super.key, required this.zoom, required this.child});

  final double zoom;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    // Normalize at the boundary rather than trusting the call site. The
    // provider always supplies a normalized value, but this widget is public:
    // a raw 0, NaN, or negative zoom would divide the logical size into
    // infinity or NaN and blank the UI. Normalizing also means a float-drifted
    // value that should be 100% still takes the no-op fast path below.
    final scale = DisplayZoom.normalize(zoom);

    // Exact identity at the default so users who never touch the setting get
    // the same widget tree as before, with no extra transform layer.
    if (scale == DisplayZoom.defaultValue) return child;

    final mq = MediaQuery.of(context);
    final logical = mq.size / scale;

    return MediaQuery(
      data: mq.copyWith(
        size: logical,
        // Insets are expressed in the outer coordinate space. Without dividing
        // them, content creeps under the notch and behind the keyboard.
        padding: mq.padding / scale,
        viewPadding: mq.viewPadding / scale,
        viewInsets: mq.viewInsets / scale,
        // ImageConfiguration consults this to select asset resolution.
        devicePixelRatio: mq.devicePixelRatio * scale,
      ),
      child: Transform.scale(
        scale: scale,
        alignment: Alignment.topLeft,
        // OverflowBox, not SizedBox: MaterialApp.builder passes TIGHT
        // constraints equal to the physical window, which would force a
        // SizedBox back to the physical size. The child would then be scaled
        // below the window (unpainted band at zoom < 1) or past it (clipped
        // overflow at zoom > 1). OverflowBox lets the child take the enlarged
        // logical size regardless of the incoming constraints.
        child: OverflowBox(
          alignment: Alignment.topLeft,
          minWidth: logical.width,
          maxWidth: logical.width,
          minHeight: logical.height,
          maxHeight: logical.height,
          child: child,
        ),
      ),
    );
  }
}
