import 'package:flutter/widgets.dart';

/// The subset of Material Design Icons glyphs still used by the app, vendored
/// locally alongside the bundled font.
///
/// This replaces the `material_design_icons_flutter` package, which defines its
/// icons via `class _MdiIconData extends IconData`. Flutter 3.44 made
/// [IconData] a `final` (sealed) class, so that package no longer compiles.
/// Only a handful of glyphs are ever used, so we vendor the font
/// (`assets/fonts/materialdesignicons-webfont.ttf`, declared under the
/// `Material Design Icons` family in `pubspec.yaml`) and reference the
/// code points directly via plain [IconData] constants.
///
/// Code points are taken verbatim from material_design_icons_flutter 7.0.7296.
abstract final class MdiIcons {
  /// The family declared for the vendored font in `pubspec.yaml`. Public so
  /// tests can look the code points below up in the committed `.ttf`.
  static const String fontFamily = 'Material Design Icons';

  static const IconData divingScubaTank = IconData(
    0xf0dc3,
    fontFamily: fontFamily,
  );

  // Dive glyphs that were sitting unused in the bundled font while the
  // equipment list showed Material metaphors instead: waves for fins, an
  // eyeball for a mask, scissors for a knife, a gym dumbbell for weights and a
  // generic flag for an SMB (#1189). `knifeMilitary` rather than `knife`,
  // which is a chef's knife.
  static const IconData divingFlippers = IconData(
    0xf0dbf,
    fontFamily: fontFamily,
  );
  static const IconData divingScubaMask = IconData(
    0xf0dc1,
    fontFamily: fontFamily,
  );
  static const IconData divingScubaFlag = IconData(
    0xf0dc2,
    fontFamily: fontFamily,
  );
  static const IconData knifeMilitary = IconData(
    0xf09fc,
    fontFamily: fontFamily,
  );
  static const IconData weight = IconData(0xf05a1, fontFamily: fontFamily);

  // Five of the six equipment types added for #1518 found their shape already
  // sitting in the bundled font: a literal snorkel, a bezelled compass card, a
  // needle gauge for the instrument family (SPG, depth gauge, bottom timer), a
  // crossed screwdriver and wrench for a save-a-dive kit, and a crew-neck
  // shirt for a rash guard. The sixth, the undergarment, is drawn in
  // `SubmersionIcons`: no icon font has a thermal base layer.
  static const IconData divingSnorkel = IconData(
    0xf0dc5,
    fontFamily: fontFamily,
  );
  static const IconData compass = IconData(0xf018b, fontFamily: fontFamily);
  static const IconData gauge = IconData(0xf029a, fontFamily: fontFamily);
  static const IconData tools = IconData(0xf1064, fontFamily: fontFamily);
  static const IconData tshirtCrew = IconData(0xf0a7b, fontFamily: fontFamily);

  static const IconData fish = IconData(0xf023a, fontFamily: fontFamily);
  static const IconData turtle = IconData(0xf0cd7, fontFamily: fontFamily);
  static const IconData shark = IconData(0xf18ba, fontFamily: fontFamily);
  static const IconData jellyfish = IconData(0xf0f01, fontFamily: fontFamily);
  static const IconData dolphin = IconData(0xf18b4, fontFamily: fontFamily);
}
