import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/features/insights/domain/focus/focus_factor.dart';
import 'package:submersion/features/insights/presentation/formatters/focus_quiet_rows.dart';

void main() {
  NumericFactor numeric({double? g, double? b, bool standsOut = false}) =>
      NumericFactor(
        id: FocusFactorId.maxDepth,
        groupCovered: g == null ? 0 : 3,
        groupSize: 3,
        groupMean: g,
        baselineMean: b,
        standsOut: standsOut,
        strength: standsOut ? 1 : 0,
      );
  CategoricalFactor categorical(List<CategoryShare> top) => CategoricalFactor(
    id: FocusFactorId.entryMethod,
    groupCovered: top.isEmpty ? 0 : 3,
    groupSize: 3,
    top: top,
  );
  CategoryShare share(double g, double b, {bool standsOut = false}) =>
      CategoryShare(
        key: 'boat',
        groupShare: g,
        baselineShare: b,
        groupCount: 3,
        standsOut: standsOut,
        strength: g - b,
      );

  test('a standout is never quiet', () {
    expect(
      focusFactorIsQuiet(
        numeric(g: 20, b: 20, standsOut: true),
        formattedDifference: '+0.0m',
      ),
      isFalse,
    );
  });

  test('no data is quiet', () {
    expect(focusFactorIsQuiet(numeric(), formattedDifference: null), isTrue);
    expect(
      focusFactorIsQuiet(categorical(const []), formattedDifference: null),
      isTrue,
    );
  });

  test('a difference that rounds to zero in display units is quiet', () {
    expect(
      focusFactorIsQuiet(
        numeric(g: 20.02, b: 20),
        formattedDifference: '+0.0m',
      ),
      isTrue,
    );
    expect(
      focusFactorIsQuiet(
        numeric(g: 20.02, b: 20),
        formattedDifference: '+0 ft',
      ),
      isTrue,
    );
    expect(
      focusFactorIsQuiet(numeric(g: 21, b: 20), formattedDifference: '+1.0m'),
      isFalse,
    );
  });

  test('a categorical top value under a five point gap is quiet', () {
    expect(
      focusFactorIsQuiet(
        categorical([share(0.42, 0.40)]),
        formattedDifference: null,
      ),
      isTrue,
    );
    expect(
      focusFactorIsQuiet(
        categorical([share(0.50, 0.40)]),
        formattedDifference: null,
      ),
      isFalse,
    );
    expect(
      focusFactorIsQuiet(
        categorical([share(0.30, 0.40)]),
        formattedDifference: null,
      ),
      isFalse,
    );
  });
}
