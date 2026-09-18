import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/core/constants/pdf_templates.dart';
import 'package:submersion/core/constants/units.dart';
import 'package:submersion/core/services/pdf_templates/pdf_date_formatter.dart';
import 'package:submersion/core/services/pdf_templates/pdf_template_detailed.dart';
import 'package:submersion/core/utils/unit_formatter.dart';
import 'package:submersion/features/dive_log/domain/entities/dive.dart';
import 'package:submersion/features/dive_log/domain/entities/dive_custom_field.dart';
import 'package:submersion/features/settings/presentation/providers/settings_providers.dart';

import '../../../helpers/pdf_text.dart';

/// Custom field values and sighting notes are free text, but both were laid
/// out inside a pw.Row. A Row can never span pages, so one value taller than
/// a page body threw "Widget won't fit into the page" and failed the whole
/// Detailed export, the same failure #2056 fixed for the dive notes.
void main() {
  final dive = Dive(
    id: 'd1',
    diveNumber: 197,
    dateTime: DateTime(2026, 8, 17, 11, 7),
    runtime: const Duration(minutes: 26),
    maxDepth: 9.8,
  );

  final dates = PdfDateFormatter(
    dateFormat: DateFormatPreference.ddmmyyyy,
    timeFormat: TimeFormat.twentyFourHour,
  );
  const units = UnitFormatter(AppSettings());

  Future<List<int>> render(Dive d, PdfPageSize pageSize) =>
      PdfTemplateDetailed().buildPdf(
        dives: [d],
        pageSize: pageSize,
        dates: dates,
        units: units,
      );

  /// Prose far taller than any page body.
  final pageLongText = List.generate(
    400,
    (i) => 'Sentence $i of a very long entry.',
  ).join(' ');

  /// Few characters but one line each, so it is tall without being long.
  final manyShortLines = List.generate(90, (i) => 'Line$i').join('\n');

  for (final pageSize in PdfPageSize.values) {
    group('on $pageSize', () {
      test(
        'a custom field value longer than a page is printed in full',
        () async {
          final bytes = await render(
            dive.copyWith(
              customFields: [
                DiveCustomField(id: 'f1', key: 'Debrief', value: pageLongText),
              ],
            ),
            pageSize,
          );

          final text = pdfVisibleText(bytes);
          expect(text, contains('Debrief'));
          expect(text, contains('Sentence 0 of'));
          expect(
            text,
            contains('Sentence 399 of'),
            reason: 'the tail of the value must land on a continuation sheet',
          );
          expect(pdfPageCount(bytes), greaterThan(1));
        },
      );

      test(
        'a custom field value of many short lines is printed in full',
        () async {
          final text = pdfVisibleText(
            await render(
              dive.copyWith(
                customFields: [
                  DiveCustomField(
                    id: 'f1',
                    key: 'Checklist',
                    value: manyShortLines,
                  ),
                ],
              ),
              pageSize,
            ),
          );

          expect(text, contains('Line0'));
          expect(text, contains('Line89'));
        },
      );

      test('a sighting note longer than a page is printed in full', () async {
        final bytes = await render(
          dive.copyWith(
            sightings: [
              MarineSighting(
                id: 's1',
                speciesId: 'sp1',
                speciesName: 'Green Sea Turtle',
                count: 2,
                notes: pageLongText,
              ),
            ],
          ),
          pageSize,
        );

        final text = pdfVisibleText(bytes);
        expect(text, contains('Green Sea Turtle x2'));
        expect(text, contains('Sentence 0 of'));
        expect(
          text,
          contains('Sentence 399 of'),
          reason: 'the tail of the note must land on a continuation sheet',
        );
        expect(pdfPageCount(bytes), greaterThan(1));
      });

      test('a sighting note of many short lines is printed in full', () async {
        final text = pdfVisibleText(
          await render(
            dive.copyWith(
              sightings: [
                MarineSighting(
                  id: 's1',
                  speciesId: 'sp1',
                  speciesName: 'Green Sea Turtle',
                  notes: manyShortLines,
                ),
              ],
            ),
            pageSize,
          ),
        );

        expect(text, contains('Line0'));
        expect(text, contains('Line89'));
      });
    });
  }
}
