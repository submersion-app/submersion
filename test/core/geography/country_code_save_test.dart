import 'package:flutter_test/flutter_test.dart';

import 'package:submersion/core/geography/country_code_save.dart';

/// The rule that keeps a stored country code in step with its country text,
/// shared by sites and buddies (issues #4426, #4457).
void main() {
  group('reconcileCountryCode', () {
    test('a new record reads its code from the text', () {
      expect(reconcileCountryCode(country: 'Italy', code: null), 'IT');
    });

    test('a new record with no country has no code', () {
      expect(reconcileCountryCode(country: null, code: null), isNull);
    });

    test('changed text with the old code carried over is read afresh', () {
      expect(
        reconcileCountryCode(
          country: 'Malta',
          code: 'IT',
          before: (country: 'Italy', code: 'IT'),
        ),
        'MT',
      );
    });

    test('unchanged text written without a code keeps the stored one', () {
      expect(
        reconcileCountryCode(
          country: 'Korea',
          code: null,
          before: (country: 'Korea', code: 'KR'),
        ),
        'KR',
      );
    });

    test('cleared text clears the code', () {
      expect(
        reconcileCountryCode(
          country: '  ',
          code: null,
          before: (country: 'Italy', code: 'IT'),
        ),
        isNull,
      );
    });

    test("a writer's own code for changed text is kept", () {
      expect(
        reconcileCountryCode(
          country: 'Italy',
          code: 'IT',
          before: (country: 'Malta', code: 'MT'),
        ),
        'IT',
      );
    });

    test('text that names no country gets no code', () {
      expect(reconcileCountryCode(country: 'Atlantis', code: null), isNull);
    });
  });

  group('countryCodeOnSave', () {
    test('text left as it came keeps the code that came with it', () {
      expect(
        countryCodeOnSave(
          country: 'Korea',
          known: (country: 'Korea', code: 'KR'),
        ),
        'KR',
      );
    });

    test('edited text is read afresh', () {
      expect(
        countryCodeOnSave(
          country: 'Malta',
          known: (country: 'Italy', code: 'IT'),
        ),
        'MT',
      );
    });
  });
}
