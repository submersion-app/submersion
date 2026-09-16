import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/core/constants/pdf_templates.dart';
import 'package:submersion/core/constants/units.dart';
import 'package:submersion/core/services/pdf_templates/pdf_date_formatter.dart';
import 'package:submersion/core/services/pdf_templates/pdf_template_padi.dart';
import 'package:submersion/core/utils/unit_formatter.dart';
import 'package:submersion/features/dive_log/domain/entities/dive.dart';
import 'package:submersion/features/settings/presentation/providers/settings_providers.dart';

import '../../../helpers/dive_participants.dart';
import '../../../helpers/pdf_text.dart';

/// Issue #1861: the PADI logbook's sign-off row read only the legacy `buddy` /
/// `diveMaster` scalars, so a dive whose team was linked through the buddy
/// picker printed a blank Buddy and "Verified by".
void main() {
  Future<String> renderText(Dive dive) async => pdfVisibleText(
    await PdfTemplatePadi().buildPdf(
      dives: [dive],
      pageSize: PdfPageSize.a4,
      dates: PdfDateFormatter(
        dateFormat: DateFormatPreference.yyyymmdd,
        timeFormat: TimeFormat.twentyFourHour,
      ),
      units: const UnitFormatter(AppSettings()),
    ),
  );

  test('the sign-off row names the linked buddy and guides', () async {
    final text = await renderText(diveWithLinkedTeam());

    expect(text, contains('Buddy: Ana'));
    expect(text, contains('Verified by: Gil, Mia'));
  });

  test(
    'a linked team is authoritative over the stale legacy scalars',
    () async {
      final text = await renderText(diveWithLinkedTeam());

      expect(text, isNot(contains('Stalebuddy')));
      expect(text, isNot(contains('Staledm')));
    },
  );

  test('a dive with no linked team falls back to the legacy scalars', () async {
    final text = await renderText(diveWithLegacyScalarsOnly());

    expect(text, contains('Buddy: Oldbuddy'));
    expect(text, contains('Verified by: Olddm'));
  });
}
