import 'package:submersion/core/constants/enums.dart';
import 'package:submersion/core/services/logger_service.dart';
import 'package:submersion/features/equipment/data/repositories/service_kind_repository.dart';
import 'package:submersion/features/equipment/data/repositories/service_schedule_repository.dart';
import 'package:submersion/features/equipment/domain/entities/exposure_unit.dart';
import 'package:submersion/features/equipment/domain/entities/service_kind.dart';
import 'package:submersion/features/equipment/domain/entities/service_schedule.dart';

const _log = LoggerService('importServiceClocks');

/// Resolves a kind ref from a backup to a kind in this library (issue
/// #2651): through the file's own kinds as they were mapped, else to itself
/// when a visible kind (a built-in) has that id, else to nothing.
class ServiceKindResolver {
  const ServiceKindResolver(this._mapped, this._localIds);

  final Map<String, String> _mapped;
  final Set<String> _localIds;

  String? resolve(String? ref) {
    if (ref == null || ref.isEmpty) return null;
    return _mapped[ref] ?? (_localIds.contains(ref) ? ref : null);
  }
}

/// Whether an import names any service kind (issue #2651): custom kind
/// definitions, an item's clocks, or a service record's kind. Only then is
/// the library's kind list worth reading.
bool carriesServiceKinds(
  List<Map<String, dynamic>> kinds,
  List<Map<String, dynamic>> items,
  List<Map<String, dynamic>> serviceRecords,
) =>
    kinds.isNotEmpty ||
    items.any((i) => (i['serviceSchedules'] as List?)?.isNotEmpty ?? false) ||
    serviceRecords.any((r) => r['serviceKindRef'] is String);

/// Imports a backup's custom service kinds for [diverId] (issue #2651):
/// each maps to the visible kind with its id, else the visible kind with
/// its name (case-insensitive), else a new kind owned by the diver under a
/// fresh id. A kind that cannot be stored is logged and left unmapped, so
/// refs to it resolve to nothing rather than failing the import.
Future<ServiceKindResolver> importServiceKinds(
  List<Map<String, dynamic>> kinds,
  ServiceKindRepository repository, {
  required String diverId,
}) async {
  final visible = await repository.getAllKinds(diverId: diverId);
  final localIds = {for (final k in visible) k.id};
  final byName = {for (final k in visible) k.name.trim().toLowerCase(): k.id};
  final mapped = <String, String>{};
  for (final data in kinds) {
    final id = data['id'] as String?;
    final name = (data['name'] as String?)?.trim();
    if (id == null || name == null || name.isEmpty) continue;
    if (localIds.contains(id)) {
      mapped[id] = id;
      continue;
    }
    if (byName[name.toLowerCase()] case final existing?) {
      mapped[id] = existing;
      continue;
    }
    final now = DateTime.now();
    try {
      final created = await repository.createKind(
        ServiceKind(
          id: '',
          diverId: diverId,
          name: name,
          applicableTypes: [
            for (final t in (data['applicableTypes'] as List?) ?? const [])
              ?EquipmentType.values.asNameMap()[t],
          ],
          defaultIntervalDays: data['defaultIntervalDays'] as int?,
          defaultIntervalDives: data['defaultIntervalDives'] as int?,
          defaultIntervalHours: (data['defaultIntervalHours'] as num?)
              ?.toDouble(),
          exposureIntervals: _exposures(data['exposureIntervals']),
          defaultCost: (data['defaultCost'] as num?)?.toDouble(),
          defaultCurrency: data['defaultCurrency'] as String?,
          defaultCategory: ServiceCategory.values
              .asNameMap()[data['defaultCategory']],
          autoAttach: data['autoAttach'] as bool? ?? false,
          createdAt: now,
          updatedAt: now,
        ),
      );
      mapped[id] = created.id;
      localIds.add(created.id);
      byName[name.toLowerCase()] = created.id;
    } catch (e) {
      _log.warning('Could not import a service kind: $e');
    }
  }
  return ServiceKindResolver(mapped, localIds);
}

/// Restores the clocks a backup carries on its items (issue #2651), only
/// for items this import created: a duplicate matched to an existing row
/// keeps its own clocks, as it keeps its service records. The item ends
/// with exactly the backup's clocks. Each replaces the item's unclaimed
/// clock of the same kind (one createEquipment just seeded, auto-attached
/// or legacy), keeping its id, or is created; a seeded clock the backup
/// does not list is removed, as the diver had removed it. An item from a
/// file written before clocks travelled carries no list and keeps its
/// defaults. Returns how many clocks were written.
Future<int> restoreServiceClocks(
  List<Map<String, dynamic>> items,
  Set<int> selected,
  Map<String, String> equipmentIdMapping,
  Map<String, String> preResolvedEquipmentIds,
  ServiceScheduleRepository repository,
  ServiceKindResolver kinds,
) async {
  // The created items that carry a clock list, with their seeded clocks
  // read in one batch rather than one query per item.
  final targets = <(String, List<Object?>)>[];
  for (final (i, item) in items.indexed) {
    if (!selected.contains(i)) continue;
    final uddfId = item['uddfId'] as String?;
    final rows = item['serviceSchedules'];
    if (uddfId == null || rows is! List) continue;
    final equipmentId = equipmentIdMapping[uddfId];
    if (equipmentId == null || preResolvedEquipmentIds[uddfId] == equipmentId) {
      continue;
    }
    targets.add((equipmentId, rows));
  }
  if (targets.isEmpty) return 0;
  final seeded = await repository.getSchedulesForEquipmentIds([
    for (final (equipmentId, _) in targets) equipmentId,
  ]);
  var count = 0;
  for (final (equipmentId, rows) in targets) {
    final unclaimed = [...?seeded[equipmentId]];
    for (final row in rows.whereType<Map<String, dynamic>>()) {
      final kindId = kinds.resolve(row['kindRef'] as String?);
      if (kindId == null) continue;
      final slot = unclaimed
          .where((s) => s.serviceKindId == kindId)
          .firstOrNull;
      if (slot != null) unclaimed.remove(slot);
      final now = DateTime.now();
      final schedule = ServiceSchedule(
        id: slot?.id ?? '',
        equipmentId: equipmentId,
        serviceKindId: kindId,
        intervalDays: row['intervalDays'] as int?,
        intervalDives: row['intervalDives'] as int?,
        intervalHours: (row['intervalHours'] as num?)?.toDouble(),
        exposureIntervals: _exposures(row['exposureIntervals']),
        defaultCost: (row['defaultCost'] as num?)?.toDouble(),
        defaultCurrency: row['defaultCurrency'] as String?,
        anchorDate: row['anchorDate'] as DateTime?,
        anchorSetAt: row['anchorSetAt'] as DateTime?,
        enabled: row['enabled'] as bool? ?? true,
        createdAt: slot?.createdAt ?? now,
        updatedAt: now,
      );
      try {
        if (slot != null) {
          await repository.updateSchedule(schedule);
        } else {
          await repository.createSchedule(schedule);
        }
        count++;
      } catch (e) {
        _log.warning('Could not restore a $kindId clock on $equipmentId: $e');
      }
    }
    // Seeded moments ago by createEquipment; the backup did not list them.
    for (final extra in unclaimed) {
      try {
        await repository.deleteSchedule(extra.id);
      } catch (e) {
        _log.warning('Could not remove a default clock on $equipmentId: $e');
      }
    }
  }
  return count;
}

Map<ExposureUnit, double> _exposures(Object? raw) => {
  if (raw is Map)
    for (final entry in raw.entries)
      if ((ExposureUnit.fromDbValue('${entry.key}'), entry.value) case (
        final ExposureUnit unit,
        final num value,
      ))
        unit: value.toDouble(),
};
