import 'package:equatable/equatable.dart';

/// A window's position and size in logical screen coordinates, as the
/// desktop window and display APIs report them (issue #5078).
class PopOutFrame extends Equatable {
  final double x;
  final double y;
  final double width;
  final double height;

  const PopOutFrame({
    required this.x,
    required this.y,
    required this.width,
    required this.height,
  });

  double get centerX => x + width / 2;
  double get centerY => y + height / 2;

  bool contains(double px, double py) =>
      px >= x && px < x + width && py >= y && py < y + height;

  Map<String, Object> toMap() => {
    'x': x,
    'y': y,
    'width': width,
    'height': height,
  };

  /// The frame [toMap] wrote, or null for anything else.
  static PopOutFrame? fromMap(Object? map) {
    if (map is! Map) return null;
    final x = map['x'];
    final y = map['y'];
    final width = map['width'];
    final height = map['height'];
    if (x is! num || y is! num || width is! num || height is! num) {
      return null;
    }
    return PopOutFrame(
      x: x.toDouble(),
      y: y.toDouble(),
      width: width.toDouble(),
      height: height.toDouble(),
    );
  }

  @override
  List<Object?> get props => [x, y, width, height];
}

/// How tall the strip at the top of a window is that the diver drags it by.
/// A saved frame is reused only while that strip is on a connected display,
/// so a window can always be grabbed and moved.
const double _titleStripHeight = 40;

/// Where the pop-out opens: [saved] when its title strip is on one of
/// [displays], otherwise a [defaultWidth] by [defaultHeight] window centred
/// on the display that holds [mainWindow]'s centre (or on the main window
/// itself when no display is known). Never smaller than [minWidth] by
/// [minHeight].
PopOutFrame resolvePopOutFrame({
  PopOutFrame? saved,
  required List<PopOutFrame> displays,
  required PopOutFrame mainWindow,
  double defaultWidth = 900,
  double defaultHeight = 600,
  double minWidth = 480,
  double minHeight = 320,
}) {
  if (saved != null) {
    final stripX = saved.centerX;
    final stripY = saved.y + _titleStripHeight / 2;
    if (displays.any((d) => d.contains(stripX, stripY))) {
      return PopOutFrame(
        x: saved.x,
        y: saved.y,
        width: saved.width < minWidth ? minWidth : saved.width,
        height: saved.height < minHeight ? minHeight : saved.height,
      );
    }
  }

  PopOutFrame? host;
  for (final display in displays) {
    if (display.contains(mainWindow.centerX, mainWindow.centerY)) {
      host = display;
      break;
    }
  }
  host ??= displays.isEmpty ? mainWindow : displays.first;
  return PopOutFrame(
    x: host.x + (host.width - defaultWidth) / 2,
    y: host.y + (host.height - defaultHeight) / 2,
    width: defaultWidth,
    height: defaultHeight,
  );
}
