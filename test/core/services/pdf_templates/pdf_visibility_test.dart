import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/core/constants/pdf_templates.dart';
import 'package:submersion/core/constants/units.dart';
import 'package:submersion/core/services/pdf_templates/pdf_date_formatter.dart';
import 'package:submersion/core/constants/enums.dart' as enums;
import 'package:submersion/core/services/pdf_templates/pdf_template_naui.dart';
import 'package:submersion/core/services/pdf_templates/pdf_template_padi.dart';
import 'package:submersion/core/services/pdf_templates/pdf_template_professional.dart';
import 'package:submersion/features/dive_log/domain/entities/dive.dart';

/// Existing coverage pins the historical ISO rendering; #964 preference
/// coverage lives in pdf_date_preference_test.dart.
final isoDates = PdfDateFormatter(
  dateFormat: DateFormatPreference.yyyymmdd,
  timeFormat: TimeFormat.twentyFourHour,
);

void main() {
  Dive buildDive({double? visibilityMeters, enums.Visibility? visibility}) =>
      Dive(
        id: 'dive-vis',
        diveNumber: 1,
        dateTime: DateTime(2026, 3, 28, 10, 0),
        bottomTime: const Duration(minutes: 45),
        runtime: const Duration(minutes: 50),
        maxDepth: 25.0,
        avgDepth: 18.0,
        waterTemp: 22.0,
        visibilityMeters: visibilityMeters,
        visibility: visibility,
        tanks: const [],
        profile: const [],
        equipment: const [],
        notes: '',
        photoIds: const [],
        sightings: const [],
        weights: const [],
        tags: const [],
      );

  // The three logbook templates that print a visibility field. Each renders a
  // measured distance from v144 and falls back to a pre-v144 bucket label.
  final templates = <String, Future<List<int>> Function(List<Dive>)>{
    'PADI': (dives) => PdfTemplatePadi().buildPdf(
      dives: dives,
      pageSize: PdfPageSize.a4,
      dates: isoDates,
    ),
    'NAUI': (dives) => PdfTemplateNaui().buildPdf(
      dives: dives,
      pageSize: PdfPageSize.a4,
      dates: isoDates,
    ),
    'Professional': (dives) => PdfTemplateProfessional().buildPdf(
      dives: dives,
      pageSize: PdfPageSize.a4,
      dates: isoDates,
    ),
  };

  for (final entry in templates.entries) {
    group('${entry.key} template visibility', () {
      test('renders a measured distance', () async {
        final bytes = await entry.value([buildDive(visibilityMeters: 6.0)]);
        expect(bytes, isNotEmpty);
      });

      test('falls back to a legacy bucket label', () async {
        final bytes = await entry.value([
          buildDive(visibility: enums.Visibility.moderate),
        ]);
        expect(bytes, isNotEmpty);
      });

      test('renders a dive with no visibility at all', () async {
        final bytes = await entry.value([buildDive()]);
        expect(bytes, isNotEmpty);
      });
    });
  }
}
