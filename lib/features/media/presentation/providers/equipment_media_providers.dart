import 'package:submersion/core/providers/provider.dart';
import 'package:submersion/features/media/domain/entities/media_item.dart';
import 'package:submersion/features/media/presentation/providers/media_providers.dart';

/// Documents and photos attached to a piece of equipment (issue #1517):
/// invoices, receipts and warranty paperwork, oldest first.
final mediaForEquipmentProvider =
    FutureProvider.family<List<MediaItem>, String>((ref, equipmentId) async {
      final repository = ref.watch(mediaRepositoryProvider);
      ref.invalidateSelfWhen(repository.watchMediaChanges());
      return repository.getMediaForEquipment(equipmentId);
    });

/// Count of equipment attachments (badges/headers).
final mediaCountForEquipmentProvider = FutureProvider.family<int, String>((
  ref,
  equipmentId,
) async {
  final repository = ref.watch(mediaRepositoryProvider);
  ref.invalidateSelfWhen(repository.watchMediaChanges());
  return repository.getMediaCountForEquipment(equipmentId);
});
