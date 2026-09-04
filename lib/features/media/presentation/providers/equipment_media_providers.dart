import 'package:submersion/core/providers/provider.dart';
import 'package:submersion/features/media/data/services/media_unlink_service.dart';
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

/// Detaches media from a piece of equipment. Rows a dive or site still
/// references survive with only the equipment link cleared; the rest leave
/// the library through the same destructive path every other unlink uses.
/// Original source files are never touched.
Future<EquipmentUnlinkOutcome> unlinkEquipmentMedia(
  WidgetRef ref,
  List<String> ids,
) async {
  final outcome = await ref
      .read(mediaUnlinkServiceProvider)
      .unlinkFromEquipment(ids);
  ref.invalidate(mediaForEquipmentProvider);
  ref.invalidate(mediaCountForEquipmentProvider);
  return outcome;
}
