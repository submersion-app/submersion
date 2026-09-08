import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/core/constants/enums.dart';
import 'package:submersion/core/constants/pdf_templates.dart';
import 'package:submersion/core/constants/units.dart';
import 'package:submersion/core/services/pdf_templates/pdf_date_formatter.dart';
import 'package:submersion/core/services/pdf_templates/pdf_template_builder.dart';
import 'package:submersion/core/services/pdf_templates/pdf_template_detailed.dart';
import 'package:submersion/core/services/pdf_templates/pdf_template_naui.dart';
import 'package:submersion/core/services/pdf_templates/pdf_template_padi.dart';
import 'package:submersion/core/utils/unit_formatter.dart';
import 'package:submersion/features/certifications/domain/entities/certification.dart';
import 'package:submersion/features/dive_log/domain/entities/dive.dart';
import 'package:submersion/features/settings/presentation/providers/settings_providers.dart';

import '../../../helpers/pdf_text.dart';

/// Every template placed the certification list on a single `pw.Page`, which
/// cannot break: a diver with more certifications than fit simply lost the
/// overflow with no warning. That is the "not all certifications are
/// displayed" report in #1017, and these tests pin the pagination.
void main() {
  final dive = Dive(
    id: 'd1',
    diveNumber: 1,
    dateTime: DateTime(2026, 3, 28, 14, 30),
    runtime: const Duration(minutes: 50),
    maxDepth: 30.0,
    waterTemp: 20.0,
  );

  final dates = PdfDateFormatter(
    dateFormat: DateFormatPreference.ddmmyyyy,
    timeFormat: TimeFormat.twentyFourHour,
  );
  const units = UnitFormatter(AppSettings());

  List<Certification> manyCerts(int count) => List.generate(
    count,
    (i) => Certification(
      id: 'c$i',
      name: 'Specialty$i',
      agency: CertificationAgency.padi,
      cardNumber: 'CARD-$i',
      issueDate: DateTime(2019, 1, 1),
      expiryDate: DateTime(2030, 6, 30),
      createdAt: DateTime(2019, 1, 1),
      updatedAt: DateTime(2019, 1, 1),
    ),
  );

  final builders = <String, PdfTemplateBuilder Function()>{
    'Detailed': PdfTemplateDetailed.new,
    'PADI': PdfTemplatePadi.new,
    'NAUI': PdfTemplateNaui.new,
  };

  builders.forEach((name, make) {
    test(
      '$name keeps every certification when the list overflows a page',
      () async {
        const count = 24;
        final text = pdfVisibleText(
          await make().buildPdf(
            dives: [dive],
            pageSize: PdfPageSize.a4,
            dates: dates,
            units: units,
            certifications: manyCerts(count),
          ),
        );

        expect(text, contains('Specialty0'));
        expect(
          text,
          contains('Specialty${count - 1}'),
          reason: 'the last certification was dropped off the end of the page',
        );
      },
    );
  });

  test('the certification card carries agency, number and dates', () async {
    final text = pdfVisibleText(
      await PdfTemplateDetailed().buildPdf(
        dives: [dive],
        pageSize: PdfPageSize.a4,
        dates: dates,
        units: units,
        certifications: manyCerts(1),
      ),
    );

    expect(text, contains('CARD-0'), reason: 'certification number');
    expect(text, contains('01/01/2019'), reason: 'issue date');
    expect(text, contains('30/06/2030'), reason: 'expiry date');
  });
}
