import 'dart:io';

import 'package:flutter/services.dart';
import 'package:intl/intl.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/core/constants/enums.dart';
import 'package:submersion/core/constants/units.dart';
import 'package:submersion/core/services/export/pdf/pdf_course_export_service.dart';
import 'package:submersion/core/services/pdf_templates/pdf_date_formatter.dart';
import 'package:submersion/features/courses/domain/entities/course.dart';
import 'package:submersion/features/dive_log/domain/entities/dive.dart';

import '../../../../helpers/pdf_text.dart';
import '../../../../helpers/test_database.dart';

/// The course training log must report total *runtime*, not bottom time (#644).
/// The historical ISO rendering these tests were written against; the diver's
/// own date and time preferences are covered in pdf_date_preference_test.dart.
final isoDates = PdfDateFormatter(
  dateFormat: DateFormatPreference.yyyymmdd,
  timeFormat: TimeFormat.twentyFourHour,
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
  }) => Dive(
    id: id,
    diveNumber: number,
    dateTime: DateTime(2026, 5, 27 + number, 9),
    runtime: runtime,
    bottomTime: bottomTime,
    maxDepth: maxDepth,
  );

  /// Runs the export and returns the visible text of the generated PDF.
  Future<String> exportText(List<Dive> dives) async {
    final path = await service.exportCourseTrainingLogToPdf(
      course,
      dives,
      dates: isoDates,
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
}
