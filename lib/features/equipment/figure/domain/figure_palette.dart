import 'package:submersion/features/equipment/figure/domain/figure_role.dart';

/// Colours for every role, as ARGB ints so the PDF code can use the same
/// palette without Flutter.
class FigurePalette {
  const FigurePalette({
    required this.body,
    required this.bodyShade,
    required this.gearDark,
    required this.gearLight,
    required this.metal,
    required this.outline,
    required this.badge,
    required this.onBadge,
  });

  /// The share image and the PDFs draw with this whatever the app theme.
  static const FigurePalette light = FigurePalette(
    body: 0xFFCBD3DB,
    bodyShade: 0xFFB2BCC6,
    gearDark: 0xFF2A2A2E,
    gearLight: 0xFF8FD3FF,
    metal: 0xFF9AA3AD,
    outline: 0xFF1B1B1F,
    badge: 0xFF0B57D0,
    onBadge: 0xFFFFFFFF,
  );

  final int body;
  final int bodyShade;
  final int gearDark;
  final int gearLight;
  final int metal;
  final int outline;

  /// The number badge's fill and its digit.
  final int badge;
  final int onBadge;

  /// The colour for [role] on an item whose own colour is [itemColor].
  int colorFor(FigureRole role, int itemColor) => switch (role) {
    FigureRole.body => body,
    FigureRole.bodyShade => bodyShade,
    FigureRole.gearDark => gearDark,
    FigureRole.gearLight => gearLight,
    FigureRole.metal => metal,
    FigureRole.itemColor => itemColor,
    FigureRole.itemShade => darken(itemColor, 0.25),
    FigureRole.outline => outline,
  };

  @override
  bool operator ==(Object other) =>
      other is FigurePalette &&
      other.body == body &&
      other.bodyShade == bodyShade &&
      other.gearDark == gearDark &&
      other.gearLight == gearLight &&
      other.metal == metal &&
      other.outline == outline &&
      other.badge == badge &&
      other.onBadge == onBadge;

  @override
  int get hashCode => Object.hash(
    body,
    bodyShade,
    gearDark,
    gearLight,
    metal,
    outline,
    badge,
    onBadge,
  );

  /// Scales the RGB channels of [argb] down by [fraction], keeping alpha.
  static int darken(int argb, double fraction) {
    final keep = 1 - fraction;
    int channel(int shift) => (((argb >> shift) & 0xFF) * keep).truncate();
    return (argb & 0xFF000000) |
        (channel(16) << 16) |
        (channel(8) << 8) |
        channel(0);
  }
}
