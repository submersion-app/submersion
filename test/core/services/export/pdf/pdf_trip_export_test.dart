import 'dart:io';

import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/core/services/export/pdf/pdf_export_service.dart';
import 'package:submersion/features/dive_log/domain/entities/dive.dart';
import 'package:submersion/features/trips/domain/entities/trip.dart';

import '../../../../helpers/pdf_text.dart';

/// The trip report's per-dive Duration line must print total runtime rather
/// than bottom time, matching the rest of the PDF exports (#644).
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late Directory shareDir;
  late PdfExportService service;

  setUpAll(() async {
    shareDir = await Directory.systemTemp.createTemp('trip_pdf_test_');
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(
          const MethodChannel('plugins.flutter.io/path_provider'),
          (call) async => call.method == 'getApplicationDocumentsDirectory'
              ? shareDir.path
              : null,
        );
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(
          const MethodChannel('dev.fluttercommunity.plus/share'),
          (call) async => null,
        );
  });

  tearDownAll(() async {
    if (await shareDir.exists()) await shareDir.delete(recursive: true);
  });

  setUp(() => service = PdfExportService());

  final trip = Trip(
    id: 'trip-1',
    name: 'Red Sea 2026',
    startDate: DateTime(2026, 5, 1),
    endDate: DateTime(2026, 5, 8),
    location: 'Hurghada',
    createdAt: DateTime(2026, 4, 1),
    updatedAt: DateTime(2026, 5, 9),
  );

  Future<String> exportText(List<Dive> dives) async {
    final path = await service.exportTripToPdf(trip, dives);
    final bytes = await File(path).readAsBytes();
    expect(String.fromCharCodes(bytes.take(4)), '%PDF');
    return pdfVisibleText(bytes);
  }

  test('per-dive Duration prints runtime, not bottom time', () async {
    final text = await exportText([
      Dive(
        id: 'd1',
        diveNumber: 1,
        dateTime: DateTime(2026, 5, 2, 9),
        runtime: const Duration(minutes: 62),
        bottomTime: const Duration(minutes: 50),
        maxDepth: 25.0,
      ),
    ]);

    expect(text, contains('Duration: 62 min'));
    expect(text, isNot(contains('50 min')));
  });

  test('a runtime-only dive still prints a Duration line', () async {
    // The line used to be gated on bottomTime, so runtime-only dives showed
    // no duration in the trip report at all.
    final text = await exportText([
      Dive(
        id: 'd1',
        diveNumber: 1,
        dateTime: DateTime(2026, 5, 2, 9),
        entryTime: DateTime(2026, 5, 2, 9),
        exitTime: DateTime(2026, 5, 2, 9, 47),
        maxDepth: 18.0,
      ),
    ]);

    expect(text, contains('Duration: 47 min'));
  });

  test('a dive with no duration prints no Duration line', () async {
    final text = await exportText([
      Dive(
        id: 'd1',
        diveNumber: 1,
        dateTime: DateTime(2026, 5, 2, 9),
        maxDepth: 18.0,
      ),
    ]);

    expect(text, isNot(contains('Duration:')));
    expect(text, contains('Max Depth: 18.0 m'));
  });
}
