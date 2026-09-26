import 'package:submersion/shared/widgets/forms/number_input_validation.dart';

/// Read a mix percentage from a field, keeping [previous] when the field is
/// blank or half-typed.
///
/// Falling back to zero, which is what this did before PR #1215, conflates two
/// different states. For a pressure field they coincide: an empty field and an
/// empty cylinder are both 0 bar. For a mix field they do not. Clearing the O2
/// and He boxes before typing a replacement left the blender solving for 0% O2
/// and 0% He, which is 100% nitrogen, and it answered with a well-formed fill
/// procedure for a cylinder nobody has. A field reporter caught it only by
/// cross-checking against three other blending tools.
///
/// Keeping the previous value means a half-finished edit shows a procedure
/// that is one keystroke stale rather than one that is confidently wrong.
///
/// Unreadable text keeps [previous] too, while the field shows its error.
double mixPercentOrKeep(String text, double previous) =>
    switch (readNumber(text)) {
      NumberValue(:final value) => value,
      NumberBlank() || NumberInvalid() => previous,
    };

/// Read a pressure from a field. Blank genuinely means zero here: an empty
/// cylinder is the most common starting point there is.
///
/// Null for unreadable text, so the caller keeps the pressure it has. Reading
/// it as zero, as this once did, turned a mistyped fill pressure into an
/// empty cylinder while the field showed its error (#1900).
double? pressureOrKeep(String text) => switch (readNumber(text)) {
  NumberValue(:final value) => value,
  NumberBlank() => 0,
  NumberInvalid() => null,
};
