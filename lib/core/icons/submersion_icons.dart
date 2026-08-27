import 'package:flutter/widgets.dart';

/// Dive-gear glyphs drawn for Submersion, vendored alongside the font they
/// live in.
///
/// Neither Material Icons nor Material Design Icons has a wetsuit, a drysuit,
/// a BCD, a rebreather, a hood, a glove, a dive bootie, a reel, a DPV or a
/// regulator, so the equipment list reached for metaphors instead: a hanger
/// for both exposure suits, a hiking figure for boots, an infinity symbol for
/// a reel, a kick scooter for a DPV. Issue #1189 reported the result as icons
/// that "don't really fit the equipment".
///
/// These ten are drawn in `tool/equipment_glyphs.py` and compiled into
/// `assets/fonts/submersion-equipment.ttf` by
/// `tool/build_equipment_icon_font.py`. Regenerate with:
///
/// ```sh
/// pip install fonttools
/// python3 tool/build_equipment_icon_font.py --verify
/// ```
///
/// Shipping them as a font rather than as SVG assets or custom painters keeps
/// [equipmentTypeIcon] returning [IconData], so all of its call sites keep
/// working and the glyphs inherit `IconTheme` size, colour, opacity and
/// directionality for free. Because every constant here is `const`, Flutter's
/// icon tree-shaker subsets the font at build time.
///
/// Code points sit in the Unicode Private Use Area and are assigned in the
/// declaration order of `tool/equipment_glyphs.py`. They are baked into the
/// committed font, so reordering that file without rebuilding the font would
/// silently swap glyphs.
abstract final class SubmersionIcons {
  /// The family declared for the generated font in `pubspec.yaml`.
  static const String fontFamily = 'Submersion Equipment';

  /// One-piece exposure suit with an open neck.
  static const IconData wetsuit = IconData(0xe900, fontFamily: fontFamily);

  /// Five-finger dive glove above a sealed wrist cuff.
  static const IconData gloves = IconData(0xe901, fontFamily: fontFamily);

  /// Dive bootie with a flared sole.
  static const IconData boots = IconData(0xe902, fontFamily: fontFamily);

  /// The wetsuit silhouette with the attached hood and boots that tell a
  /// drysuit apart from it.
  static const IconData drysuit = IconData(0xe903, fontFamily: fontFamily);

  /// Second stage seen side-on, with its purge face and LP hose.
  static const IconData regulator = IconData(0xe904, fontFamily: fontFamily);

  /// Buoyancy vest with a waist belt and a corrugated inflator hose.
  static const IconData bcd = IconData(0xe905, fontFamily: fontFamily);

  /// Scrubber canister flanked by counterlungs.
  static const IconData rebreather = IconData(0xe906, fontFamily: fontFamily);

  /// Hood seen front-on, its face opening running out through the neck.
  static const IconData hood = IconData(0xe907, fontFamily: fontFamily);

  /// Finger spool with line paying out.
  static const IconData reel = IconData(0xe908, fontFamily: fontFamily);

  /// Diver propulsion vehicle: torpedo hull with a shrouded prop.
  static const IconData dpv = IconData(0xe909, fontFamily: fontFamily);
}
