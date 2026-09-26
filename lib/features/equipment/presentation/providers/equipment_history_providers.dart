import 'package:submersion/core/providers/provider.dart';
import 'package:submersion/features/dive_log/presentation/providers/dive_repository_provider.dart';
import 'package:submersion/features/equipment/domain/services/equipment_history_builder.dart';
import 'package:submersion/features/equipment/presentation/providers/equipment_providers.dart';
import 'package:submersion/features/equipment/presentation/providers/equipment_share_providers.dart';

/// [equipmentId]'s History card entries, newest first (issue #2046).
final equipmentHistoryProvider =
    FutureProvider.family<List<EquipmentHistoryEntry>, String>((
      ref,
      equipmentId,
    ) async {
      final repository = ref.watch(equipmentRepositoryProvider);
      final shares = ref.watch(equipmentShareRepositoryProvider);
      ref.invalidateSelfWhen(repository.watchEquipmentChanges());
      // Usage comes from the dives and their gear and tank links, so putting
      // the item on (or off) a dive refreshes the card.
      ref.invalidateSelfWhen(
        ref.read(diveRepositoryProvider).watchTables(const {
          'dives',
          'dive_equipment',
          'dive_tanks',
        }),
      );
      ref.invalidateSelfWhen(shares.watchChanges());
      final item = await repository.getEquipmentById(equipmentId);
      if (item == null) return const [];
      return buildEquipmentHistory(
        dives: await repository.getUsageByDiver(item),
        events: await shares.getEventsFor(equipmentId),
        currentOwnerId: item.diverId,
        createdAt: item.createdAt,
      );
    });
