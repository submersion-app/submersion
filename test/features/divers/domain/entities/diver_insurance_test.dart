import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/features/divers/domain/entities/diver.dart';

void main() {
  group('DiverInsurance emergency contact details', () {
    test('defaults both numbers to null', () {
      const insurance = DiverInsurance(provider: 'ARENA');
      expect(insurance.emergencyPhone, isNull);
      expect(insurance.phone, isNull);
      expect(insurance.assistanceLine, isNull);
      expect(insurance.officeLine, isNull);
      expect(insurance.callNumber, isNull);
      expect(insurance.hasCallNumber, isFalse);
    });

    test('assistanceLine is null when only an office line is recorded', () {
      // The emergency card leads with assistanceLine and nothing else, so
      // this null is what keeps a business-hours number out of the primary
      // button.
      const insurance = DiverInsurance(
        provider: 'ARENA',
        phone: '+49-30-111-111',
      );
      expect(insurance.assistanceLine, isNull);
      expect(insurance.officeLine, '+49-30-111-111');
    });

    test('provider and policy labels trim, and blanks read as absent', () {
      const blank = DiverInsurance(provider: '   ', policyNumber: '');
      expect(blank.providerLabel, isNull);
      expect(blank.policyLabel, isNull);
      expect(blank.hasAnyDetail, isFalse);

      const padded = DiverInsurance(
        provider: '  ARENA  ',
        policyNumber: '  A-777  ',
      );
      expect(padded.providerLabel, 'ARENA');
      expect(padded.policyLabel, 'A-777');
      expect(padded.hasAnyDetail, isTrue);
    });

    test('a whitespace-only provider is not valid insurance', () {
      // isValid feeds Diver.hasValidInsurance, the dashboard gauge strip and
      // the profile hub. If it disagreed with providerLabel, the dashboard
      // would call a policy valid that the emergency card refuses to show.
      const blank = DiverInsurance(provider: '   ');
      expect(blank.isValid, isFalse);
      expect(blank.providerLabel, isNull);

      const named = DiverInsurance(provider: '  ARENA  ');
      expect(named.isValid, isTrue);
    });

    test('hasAnyDetail counts an expiry date on its own', () {
      // Export keys off this, so an expiry-only record must still round-trip.
      final insurance = DiverInsurance(expiryDate: DateTime.utc(2030));
      expect(insurance.hasAnyDetail, isTrue);
      expect(insurance.hasCallNumber, isFalse);
    });

    test('both lines are trimmed, and blanks read as absent', () {
      const insurance = DiverInsurance(
        emergencyPhone: '  +49-30-000-000  ',
        phone: '   ',
      );
      expect(insurance.assistanceLine, '+49-30-000-000');
      expect(insurance.officeLine, isNull);
    });

    test('callNumber prefers the 24h assistance line over the office line', () {
      const insurance = DiverInsurance(
        provider: 'ARENA',
        emergencyPhone: '+49-30-000-000',
        phone: '+49-30-111-111',
      );
      expect(insurance.callNumber, '+49-30-000-000');
      expect(insurance.hasCallNumber, isTrue);
    });

    test('callNumber falls back to the office line', () {
      const insurance = DiverInsurance(
        provider: 'ARENA',
        phone: '+49-30-111-111',
      );
      expect(insurance.callNumber, '+49-30-111-111');
      expect(insurance.hasCallNumber, isTrue);
    });

    test('a blank number is not a call number', () {
      const insurance = DiverInsurance(
        provider: 'ARENA',
        emergencyPhone: '   ',
        phone: '',
      );
      expect(insurance.callNumber, isNull);
      expect(insurance.hasCallNumber, isFalse);
    });

    test('copyWith carries the numbers and can replace them', () {
      const insurance = DiverInsurance(
        provider: 'ARENA',
        emergencyPhone: '+49-30-000-000',
        phone: '+49-30-111-111',
      );
      expect(
        insurance.copyWith(policyNumber: 'P-1').emergencyPhone,
        '+49-30-000-000',
      );
      expect(
        insurance.copyWith(emergencyPhone: '+49-30-222-222').emergencyPhone,
        '+49-30-222-222',
      );
    });

    test('the numbers take part in equality', () {
      expect(
        const DiverInsurance(provider: 'ARENA', emergencyPhone: '1'),
        isNot(const DiverInsurance(provider: 'ARENA', emergencyPhone: '2')),
      );
      expect(
        const DiverInsurance(provider: 'ARENA', phone: '1'),
        isNot(const DiverInsurance(provider: 'ARENA', phone: '2')),
      );
    });
  });
}
