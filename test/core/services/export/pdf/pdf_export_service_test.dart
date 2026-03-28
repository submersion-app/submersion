import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/core/services/export/pdf/pdf_export_service.dart';
import 'package:submersion/features/dive_log/domain/entities/dive.dart';

import '../../../../helpers/test_database.dart';

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

      final result = await service.generateDivePdfBytes(dives);

      expect(result.bytes, isNotEmpty);
      expect(result.fileName, contains('.pdf'));
      // PDF files start with %PDF
      expect(String.fromCharCodes(result.bytes.take(4)), '%PDF');
    });

    test('generates PDF with null bottomTime', () async {
      final dives = [makeDive(id: 'd1', diveNumber: 1, maxDepth: 20.0)];

      final result = await service.generateDivePdfBytes(dives);

      expect(result.bytes, isNotEmpty);
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

      final result = await service.generateDivePdfBytes(dives);

      expect(result.bytes, isNotEmpty);
      expect(result.bytes.length, greaterThan(1000));
    });
  });
}
