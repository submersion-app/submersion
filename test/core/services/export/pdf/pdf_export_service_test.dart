import 'package:flutter_test/flutter_test.dart';
import 'package:intl/intl.dart';
import 'package:submersion/core/constants/units.dart';
import 'package:submersion/core/services/export/pdf/pdf_export_service.dart';
import 'package:submersion/core/services/pdf_templates/pdf_date_formatter.dart';
import 'package:submersion/features/dive_log/domain/entities/dive.dart';

import '../../../../helpers/pdf_text.dart';
import '../../../../helpers/test_database.dart';

/// The historical ISO rendering these tests were written against; the diver's
/// own date and time preferences are covered in pdf_date_preference_test.dart.
final isoDates = PdfDateFormatter(
  dateFormat: DateFormatPreference.yyyymmdd,
  timeFormat: TimeFormat.twentyFourHour,
);

void main() {
  late PdfExportService service;

  setUp(() async {
    await setUpTestDatabase();
    service = PdfExportService();
  });

  tearDown(() async {
    await tearDownTestDatabase();
  });

  Dive makeDive({
    String id = 'dive-1',
    int? diveNumber,
    DateTime? dateTime,
    Duration? bottomTime,
    Duration? runtime,
    double? maxDepth,
    double? avgDepth,
    double? waterTemp,
  }) {
    return Dive(
      id: id,
      diveNumber: diveNumber,
      dateTime: dateTime ?? DateTime(2026, 3, 28, 10, 0),
      bottomTime: bottomTime,
      runtime: runtime,
      maxDepth: maxDepth,
      avgDepth: avgDepth,
      waterTemp: waterTemp,
      tanks: const [],
      profile: const [],
      equipment: const [],
      notes: '',
      photoIds: const [],
      sightings: const [],
      weights: const [],
      tags: const [],
    );
  }

  group('generateDivePdfBytes with tank pressure data', () {
    test('generates PDF with tank start/end pressure values', () async {
      final dives = [
        Dive(
          id: 'dive-tank-1',
          diveNumber: 1,
          dateTime: DateTime(2026, 3, 28, 10, 0),
          bottomTime: const Duration(minutes: 45),
          maxDepth: 25.0,
          waterTemp: 22.0,
          tanks: const [
            DiveTank(
              id: 'tank-1',
              startPressure: 206.843,
              endPressure: 50.5,
              volume: 11.1,
            ),
          ],
          profile: const [],
          equipment: const [],
          notes: '',
          photoIds: const [],
          sightings: const [],
          weights: const [],
          tags: const [],
        ),
      ];

      final result = await service.generateDivePdfBytes(dives, dates: isoDates);
      expect(result.bytes, isNotEmpty);
      expect(String.fromCharCodes(result.bytes.take(4)), '%PDF');
    });
  });

  group('generateDivePdfBytes', () {
    test('generates PDF with bottomTime data', () async {
      final dives = [
        makeDive(
          id: 'd1',
          diveNumber: 1,
          bottomTime: const Duration(minutes: 45),
          runtime: const Duration(minutes: 50),
          maxDepth: 25.0,
          waterTemp: 22.0,
        ),
        makeDive(
          id: 'd2',
          diveNumber: 2,
          bottomTime: const Duration(minutes: 30),
          maxDepth: 18.0,
          waterTemp: 24.0,
          dateTime: DateTime(2026, 3, 29, 10, 0),
        ),
      ];

      final result = await service.generateDivePdfBytes(dives, dates: isoDates);

      expect(result.bytes, isNotEmpty);
      expect(result.fileName, contains('.pdf'));
      // PDF files start with %PDF
      expect(String.fromCharCodes(result.bytes.take(4)), '%PDF');
    });

    test('generates PDF with null bottomTime', () async {
      final dives = [makeDive(id: 'd1', diveNumber: 1, maxDepth: 20.0)];

      final result = await service.generateDivePdfBytes(dives, dates: isoDates);

      expect(result.bytes, isNotEmpty);
    });

    test(
      'renders dates and times in the diver\'s preferences (#964)',
      () async {
        final result = await service.generateDivePdfBytes(
          [
            makeDive(
              id: 'd1',
              diveNumber: 1,
              maxDepth: 25.0,
              dateTime: DateTime(2026, 3, 28, 14, 30),
            ),
          ],
          dates: PdfDateFormatter(
            dateFormat: DateFormatPreference.ddmmyyyy,
            timeFormat: TimeFormat.twelveHour,
          ),
        );

        final text = pdfVisibleText(result.bytes);
        expect(text, contains('28/03/2026'));
        expect(text, contains('2:30'));
        expect(text, contains('PM'));
        expect(text, isNot(contains('2026-03-28')));
        expect(text, isNot(contains('14:30')));
      },
    );

    test('keeps the file name ISO so exports stay sortable', () async {
      final result = await service.generateDivePdfBytes(
        [makeDive(id: 'd1', diveNumber: 1, maxDepth: 20.0)],
        dates: PdfDateFormatter(
          dateFormat: DateFormatPreference.ddmmyyyy,
          timeFormat: TimeFormat.twelveHour,
        ),
      );

      expect(
        result.fileName,
        'dive_logbook_${DateFormat('yyyy-MM-dd').format(DateTime.now())}.pdf',
        reason:
            'the document text follows the diver, but a folder of exports has '
            'to sort chronologically (#964)',
      );
    });

    test('generates PDF with many dives for summary page', () async {
      final dives = List.generate(
        5,
        (i) => makeDive(
          id: 'dive-$i',
          diveNumber: i + 1,
          bottomTime: Duration(minutes: 30 + i * 5),
          maxDepth: 15.0 + i * 3,
          waterTemp: 20.0 + i,
          dateTime: DateTime(2026, 3, 20 + i, 10, 0),
        ),
      );

      final result = await service.generateDivePdfBytes(dives, dates: isoDates);

      expect(result.bytes, isNotEmpty);
      expect(result.bytes.length, greaterThan(1000));
    });
  });
}
