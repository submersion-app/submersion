import 'package:submersion/core/database/database.dart' show DiverSetting;
import 'package:submersion/features/agent_access/data/documents/profile_documents.dart';
import 'package:submersion/features/agent_access/data/records/record_entity.dart';
import 'package:submersion/features/agent_access/data/records/record_repositories.dart';
import 'package:submersion/features/agent_access/data/records/record_scope.dart';
import 'package:submersion/features/divers/domain/entities/diver.dart';

/// Diver profiles and their settings. An agent acts across every profile on
/// the device, so each profile reads from any other.
List<RecordEntry> profileEntries(RecordRepositories r) => [
  RecordEntity<Diver>(
    name: 'divers',
    table: 'divers',
    scope: everyone(),
    orderBy: 'r0.name COLLATE NOCASE',
    load: (ids, _) => loadEach(ids, r.divers.getDiverById),
    document: diverRecordDocument,
    summaryKeys: const ['name', 'email', 'is_default'],
  ),
  RecordEntity<DiverSetting>(
    name: 'diver_settings',
    table: 'diver_settings',
    scope: owned(),
    load: (ids, _) async {
      final rows = await (r.db.select(
        r.db.diverSettings,
      )..where((s) => s.id.isIn(ids))).get();
      return byId(rows, (s) => s.id);
    },
    document: settingsDocument,
    summaryKeys: const ['diver_id', 'depth_unit', 'temperature_unit'],
  ),
];
