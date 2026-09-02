import 'package:submersion/core/utils/number_input.dart';

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
double mixPercentOrKeep(String text, double previous) {
  if (text.trim().isEmpty) return previous;
  return parseUserDecimal(text) ?? previous;
}

/// Read a pressure from a field. Blank genuinely means zero here: an empty
/// cylinder is the most common starting point there is.
double pressureOrZero(String text) => parseUserDecimal(text) ?? 0;
