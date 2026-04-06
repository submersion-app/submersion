import 'package:drift/drift.dart' show Value;
import 'package:uuid/uuid.dart';

import 'package:submersion/core/database/database.dart'
    show DiveDataSourcesCompanion, DiveProfilesCompanion;
import 'package:submersion/core/utils/number_utils.dart';
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
      maxDepth: Value(asDoubleOrNull(diveData['maxDepth'])),
      avgDepth: Value(asDoubleOrNull(diveData['avgDepth'])),
      duration: Value(effectiveDuration?.inSeconds),
      waterTemp: Value(asDoubleOrNull(diveData['waterTemp'])),
      entryTime: Value(dateTime),
      exitTime: Value(exitTime),
      cns: Value(asDoubleOrNull(diveData['cnsEnd'])),
      otu: Value(asDoubleOrNull(diveData['otu'])),
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
            depth: asDoubleOrNull(p['depth']) ?? 0.0,
            temperature: Value(asDoubleOrNull(p['temperature'])),
            pressure: const Value(null),
            heartRate: Value(p['heartRate'] as int?),
            setpoint: Value(asDoubleOrNull(p['setpoint'])),
            ppO2: Value(asDoubleOrNull(p['ppO2'])),
            cns: Value(asDoubleOrNull(p['cns'])),
            ndl: Value(p['ndl'] as int?),
            rbt: Value(p['rbt'] as int?),
            decoType: Value(p['decoType'] as int?),
            tts: Value(p['tts'] as int?),
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
