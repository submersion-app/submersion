import 'package:submersion/core/constants/enums.dart';
import 'package:submersion/core/services/logger_service.dart';
import 'package:submersion/features/equipment/data/repositories/equipment_repository_impl.dart';
import 'package:submersion/features/equipment/domain/constants/equipment_attribute_catalog.dart';
import 'package:submersion/features/equipment/domain/entities/equipment_attribute.dart';
import 'package:submersion/features/equipment/domain/entities/equipment_item.dart';
import 'package:submersion/features/equipment/domain/entities/other_gear_retype.dart';
import 'package:submersion/features/equipment/domain/services/equipment_type_from_name.dart';

/// Retypes gear that earlier imports stored as [EquipmentType.other] from
/// what its name says it is (issue #1886), after the diver reviews it.
///
/// Every write goes through [EquipmentRepository.updateEquipment], so a
/// retype is an ordinary edit: it stamps `updatedAt`, marks the item and its
/// attributes pending, and syncs to other devices like any other change.
class OtherGearRetypeService {
  OtherGearRetypeService(this._repository);

  final EquipmentRepository _repository;
  final _log = LoggerService.forClass(OtherGearRetypeService);

  /// [diverId]'s Other items whose name says what they are, by name.
  Future<List<RetypeCandidate>> findCandidates(String diverId) async {
    final items = await _repository.getAllEquipment(diverId: diverId);
    final candidates = [for (final item in items) ?candidateFor(item)];
    return candidates..sort((a, b) {
      final byName = a.item.name.toLowerCase().compareTo(
        b.item.name.toLowerCase(),
      );
      return byName != 0 ? byName : a.item.id.compareTo(b.item.id);
    });
  }

  /// What retyping [item] would write, or null when it is not an Other item
  /// whose name says what it is.
  static RetypeCandidate? candidateFor(EquipmentItem item) {
    if (item.type != EquipmentType.other) return null;
    final read = typeFromName(item.name);
    if (read == null) return null;
    final thickness = read.thickness;
    final writesThickness =
        thickness != null &&
        isValidThicknessDesignation(thickness) &&
        _takesThickness(read.type) &&
        !_hasThickness(item);
    return RetypeCandidate(
      item: item,
      type: read.type,
      thickness: writesThickness ? thickness : null,
    );
  }

  /// Retypes each of [candidates] that is still an Other item reading as the
  /// same type. Each item is read afresh and written on its own, so an edit
  /// or sync since the list was built is neither overwritten nor undone, and
  /// one failed write does not stop the rest.
  Future<RetypeReceipt> apply(List<RetypeCandidate> candidates) async {
    final retyped = <RetypedItem>[];
    var failed = 0;
    for (final listed in candidates) {
      try {
        final current = await _repository.getEquipmentById(listed.item.id);
        final candidate = current == null ? null : candidateFor(current);
        if (current == null ||
            candidate == null ||
            candidate.type != listed.type) {
          continue;
        }
        final thickness = candidate.thickness;
        await _repository.updateEquipment(
          current.copyWith(
            type: candidate.type,
            attributes: [
              ...current.attributes,
              if (thickness != null)
                EquipmentAttribute.curated(
                  equipmentId: current.id,
                  key: EquipmentAttrKeys.thicknessMm,
                  valueText: thickness,
                  valueNum: parsePrimaryThickness(thickness),
                ),
            ],
          ),
        );
        retyped.add(
          RetypedItem(
            id: current.id,
            previousType: current.type,
            type: candidate.type,
            addedThickness: thickness != null,
          ),
        );
      } catch (e, stackTrace) {
        _log.error(
          'Failed to retype equipment: ${listed.item.id}',
          error: e,
          stackTrace: stackTrace,
        );
        failed++;
      }
    }
    return RetypeReceipt(retyped: retyped, failed: failed);
  }

  /// Puts back each item in [receipt] that still has the type the retype
  /// gave it, removing a thickness the retype wrote. Returns how many writes
  /// failed.
  Future<int> undo(RetypeReceipt receipt) async {
    var failed = 0;
    for (final change in receipt.retyped) {
      try {
        final current = await _repository.getEquipmentById(change.id);
        if (current == null || current.type != change.type) continue;
        await _repository.updateEquipment(
          current.copyWith(
            type: change.previousType,
            attributes: change.addedThickness
                ? [
                    for (final a in current.attributes)
                      if (!_isThickness(a)) a,
                  ]
                : current.attributes,
          ),
        );
      } catch (e, stackTrace) {
        _log.error(
          'Failed to undo retype of equipment: ${change.id}',
          error: e,
          stackTrace: stackTrace,
        );
        failed++;
      }
    }
    return failed;
  }

  static bool _takesThickness(EquipmentType type) =>
      EquipmentAttributeCatalog.attributesFor(
        type,
      ).any((def) => def.key == EquipmentAttrKeys.thicknessMm);

  static bool _isThickness(EquipmentAttribute a) =>
      !a.isCustom && a.key == EquipmentAttrKeys.thicknessMm;

  static bool _hasThickness(EquipmentItem item) =>
      item.attributes.any((a) => _isThickness(a) && a.hasValue);
}
