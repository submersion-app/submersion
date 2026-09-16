import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/core/constants/enums.dart';
import 'package:submersion/core/constants/pdf_templates.dart';
import 'package:submersion/core/constants/units.dart';
import 'package:submersion/core/services/pdf_templates/pdf_date_formatter.dart';
import 'package:submersion/core/services/pdf_templates/pdf_template_padi.dart';
import 'package:submersion/core/utils/unit_formatter.dart';
import 'package:submersion/features/dive_log/domain/entities/dive.dart';
import 'package:submersion/features/dive_sites/domain/entities/dive_site.dart';
import 'package:submersion/features/settings/presentation/providers/settings_providers.dart';

import '../../../helpers/pdf_text.dart';

/// Issue #793: a dive logged before its site had a water type (or whose site
/// gained one later) still carries `waterType: null`. The PADI logbook should
/// show the site's water type in that case, like the dive detail page does.
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

  test('falls back to the site\'s water type when the dive has none', () async {
    final dive = Dive(
      id: 'd1',
      dateTime: DateTime(2026, 8, 17, 11, 7),
      site: const DiveSite(
        id: 'site-1',
        name: 'Blue Hole',
        waterType: WaterType.fresh,
      ),
    );

    final text = await renderText(dive);

    expect(text, contains(WaterType.fresh.displayName));
  });

  test('a dive\'s own water type is authoritative over the site\'s', () async {
    final dive = Dive(
      id: 'd1',
      dateTime: DateTime(2026, 8, 17, 11, 7),
      waterType: WaterType.brackish,
      site: const DiveSite(
        id: 'site-1',
        name: 'Blue Hole',
        waterType: WaterType.fresh,
      ),
    );

    final text = await renderText(dive);

    expect(text, contains(WaterType.brackish.displayName));
    expect(text, isNot(contains(WaterType.fresh.displayName)));
  });
}
