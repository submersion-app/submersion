import 'package:flutter_test/flutter_test.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:submersion/core/constants/enums.dart';
import 'package:submersion/core/constants/units.dart';
import 'package:submersion/core/services/pdf_templates/pdf_date_formatter.dart';
import 'package:submersion/core/services/pdf_templates/pdf_front_matter.dart';
import 'package:submersion/features/certifications/domain/entities/certification.dart';
import 'package:submersion/features/divers/domain/entities/diver.dart';

import '../../../helpers/pdf_text.dart';

void main() {
  final dates = PdfDateFormatter(
    dateFormat: DateFormatPreference.ddmmyyyy,
    timeFormat: TimeFormat.twentyFourHour,
  );

  Certification cert(String name, {String? card}) => Certification(
    id: name,
    name: name,
    agency: CertificationAgency.padi,
    cardNumber: card,
    issueDate: DateTime(2020, 5, 1),
    createdAt: DateTime(2020, 5, 1),
    updatedAt: DateTime(2020, 5, 1),
  );

  final diver = Diver(
    id: 'd1',
    name: 'Ada Lovelace',
    createdAt: DateTime(2020, 1, 1),
    updatedAt: DateTime(2020, 1, 1),
  );

  Future<String> render(List<Certification> certs) async {
    final doc = pw.Document();
    doc.addPage(
      pw.Page(
        build: (context) => PdfFrontMatter.buildDiverPage(
          diver: diver,
          dates: dates,
          diveCount: 42,
          certifications: certs,
        ),
      ),
    );
    return pdfVisibleText(await doc.save());
  }

  test('renders the diver name and dive count', () async {
    final text = await render([cert('Open Water')]);
    expect(text, contains('Ada Lovelace'));
    expect(text, contains('42'));
  });

  test('renders every certification, not just the first five', () async {
    final certs = List.generate(8, (i) => cert('Course $i'));
    final text = await render(certs);
    for (var i = 0; i < 8; i++) {
      expect(text, contains('Course $i'), reason: 'certification $i missing');
    }
    expect(text, isNot(contains('and 3 more')));
  });

  test('renders the certification card number when present', () async {
    final text = await render([cert('Rescue Diver', card: 'CARD-77')]);
    expect(text, contains('CARD-77'));
  });
}
