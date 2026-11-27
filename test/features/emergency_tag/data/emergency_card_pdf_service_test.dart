import 'package:flutter_test/flutter_test.dart';
import 'package:pdf/widgets.dart' as pw;

import 'package:submersion/features/emergency_tag/data/services/emergency_card_pdf_service.dart';

import '../../../helpers/pdf_text.dart';

void main() {
  // Helvetica keeps the text readable by pdfVisibleText; production uses the
  // shared Roboto loader.
  EmergencyCardPdfService service() => EmergencyCardPdfService(
    loadTheme: (_) async => pw.ThemeData.withFont(
      base: pw.Font.helvetica(),
      bold: pw.Font.helveticaBold(),
    ),
  );

  test('the card carries every line, the header and the QR caption', () async {
    final bytes = await service().generateBytes(
      const EmergencyCardContent(
        lines: [
          'EMERGENCY INFO',
          'Name: Sam Diver',
          'Allergies: Penicillin',
          'Emergency contact: Alex Diver (Partner) +15551234567',
        ],
        qrData: 'tel:+15551234567',
        qrCaption: 'Scan to call.',
      ),
    );
    final text = pdfVisibleText(bytes);
    expect(text, contains('EMERGENCY INFO'));
    expect(text, contains('Allergies: Penicillin'));
    expect(text, contains('Alex Diver (Partner) +15551234567'));
    expect(text, contains('Scan to call.'));
    expect(pdfPageCount(bytes), 1);
  });

  test('a long card still prints on one page, nothing left off', () async {
    final notes = List.filled(60, 'Long medical history line').join(' ');
    final bytes = await service().generateBytes(
      EmergencyCardContent(
        lines: ['EMERGENCY INFO', 'Name: Sam', 'Medical notes: $notes'],
        qrData: 'https://submersion.app/e#f=1&n=Sam',
        qrCaption: 'Scan for these details on a phone.',
      ),
    );
    expect(pdfPageCount(bytes), 1);
  });
}
