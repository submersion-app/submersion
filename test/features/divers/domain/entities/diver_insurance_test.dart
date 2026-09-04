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
