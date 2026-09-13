import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/core/constants/pdf_templates.dart';
import 'package:submersion/core/constants/units.dart';
import 'package:submersion/core/services/pdf_templates/pdf_date_formatter.dart';
import 'package:submersion/core/services/pdf_templates/pdf_template_detailed.dart';
import 'package:submersion/core/utils/unit_formatter.dart';
import 'package:submersion/features/dive_log/domain/entities/dive.dart';
import 'package:submersion/features/dive_types/domain/entities/dive_type_entity.dart';
import 'package:submersion/features/settings/presentation/providers/settings_providers.dart';

import '../../../helpers/pdf_text.dart';

/// The detailed logbook names each dive type as the diver did, not by a name
/// rebuilt from its id (#1834).
void main() {
  Future<String> render(Map<String, DiveTypeEntity> typesById) async {
    final bytes = await PdfTemplateDetailed().buildPdf(
      dives: [
        Dive(
          id: 'd1',
          diveNumber: 1,
          dateTime: DateTime(2026, 8, 17, 11, 7),
          diveTypeIds: const ['search_recovery', 'night'],
        ),
      ],
      pageSize: PdfPageSize.a4,
      dates: PdfDateFormatter(
        dateFormat: DateFormatPreference.ddmmyyyy,
        timeFormat: TimeFormat.twentyFourHour,
      ),
      units: const UnitFormatter(AppSettings()),
      diveTypesById: typesById,
    );
    return pdfVisibleText(bytes);
  }

  test('writes a custom type under its own name', () async {
    final text = await render({
      'search_recovery': DiveTypeEntity(
        id: 'search_recovery',
        name: 'Search & Recovery',
        createdAt: DateTime(2026),
        updatedAt: DateTime(2026),
      ),
    });
    expect(text, contains('Search & Recovery, Night'));
  });

  test('rebuilds the name from the id when no row is loaded', () async {
    expect(await render(const {}), contains('Search recovery, Night'));
  });
}
