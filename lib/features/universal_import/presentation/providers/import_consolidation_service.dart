import 'package:drift/drift.dart' show Value;
import 'package:uuid/uuid.dart';

import 'package:submersion/core/database/database.dart'
    show DiveDataSourcesCompanion, DiveProfilesCompanion;
import 'package:submersion/features/dive_log/data/repositories/dive_repository_impl.dart';
import 'package:submersion/features/universal_import/data/services/import_duplicate_checker.dart';

/// Attaches consolidate-flagged imported dives as secondary computer
/// readings on matched existing dives.
///
/// Returns the number of successful consolidations.
Future<int> performConsolidations({
  required Set<int> indices,
  required List<Map<String, dynamic>> diveItems,
  required ImportDuplicateResult? duplicateResult,
  required DiveRepository diveRepository,
}) async {
  const uuid = Uuid();
  final now = DateTime.now();
  var count = 0;

  for (final index in indices) {
    final matchResult = duplicateResult?.diveMatchFor(index);
    if (matchResult == null) continue;

    final diveData = diveItems[index];
    final dateTime = diveData['dateTime'] as DateTime?;
    if (dateTime == null) continue;
    final runtime = diveData['runtime'] as Duration?;
    final duration = diveData['duration'] as Duration?;
    final effectiveDuration = runtime ?? duration;
    final exitTime = effectiveDuration != null
        ? dateTime.add(effectiveDuration)
        : null;

    final secondaryReading = DiveDataSourcesCompanion.insert(
      id: uuid.v4(),
      diveId: matchResult.diveId,
      isPrimary: const Value(false),
      computerModel: Value(diveData['diveComputerModel'] as String?),
      computerSerial: Value(diveData['diveComputerSerial'] as String?),
      sourceFormat: Value(diveData['sourceFormat'] as String?),
      maxDepth: Value(diveData['maxDepth'] as double?),
      avgDepth: Value(diveData['avgDepth'] as double?),
      duration: Value(effectiveDuration?.inSeconds),
      waterTemp: Value(diveData['waterTemp'] as double?),
      entryTime: Value(dateTime),
      exitTime: Value(exitTime),
      importedAt: now,
      createdAt: now,
    );

    final profileData =
        (diveData['profile'] as List?)?.cast<Map<String, dynamic>>() ??
        const <Map<String, dynamic>>[];
    final secondaryProfile = profileData
        .map(
          (p) => DiveProfilesCompanion.insert(
            id: uuid.v4(),
            diveId: matchResult.diveId,
            isPrimary: const Value(false),
            timestamp: p['timestamp'] as int? ?? 0,
            depth: p['depth'] as double? ?? 0.0,
            temperature: Value(p['temperature'] as double?),
            pressure: const Value(null),
            setpoint: Value(p['setpoint'] as double?),
            ppO2: Value(p['ppO2'] as double?),
          ),
        )
        .toList();

    await diveRepository.consolidateComputer(
      targetDiveId: matchResult.diveId,
      secondaryReading: secondaryReading,
      secondaryProfile: secondaryProfile,
    );
    count++;
  }

  return count;
}
