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

/// Detaches media from [equipmentId]. Rows a dive or site still references
/// survive with only the equipment link cleared; the rest leave the library
/// through the same destructive path every other unlink uses. Original
/// source files are never touched.
///
/// The invalidations are scoped to [equipmentId] rather than to the family
/// root: invalidating the family would rebuild every other item's list and
/// count too, and each rebuild is a database read. Matches how the attach
/// path in `DocumentOpenHelper.pickAndAttach` invalidates.
Future<EquipmentUnlinkOutcome> unlinkEquipmentMedia(
  WidgetRef ref,
  String equipmentId,
  List<String> ids,
) async {
  final outcome = await ref
      .read(mediaUnlinkServiceProvider)
      .unlinkFromEquipment(ids);
  ref.invalidate(mediaForEquipmentProvider(equipmentId));
  ref.invalidate(mediaCountForEquipmentProvider(equipmentId));
  return outcome;
}
