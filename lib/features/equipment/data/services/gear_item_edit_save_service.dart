import 'package:submersion/core/providers/provider.dart';
import 'package:submersion/core/services/change_log/record_sitting_writer.dart';
import 'package:submersion/features/equipment/data/repositories/equipment_repository_impl.dart';
import 'package:submersion/features/equipment/data/repositories/gear_photo_repository.dart';
import 'package:submersion/features/equipment/domain/entities/equipment_item.dart';
import 'package:submersion/features/equipment/presentation/providers/equipment_providers.dart';
import 'package:submersion/features/equipment/presentation/providers/gear_photo_providers.dart';

/// Writes a gear item page's editing sitting (issue #4527, phase 3, plan 6):
/// its changed values and every held write, in one transaction and one
/// History entry labelled with the cards it changed.
class GearItemEditSaveService {
  GearItemEditSaveService(this._equipment, this._photos);

  final EquipmentRepository _equipment;
  final GearPhotoRepository _photos;

  /// Saves [apply] onto item [equipmentId] as stored now, so a value changed
  /// underneath on a card the diver never touched is kept. The update
  /// writes the row, its attributes, the service clock baselines its dates
  /// move, and the name and notes mirrored onto its dive computer and
  /// transmitters, inside the sitting. [alsoWrite] makes the held writes
  /// (tags, sharing, moves, clocks, records, check-ins, media, documents,
  /// the dive computer's settings) after the row; with [alsoWriteIsAChange]
  /// they are written even when the row is unchanged.
  ///
  /// The cover is written last, after the held writes, since the update
  /// never writes it and a photo imported in the sitting must exist before
  /// it can be chosen. Returns the item before and after, or null when
  /// nothing changed. Throws [StateError] when it no longer exists.
  Future<({EquipmentItem before, EquipmentItem after})?> save({
    required String equipmentId,
    required EquipmentItem Function(EquipmentItem stored) apply,
    required Iterable<String> changedCardIds,
    Future<void> Function()? alsoWrite,
    bool alsoWriteIsAChange = false,
  }) {
    EquipmentItem? from;
    EquipmentItem? to;
    return writeRecordSitting<EquipmentItem>(
      table: 'equipment',
      recordId: equipmentId,
      changedCardIds: changedCardIds,
      read: () => _equipment.getEquipmentById(equipmentId),
      apply: apply,
      write: (stored, merged) async {
        from = stored;
        to = merged;
        await _equipment.updateEquipment(merged, notify: false);
      },
      alsoWrite: () async {
        await alsoWrite?.call();
        final before = from;
        final after = to;
        if (before != null &&
            after != null &&
            after.coverMediaId != before.coverMediaId) {
          await _photos.setCover(equipmentId, after.coverMediaId);
        }
      },
      alsoWriteIsAChange: alsoWriteIsAChange,
    );
  }
}

final gearItemEditSaveServiceProvider = Provider<GearItemEditSaveService>(
  (ref) => GearItemEditSaveService(
    ref.watch(equipmentRepositoryProvider),
    ref.watch(gearPhotoRepositoryProvider),
  ),
);
