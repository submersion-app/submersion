import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/core/constants/enums.dart';
import 'package:submersion/core/constants/units.dart';
import 'package:submersion/core/services/export/shared/file_export_utils.dart';
import 'package:submersion/features/courses/domain/entities/course.dart';
import 'package:submersion/features/courses/domain/entities/course_progress.dart';
import 'package:submersion/features/courses/presentation/pages/course_detail_page.dart';
import 'package:submersion/features/courses/presentation/providers/course_providers.dart';
import 'package:submersion/features/courses/presentation/providers/course_requirement_providers.dart';
import 'package:submersion/features/dive_log/domain/entities/dive.dart';
import 'package:submersion/features/settings/presentation/providers/settings_providers.dart';

import '../../../../helpers/mock_providers.dart';
import '../../../../helpers/pdf_text.dart';
import '../../../../helpers/test_app.dart';
import '../../../../helpers/test_database.dart';
import '../../../../helpers/temp_dir.dart';

/// Exporting a training log from the course page must render depth and
/// temperature in the active diver's units, not hardcoded metric.
void main() {
  late Directory shareDir;

  final course = Course(
    id: 'course-1',
    diverId: 'diver-1',
    name: 'Advanced Open Water',
    agency: CertificationAgency.padi,
    startDate: DateTime(2026, 5, 27),
    createdAt: DateTime(2026, 5, 27),
    updatedAt: DateTime(2026, 5, 28),
  );

  final dive = Dive(
    id: 'd1',
    diveNumber: 1,
    dateTime: DateTime(2026, 5, 28, 9),
    runtime: const Duration(minutes: 47),
    maxDepth: 30.0,
    waterTemp: 20.0,
  );

  const imperialSettings = AppSettings(
    depthUnit: DepthUnit.feet,
    temperatureUnit: TemperatureUnit.fahrenheit,
  );

  File? exportedPdf() {
    final matches = shareDir.listSync().whereType<File>().where(
      (f) =>
          f.path.contains('training_log_') &&
          f.path.endsWith('.pdf') &&
          f.lengthSync() > 0,
    );
    return matches.isEmpty ? null : matches.first;
  }

  Future<void> pumpFrames(WidgetTester tester) async {
    for (var i = 0; i < 5; i++) {
      await tester.pump(const Duration(milliseconds: 100));
    }
  }

  setUp(() async {
    shareDir = await Directory.systemTemp.createTemp('course_detail_export_');
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
    debugCanShareFiles = true;
    await setUpTestDatabase();
  });

  tearDown(() async {
    debugCanShareFiles = null;
    await tearDownTestDatabase();
    await deleteTempDir(shareDir);
  });

  testWidgets('exported training log uses the diver\'s units', (tester) async {
    await tester.pumpWidget(
      testApp(
        overrides: [
          settingsProvider.overrideWith(
            (ref) => MockSettingsNotifier(imperialSettings),
          ),
          courseByIdProvider(course.id).overrideWith((ref) async => course),
          courseDivesProvider(course.id).overrideWith((ref) async => [dive]),
          courseProgressProvider(course.id).overrideWith(
            (ref) async =>
                CourseProgress(courseId: course.id, requirements: const []),
          ),
          suggestedDivesProvider(
            course.id,
          ).overrideWith((ref) async => const []),
        ],
        child: CourseDetailPage(courseId: course.id),
      ),
    );
    // The page keeps an indefinite animation running, so pumpAndSettle would
    // never return; a few frames are enough for the overridden providers.
    await pumpFrames(tester);

    // Choose the menu's export action directly: under the test font the
    // "Export Training Log" item overflows the 256px menu, which says nothing
    // about the export itself.
    tester
        .widget<PopupMenuButton<String>>(find.byType(PopupMenuButton<String>))
        .onSelected!('export');
    await tester.pump();

    // The export does real file IO, which only completes on the real clock;
    // alternate real waits with frames until the PDF lands on disk.
    for (var i = 0; i < 200 && exportedPdf() == null; i++) {
      await tester.runAsync(
        () => Future<void>.delayed(const Duration(milliseconds: 25)),
      );
      await tester.pump();
    }

    final pdf = exportedPdf();
    expect(pdf, isNotNull, reason: 'the training log PDF was never written');
    final text = pdfVisibleText(pdf!.readAsBytesSync());
    expect(text, contains('98.4ft Max Depth'), reason: '30 m is 98.4 ft');
    expect(text, contains('Max Depth 98.4ft'));
    expect(text, contains('Water Temp 68°F'), reason: '20 C is 68 F');
    expect(text, isNot(contains('30.0m')));

    // Let the loading dialog close before the test ends.
    await pumpFrames(tester);
  });
}
