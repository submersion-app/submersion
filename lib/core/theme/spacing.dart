/// The spacing scale for padding, margins and gaps (issue #4971).
///
/// Each name carries its value, so `EdgeInsets.all(Spacing.s16)` reads as
/// what it draws. The scale names the values the app already uses most; it
/// is not a grid to round to. A value that is deliberately off the scale
/// (the form rows' 11/14 padding, the 88 clearance under a FAB) gets its own
/// named constant with a doc comment saying why, beside the code that uses
/// it, rather than moving to a nearby step.
///
/// `test/architecture/spacing_literals_test.dart` keeps spacing literals out
/// of the folders it guards. See `docs/developer/ui-conventions.md`.
abstract final class Spacing {
  static const double s2 = 2;
  static const double s4 = 4;
  static const double s6 = 6;
  static const double s8 = 8;
  static const double s12 = 12;
  static const double s16 = 16;
  static const double s20 = 20;
  static const double s24 = 24;
  static const double s32 = 32;
  static const double s40 = 40;
  static const double s48 = 48;
}

/// Corner radii (issue #4971), named after their values like [Spacing].
///
/// An off-scale radius (the 13 of a form group, `FormStyle.groupRadius`)
/// gets its own named constant with a reason, as for spacing. See
/// `docs/developer/ui-conventions.md`.
abstract final class Radii {
  static const double r2 = 2;
  static const double r4 = 4;
  static const double r6 = 6;
  static const double r8 = 8;
  static const double r12 = 12;
  static const double r16 = 16;
  static const double r20 = 20;
  static const double r24 = 24;

  /// Fully rounded ends on a box of any height up to it: a pill or a dot.
  static const double pill = 999;
}
