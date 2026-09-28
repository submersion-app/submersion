import 'package:submersion/core/providers/provider.dart';
import 'package:submersion/features/equipment/data/repositories/equipment_service_status_repository.dart';
import 'package:submersion/features/equipment/domain/entities/service_clock_status.dart';
import 'package:submersion/features/equipment/presentation/providers/equipment_providers.dart';

final equipmentServiceStatusRepositoryProvider =
    Provider<EquipmentServiceStatusRepository>(
      (ref) => EquipmentServiceStatusRepository(),
    );

/// Mirrors [activeEquipmentClocksProvider] into the local cache the
/// `serviceDue` query field reads (#2365 PR 3). The engine lists statuses
/// worst first, so the first is the item's verdict, the same one
/// [equipmentWorstClockProvider] and the row badges show. Re-runs whenever
/// the clocks do (a ledger write, a share, a diver switch). Read it before
/// running a query whose `tablesTouched` names `equipment_service_status`.
// no-tick: a WRITE of derived data, not a cached query. It re-runs whenever
// activeEquipmentClocksProvider does, and that provider subscribes to the
// equipment, share, attribute and service-ledger ticks the verdicts come
// from; its only repository call writes the cache and renders nothing.
final equipmentServiceStatusCacheProvider = FutureProvider<void>((ref) async {
  final evaluated = await ref.watch(activeEquipmentClocksProvider.future);
  await ref.read(equipmentServiceStatusRepositoryProvider).replaceAll({
    for (final e in evaluated)
      e.item.id: e.statuses.isEmpty
          ? (severity: ServiceClockSeverity.ok.name, dueDate: null)
          : (
              severity: e.statuses.first.severity.name,
              dueDate: e.statuses.first.dueDate?.millisecondsSinceEpoch,
            ),
  }, computedAt: DateTime.now().millisecondsSinceEpoch);
});
