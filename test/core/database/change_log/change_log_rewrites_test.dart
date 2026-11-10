import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/core/database/change_log/change_log_rewrites.dart';

/// Every helper looks a column up in [changeLogRewrittenColumns] before its
/// repair in [changeLogRewrittenValues], so a repair listed only in the second
/// map would be ignored without a word (issue #4415).
void main() {
  test('every value repair names a column a rung rewrote', () {
    expect(
      changeLogRewrittenColumns.keys,
      containsAll(changeLogRewrittenValues.keys),
    );
  });

  test('a restore repairs a value the rung reshaped and keeps the rest', () {
    Object? restored(Object? value) => changeLogRestoredValue(
      changeLogRewrittenColumns,
      'dives',
      'rating',
      value,
    );

    expect(restored(8), 4);
    expect(restored(0), isNull);
    expect(restored(3), 3);
    expect(restored('5'), '5');
    expect(
      changeLogRestoredValue(changeLogRewrittenColumns, 'dives', 'notes', 0),
      0,
    );
  });

  test('a restore is refused only for a column with no repair', () {
    expect(
      changeLogRestoreBlocked(changeLogRewrittenColumns, 'dives', 'rating', 1),
      isFalse,
    );
    expect(
      changeLogRestoreBlocked(
        changeLogRewrittenColumns,
        'dives',
        'weather_fetched_at',
        336,
      ),
      isTrue,
    );
  });
}
