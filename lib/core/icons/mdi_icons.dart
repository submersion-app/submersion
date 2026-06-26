import 'package:flutter/widgets.dart';

/// The subset of Material Design Icons glyphs still used by the app, vendored
/// locally alongside the bundled font.
///
/// This replaces the `material_design_icons_flutter` package, which defines its
/// icons via `class _MdiIconData extends IconData`. Flutter 3.44 made
/// [IconData] a `final` (sealed) class, so that package no longer compiles.
/// Only six glyphs were ever used, so we vendor the font
/// (`assets/fonts/materialdesignicons-webfont.ttf`, declared under the
/// `Material Design Icons` family in `pubspec.yaml`) and reference the
/// code points directly via plain [IconData] constants.
///
/// Code points are taken verbatim from material_design_icons_flutter 7.0.7296.
abstract final class MdiIcons {
  static const String _family = 'Material Design Icons';

  static const IconData divingScubaTank = IconData(
    0xf0dc3,
    fontFamily: _family,
  );
  static const IconData fish = IconData(0xf023a, fontFamily: _family);
  static const IconData turtle = IconData(0xf0cd7, fontFamily: _family);
  static const IconData shark = IconData(0xf18ba, fontFamily: _family);
  static const IconData jellyfish = IconData(0xf0f01, fontFamily: _family);
  static const IconData dolphin = IconData(0xf18b4, fontFamily: _family);
}
