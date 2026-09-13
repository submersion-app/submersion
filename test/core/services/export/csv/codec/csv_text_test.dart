import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/core/services/export/csv/codec/csv_text.dart';

void main() {
  test('sanitize and unsanitize are inverses for guarded values', () {
    for (final v in [
      '=1+1',
      '+x',
      '-3',
      '@a',
      '\tq',
      '|p',
      'plain',
      "'quoted",
    ]) {
      expect(unsanitizeCsvField(sanitizeCsvField(v)), v, reason: v);
    }
  });

  test('a leading quote before an unguarded character is kept', () {
    expect(unsanitizeCsvField("'hello"), "'hello");
  });

  test('trimFixed drops trailing zeros only', () {
    expect(trimFixed(22.0, 1), '22');
    expect(trimFixed(22.04, 1), '22');
    expect(trimFixed(0.39251, 3), '0.393');
    expect(trimFixed(1.50, 2), '1.5');
    expect(trimFixed(100, 1), '100');
  });

  test("a typed leading quote before a formula character round trips", () {
    // "'=1+1" is already inert in a spreadsheet, but the reader strips one
    // guard quote, so the writer doubles it to hand the value back intact.
    expect(sanitizeCsvField("'=1+1"), "''=1+1");
    expect(unsanitizeCsvField(sanitizeCsvField("'=1+1")), "'=1+1");
    expect(unsanitizeCsvField(sanitizeCsvField("'-x")), "'-x");
  });
}
