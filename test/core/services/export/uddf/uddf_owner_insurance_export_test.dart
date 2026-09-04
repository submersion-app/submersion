import 'package:flutter_test/flutter_test.dart';
import 'package:xml/xml.dart';
import 'package:submersion/core/services/export/uddf/uddf_export_builders.dart';
import 'package:submersion/core/services/export/uddf/uddf_import_parsers.dart';
import 'package:submersion/features/divers/domain/entities/diver.dart';

/// The `<insurance>` element lives under the non-standard `<ownerextended>`
/// block, so these tests pin our own contract for it: what gets written, and
/// that the parser reads back what the builder wrote.
void main() {
  final epoch = DateTime.utc(2026, 1, 1);

  Diver ownerWith(DiverInsurance insurance) => Diver(
    id: 'diver-1',
    name: 'Alice Alpha',
    createdAt: epoch,
    updatedAt: epoch,
    insurance: insurance,
  );

  XmlElement? insuranceOf(Diver owner) {
    final builder = XmlBuilder();
    builder.element(
      'root',
      nest: () =>
          UddfExportBuilders.buildApplicationData(builder, owner: owner),
    );
    return builder.buildDocument().findAllElements('insurance').firstOrNull;
  }

  group('UDDF owner insurance export', () {
    test('writes both phone numbers alongside the provider', () {
      final insurance = insuranceOf(
        ownerWith(
          const DiverInsurance(
            provider: 'ARENA',
            policyNumber: 'A-777',
            emergencyPhone: '+49-30-555-0100',
            phone: '+49-30-555-0199',
          ),
        ),
      );

      expect(insurance, isNotNull);
      expect(insurance!.getElement('provider')?.innerText, 'ARENA');
      expect(insurance.getElement('policynumber')?.innerText, 'A-777');
      expect(
        insurance.getElement('emergencyphone')?.innerText,
        '+49-30-555-0100',
      );
      expect(insurance.getElement('phone')?.innerText, '+49-30-555-0199');
    });

    test('exports an assistance line saved without a provider name', () {
      // The card supports a number with no provider name, so gating the
      // element on the provider would drop it on export and lose it on
      // re-import.
      final insurance = insuranceOf(
        ownerWith(const DiverInsurance(emergencyPhone: '+49-30-555-0100')),
      );

      expect(insurance, isNotNull);
      expect(insurance!.getElement('provider'), isNull);
      expect(
        insurance.getElement('emergencyphone')?.innerText,
        '+49-30-555-0100',
      );
    });

    test('exports a policy number saved without a provider name', () {
      final insurance = insuranceOf(
        ownerWith(const DiverInsurance(policyNumber: 'A-777')),
      );

      expect(insurance, isNotNull);
      expect(insurance!.getElement('policynumber')?.innerText, 'A-777');
    });

    test('writes no insurance element when nothing was recorded', () {
      expect(insuranceOf(ownerWith(const DiverInsurance())), isNull);
    });

    test('round-trips both numbers back through the parser', () {
      final owner = ownerWith(
        const DiverInsurance(
          provider: 'ARENA',
          emergencyPhone: '+49-30-555-0100',
          phone: '+49-30-555-0199',
        ),
      );

      final builder = XmlBuilder();
      builder.element(
        'root',
        nest: () =>
            UddfExportBuilders.buildApplicationData(builder, owner: owner),
      );
      final extended = builder
          .buildDocument()
          .findAllElements('ownerextended')
          .first;

      final parsed = <String, dynamic>{};
      UddfImportParsers.parseOwnerExtended(extended, parsed);

      expect(parsed['insuranceProvider'], 'ARENA');
      expect(parsed['insuranceEmergencyPhone'], '+49-30-555-0100');
      expect(parsed['insurancePhone'], '+49-30-555-0199');
    });
  });
}
