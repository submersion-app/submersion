import 'dart:typed_data';

import 'package:fit_tool/fit_tool.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/features/dive_import/data/services/fit_parser_service.dart';
import 'package:submersion/features/universal_import/data/models/import_enums.dart';
import 'package:submersion/features/universal_import/data/models/import_warning.dart';
import 'package:submersion/features/universal_import/data/parsers/fit_import_parser.dart';

/// Builds a FIT activity with a session but no depth records, the shape of a
/// Garmin dive logged without a recorded profile (#1605).
///
/// [product] defaults to 4536, the Fenix 8, which is the watch the report
/// came from. [sport] exists so a test can prove the sport filter is still
/// what rejects a non-dive file, now that an empty profile no longer does.
Uint8List buildProfilelessFitFile({
  required DateTime startTime,
  int durationSeconds = 2400,
  double? summaryMaxDepth,
  double? summaryAvgDepth,
  int? diveNumber,
  double? bottomTime,
  int product = 4536,
  Sport sport = Sport.diving,
}) {
  final builder = FitFileBuilder(autoDefine: true, minStringSize: 50);

  builder.add(
    FileIdMessage()
      ..type = FileType.activity
      ..manufacturer = 1
      ..product = product
      ..serialNumber = 3399112233
      ..timeCreated = startTime.millisecondsSinceEpoch,
  );

  if (summaryMaxDepth != null ||
      summaryAvgDepth != null ||
      diveNumber != null ||
      bottomTime != null) {
    final summary = DiveSummaryMessage();
    if (summaryMaxDepth != null) summary.maxDepth = summaryMaxDepth;
    if (summaryAvgDepth != null) summary.avgDepth = summaryAvgDepth;
    if (diveNumber != null) summary.diveNumber = diveNumber;
    if (bottomTime != null) summary.bottomTime = bottomTime;
    builder.add(summary);
  }

  builder.add(
    SessionMessage()
      ..sport = sport
      ..timestamp = startTime
          .add(Duration(seconds: durationSeconds))
          .millisecondsSinceEpoch
      ..startTime = startTime.millisecondsSinceEpoch
      ..totalElapsedTime = durationSeconds.toDouble()
      ..totalTimerTime = durationSeconds.toDouble(),
  );

  return builder.build().toBytes();
}

void main() {
  const service = FitParserService();
  final start = DateTime.utc(2026, 8, 30, 9, 15);

  group('a dive with no recorded profile (#1605)', () {
    test('imports with its depth taken from the dive summary', () async {
      final bytes = buildProfilelessFitFile(
        startTime: start,
        summaryMaxDepth: 18.4,
        summaryAvgDepth: 11.2,
        diveNumber: 42,
        bottomTime: 2280,
      );

      final dive = await service.parseFitFile(bytes);

      expect(dive, isNotNull);
      expect(dive!.profile, isEmpty);
      expect(dive.maxDepth, closeTo(18.4, 0.001));
      expect(dive.avgDepth, closeTo(11.2, 0.001));
      expect(dive.durationSeconds, 2400);
      expect(dive.diveNumber, 42);
      expect(dive.bottomTimeSeconds, 2280);
    });

    test('names the watch that recorded it', () async {
      final bytes = buildProfilelessFitFile(
        startTime: start,
        summaryMaxDepth: 12.0,
      );

      final dive = await service.parseFitFile(bytes);

      expect(dive!.computerModel, 'Fenix 8');
    });

    test('still imports when no depth was recorded anywhere', () async {
      final bytes = buildProfilelessFitFile(startTime: start);

      final dive = await service.parseFitFile(bytes);

      expect(dive, isNotNull);
      expect(dive!.maxDepth, 0.0);
      expect(dive.avgDepth, isNull);
      expect(dive.minTemperature, isNull);
      expect(dive.avgHeartRate, isNull);
      expect(dive.durationSeconds, 2400);
    });

    test('a non-dive activity without records is still rejected', () async {
      // Sport is now the only thing standing between this file and an
      // import: flip it to Sport.diving and the test above shows it parses.
      final bytes = buildProfilelessFitFile(
        startTime: start,
        summaryMaxDepth: 12.0,
        sport: Sport.running,
      );

      expect(await service.parseFitFile(bytes), isNull);
    });

    test(
      'reaches the import payload without the parse-failure error',
      () async {
        final bytes = buildProfilelessFitFile(
          startTime: start,
          summaryMaxDepth: 18.4,
        );

        final payload = await const FitImportParser().parse(bytes);

        expect(
          payload.warnings.where(
            (w) => w.severity == ImportWarningSeverity.error,
          ),
          isEmpty,
        );
        final dives = payload.entities[ImportEntityType.dives]!;
        expect(dives, hasLength(1));
        expect(dives.single['maxDepth'], closeTo(18.4, 0.001));
        expect(dives.single.containsKey('profile'), isFalse);
      },
    );
  });
}
