import 'dart:io';

import 'package:flutter/services.dart';
import 'package:intl/intl.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/core/constants/enums.dart';
import 'package:submersion/core/constants/units.dart';
import 'package:submersion/core/services/export/pdf/pdf_course_export_service.dart';
import 'package:submersion/core/services/pdf_templates/pdf_date_formatter.dart';
import 'package:submersion/core/utils/unit_formatter.dart';
import 'package:submersion/features/courses/domain/entities/course.dart';
import 'package:submersion/features/dive_log/domain/entities/dive.dart';
import 'package:submersion/features/settings/presentation/providers/settings_providers.dart';

import '../../../../helpers/pdf_text.dart';
import '../../../../helpers/test_database.dart';

/// The course training log must report total *runtime*, not bottom time (#644).
/// The historical ISO rendering these tests were written against; the diver's
/// own date and time preferences are covered in pdf_date_preference_test.dart.
final isoDates = PdfDateFormatter(
  dateFormat: DateFormatPreference.yyyymmdd,
  timeFormat: TimeFormat.twentyFourHour,
);

const metric = UnitFormatter(AppSettings());
const imperial = UnitFormatter(
  AppSettings(
    depthUnit: DepthUnit.feet,
    temperatureUnit: TemperatureUnit.fahrenheit,
  ),
);

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late Directory shareDir;
  late PdfCourseExportService service;

  setUpAll(() async {
    shareDir = await Directory.systemTemp.createTemp('course_pdf_test_');
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

  setUp(() async {
    await setUpTestDatabase();
    service = PdfCourseExportService();
  });

  tearDown(() async {
    await tearDownTestDatabase();
  });

  final course = Course(
    id: 'course-1',
    diverId: 'diver-1',
    name: 'Advanced Open Water',
    agency: CertificationAgency.padi,
    startDate: DateTime(2026, 5, 27),
    completionDate: DateTime(2026, 5, 29),
    instructorName: 'Jane Instructor',
    createdAt: DateTime(2026, 5, 27),
    updatedAt: DateTime(2026, 5, 29),
  );

  Dive trainingDive({
    required String id,
    required int number,
    Duration? runtime,
    Duration? bottomTime,
    double? maxDepth,
    double? waterTemp,
  }) => Dive(
    id: id,
    diveNumber: number,
    dateTime: DateTime(2026, 5, 27 + number, 9),
    runtime: runtime,
    bottomTime: bottomTime,
    maxDepth: maxDepth,
    waterTemp: waterTemp,
  );

  /// Runs the export and returns the visible text of the generated PDF.
  Future<String> exportText(
    List<Dive> dives, {
    UnitFormatter units = metric,
  }) async {
    final path = await service.exportCourseTrainingLogToPdf(
      course,
      dives,
      dates: isoDates,
      units: units,
    );
    final bytes = await File(path).readAsBytes();
    expect(String.fromCharCodes(bytes.take(4)), '%PDF');
    return pdfVisibleText(bytes);
  }

  test('Total Minutes sums runtime, not bottom time', () async {
    final text = await exportText([
      trainingDive(
        id: 'd1',
        number: 1,
        runtime: const Duration(minutes: 62),
        bottomTime: const Duration(minutes: 50),
        maxDepth: 25.0,
      ),
      trainingDive(
        id: 'd2',
        number: 2,
        bottomTime: const Duration(minutes: 40),
        maxDepth: 18.0,
      ),
    ]);

    expect(
      text,
      contains('102 Total Minutes'),
      reason:
          'runtime 62 + bottomTime fallback 40 = 102; bottom time alone '
          'would understate the training log at 90 (#644)',
    );
    expect(text, contains('2 Training Dives'));
    expect(text, contains('25.0m Max Depth'));
  });

  test('per-dive Duration chip prints runtime, not bottom time', () async {
    final text = await exportText([
      trainingDive(
        id: 'd1',
        number: 1,
        runtime: const Duration(minutes: 62),
        bottomTime: const Duration(minutes: 50),
        maxDepth: 25.0,
      ),
    ]);

    expect(text, contains('Duration 62 min'));
    expect(text, isNot(contains('50 min')));
  });

  test('a runtime-only dive still gets a Duration chip', () async {
    // Before #644 the chip was gated on bottomTime, so a dive logged with only
    // a runtime rendered no duration at all.
    final text = await exportText([
      trainingDive(id: 'd1', number: 1, runtime: const Duration(minutes: 47)),
    ]);

    expect(text, contains('Duration 47 min'));
    expect(text, contains('47 Total Minutes'));
  });

  test('course dates follow the diver\'s preferences (#964)', () async {
    final path = await service.exportCourseTrainingLogToPdf(
      course,
      [
        Dive(
          id: 'd1',
          diveNumber: 1,
          dateTime: DateTime(2026, 5, 28, 14, 30),
          runtime: const Duration(minutes: 47),
        ),
      ],
      dates: PdfDateFormatter(
        dateFormat: DateFormatPreference.ddmmyyyy,
        timeFormat: TimeFormat.twelveHour,
      ),
      units: metric,
    );

    final text = pdfVisibleText(await File(path).readAsBytes());
    // Course start date on the cover, dive date and time on the entry.
    expect(text, contains('27/05/2026'));
    expect(text, contains('28/05/2026'));
    expect(text, contains('2:30'));
    expect(text, contains('PM'));
    expect(text, isNot(contains('2026-05-27')));
    expect(text, isNot(contains('14:30')));

    expect(
      path,
      contains(DateFormat('yyyy-MM-dd').format(DateTime.now())),
      reason: 'the file name stays ISO so training logs sort by date (#964)',
    );
  });

  test('a dive with no duration at all renders no Duration chip', () async {
    final text = await exportText([
      trainingDive(id: 'd1', number: 1, maxDepth: 12.0),
    ]);

    expect(text, isNot(contains('Duration')));
    expect(text, contains('0 Total Minutes'));
  });

  // The Course Notes page used to be a fixed pw.Page, which never paginates:
  // notes taller than the sheet were dropped from the export.
  test('course notes longer than a page continue onto another sheet', () async {
    final longNotes = List.generate(
      400,
      (i) => 'Sentence $i of a very long course debrief.',
    ).join(' ');
    final path = await service.exportCourseTrainingLogToPdf(
      course.copyWith(notes: longNotes),
      [trainingDive(id: 'd1', number: 1, maxDepth: 12.0)],
      dates: isoDates,
      units: metric,
    );
    final bytes = await File(path).readAsBytes();

    final text = pdfVisibleText(bytes);
    expect(text, contains('Course Notes'));
    expect(text, contains('Sentence 0 of'));
    expect(
      text,
      contains('Sentence 399 of'),
      reason: 'the tail of the course notes must not be dropped',
    );
    expect(
      pdfPageCount(bytes),
      greaterThan(3),
      reason: 'cover, one dive page, and notes that need more than one sheet',
    );
  });

  group('dive depth and temperature follow the diver\'s units', () {
    List<Dive> dives() => [
      trainingDive(
        id: 'd1',
        number: 1,
        runtime: const Duration(minutes: 47),
        maxDepth: 30.0,
        waterTemp: 20.0,
      ),
    ];

    test('renders feet and fahrenheit for an imperial diver', () async {
      final text = await exportText(dives(), units: imperial);

      expect(
        text,
        contains('98.4ft Max Depth'),
        reason: 'cover stat box: 30 m is 98.4 ft',
      );
      expect(text, contains('Max Depth 98.4ft'), reason: 'per-dive chip');
      expect(text, contains('Water Temp 68°F'), reason: '20 C is 68 F');
      expect(text, isNot(contains('30.0m')));
      expect(text, isNot(contains('°C')));
    });

    test('renders meters and celsius for a metric diver', () async {
      final text = await exportText(dives());

      expect(text, contains('30.0m Max Depth'));
      expect(text, contains('Max Depth 30.0m'));
      expect(text, contains('Water Temp 20°C'));
      expect(text, isNot(contains('ft')));
      expect(text, isNot(contains('°F')));
    });
  });
}
