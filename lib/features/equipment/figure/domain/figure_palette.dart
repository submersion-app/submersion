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
    required this.disc,
    required this.onDisc,
  });

  /// The share image and the PDFs draw with this whatever the app theme.
  static const FigurePalette light = FigurePalette(
    body: 0xFFCBD3DB,
    bodyShade: 0xFFB2BCC6,
    gearDark: 0xFF2A2A2E,
    gearLight: 0xFF8FD3FF,
    metal: 0xFF9AA3AD,
    outline: 0xFF1B1B1F,
    disc: 0xFF0B57D0,
    onDisc: 0xFFFFFFFF,
  );

  final int body;
  final int bodyShade;
  final int gearDark;
  final int gearLight;
  final int metal;
  final int outline;
  final int disc;
  final int onDisc;

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
