import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/core/theme/spacing.dart';

/// The constants are named after their values (issue #4971), so a migration
/// from a literal reads as one-to-one. A typo in a value would silently move
/// pixels everywhere that name is used.
void main() {
  test('spacing values match their names', () {
    const scale = {
      2: Spacing.s2,
      4: Spacing.s4,
      6: Spacing.s6,
      8: Spacing.s8,
      12: Spacing.s12,
      16: Spacing.s16,
      20: Spacing.s20,
      24: Spacing.s24,
      32: Spacing.s32,
      40: Spacing.s40,
      48: Spacing.s48,
    };
    scale.forEach((name, value) => expect(value, name.toDouble()));
  });

  test('radius values match their names', () {
    const scale = {
      2: Radii.r2,
      4: Radii.r4,
      6: Radii.r6,
      8: Radii.r8,
      12: Radii.r12,
      16: Radii.r16,
      20: Radii.r20,
      24: Radii.r24,
    };
    scale.forEach((name, value) => expect(value, name.toDouble()));
    expect(Radii.pill, 999);
  });
}
