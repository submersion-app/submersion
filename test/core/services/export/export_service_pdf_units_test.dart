import 'dart:io';

import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/core/constants/enums.dart';
import 'package:submersion/core/constants/units.dart';
import 'package:submersion/core/services/export/export_service.dart';
import 'package:submersion/core/services/export/shared/file_export_utils.dart';
import 'package:submersion/core/services/pdf_templates/pdf_date_formatter.dart';
import 'package:submersion/core/utils/unit_formatter.dart';
import 'package:submersion/features/courses/domain/entities/course.dart';
import 'package:submersion/features/dive_log/domain/entities/dive.dart';
import 'package:submersion/features/settings/presentation/providers/settings_providers.dart';
import 'package:submersion/features/trips/domain/entities/trip.dart';

import '../../../helpers/pdf_text.dart';
import '../../../helpers/test_database.dart';

/// The ExportService facade must hand the diver's units through to the trip
/// report and course training log PDFs, not just the underlying services.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late Directory shareDir;

  final dates = PdfDateFormatter(
    dateFormat: DateFormatPreference.yyyymmdd,
    timeFormat: TimeFormat.twentyFourHour,
  );
  const imperial = UnitFormatter(
    AppSettings(
      depthUnit: DepthUnit.feet,
      temperatureUnit: TemperatureUnit.fahrenheit,
    ),
  );

  final dive = Dive(
    id: 'd1',
    diveNumber: 1,
    dateTime: DateTime(2026, 5, 2, 9),
    runtime: const Duration(minutes: 47),
    maxDepth: 30.0,
    waterTemp: 20.0,
  );

  setUpAll(() async {
    shareDir = await Directory.systemTemp.createTemp('export_pdf_units_');
    final messenger =
        TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;
    messenger.setMockMethodCallHandler(
      const MethodChannel('plugins.flutter.io/path_provider'),
      (call) async => call.method == 'getApplicationDocumentsDirectory'
          ? shareDir.path
          : null,
    );
    messenger.setMockMethodCallHandler(
      const MethodChannel('dev.fluttercommunity.plus/share'),
      (call) async => null,
    );
  });

  tearDownAll(() async {
    if (await shareDir.exists()) await shareDir.delete(recursive: true);
  });

  setUp(() async {
    debugCanShareFiles = true;
    await setUpTestDatabase();
  });

  tearDown(() async {
    debugCanShareFiles = null;
    await tearDownTestDatabase();
  });

  test('exportTripToPdf passes the units through', () async {
    final trip = Trip(
      id: 'trip-1',
      name: 'Red Sea 2026',
      startDate: DateTime(2026, 5, 1),
      endDate: DateTime(2026, 5, 8),
      createdAt: DateTime(2026, 4, 1),
      updatedAt: DateTime(2026, 5, 9),
    );

    final path = await ExportService().exportTripToPdf(
      trip,
      [dive],
      dates: dates,
      units: imperial,
    );

    final text = pdfVisibleText(await File(path).readAsBytes());
    expect(text, contains('Max Depth: 98.4ft'));
    expect(text, contains('Water Temp: 68°F'));
  });

  test('exportCourseTrainingLogToPdf passes the units through', () async {
    final course = Course(
      id: 'course-1',
      diverId: 'diver-1',
      name: 'Advanced Open Water',
      agency: CertificationAgency.padi,
      startDate: DateTime(2026, 5, 1),
      createdAt: DateTime(2026, 5, 1),
      updatedAt: DateTime(2026, 5, 2),
    );

    final path = await ExportService().exportCourseTrainingLogToPdf(
      course,
      [dive],
      dates: dates,
      units: imperial,
    );

    final text = pdfVisibleText(await File(path).readAsBytes());
    expect(text, contains('98.4ft Max Depth'));
    expect(text, contains('Max Depth 98.4ft'));
    expect(text, contains('Water Temp 68°F'));
  });
}
