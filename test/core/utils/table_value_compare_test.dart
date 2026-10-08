import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/core/text/text_sort.dart';
import 'package:submersion/core/utils/table_value_compare.dart';

/// Sort order for a table column whose cells can hold values of different
/// kinds (issue #2444: a Visibility column mixing measured metres with legacy
/// bucket labels threw `String is not a subtype of num` and greyed out the
/// whole dive table).
void main() {
  int compare(Object a, Object b) => compareTableValues(
    a,
    b,
    collator: TextCollator(),
    formatted: (v) => v is List ? v.join(', ') : v.toString(),
  );

  test('text compares alphabetically, ignoring case', () {
    expect(compare('anchor', 'Zebra'), lessThan(0));
    expect(compare('Zebra', 'plage'), greaterThan(0));
  });

  test('numbers compare numerically across int and double', () {
    expect(compare(3, 8.5), lessThan(0));
    expect(compare(12.0, 8), greaterThan(0));
    expect(compare(5, 5.0), 0);
  });

  test('same-type Comparables use their own order', () {
    expect(compare(DateTime(2024), DateTime(2025)), lessThan(0));
    expect(
      compare(const Duration(minutes: 50), const Duration(minutes: 9)),
      greaterThan(0),
    );
  });

  test('a number sorts before text, whichever side it is on', () {
    expect(compare(8.0, 'Poor (<5m / <15ft)'), lessThan(0));
    expect(compare('Poor (<5m / <15ft)', 8.0), greaterThan(0));
  });

  test('a number sorts before a non-numeric Comparable, text after both', () {
    expect(compare(3, DateTime(2024)), lessThan(0));
    expect(compare(DateTime(2024), 'Moderate'), lessThan(0));
    expect(compare('Moderate', DateTime(2024)), greaterThan(0));
  });

  test('Comparables of different types fall back to formatted text', () {
    // DateTime.compareTo(Duration) would throw; the formatted text decides.
    expect(
      () => compare(DateTime(2024), const Duration(minutes: 9)),
      returnsNormally,
    );
    expect(
      compare(DateTime(2024), const Duration(minutes: 9)),
      compareTextForSort(
        DateTime(2024).toString(),
        const Duration(minutes: 9).toString(),
      ),
    );
  });

  test('non-Comparable values compare by formatted text', () {
    expect(compare(['anchor'], ['Zebra']), lessThan(0));
    expect(compare(true, false), greaterThan(0)); // 'true' after 'false'
  });

  test('sorting a mixed list never throws and groups numbers first', () {
    final values = <Object>['Poor', 12.0, 'Good', 3, 8.5];
    values.sort(compare);
    expect(values, [3, 8.5, 12.0, 'Good', 'Poor']);
  });
}
