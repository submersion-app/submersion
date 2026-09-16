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
  /// same type. Each item is read afresh, so an edit or sync since the list
  /// was built is not overwritten, and written in its own transaction:
  /// [EquipmentRepository.updateEquipment] writes the row, its attributes
  /// and the pending mark in separate steps, and a throw in a later step
  /// must not leave the type changed with the item counted as failed. One
  /// failed item does not stop the rest.
  Future<RetypeReceipt> apply(List<RetypeCandidate> candidates) async {
    final retyped = <RetypedItem>[];
    var failed = 0;
    for (final listed in candidates) {
      try {
        final change = await _repository.transaction(() => _retype(listed));
        if (change != null) retyped.add(change);
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

  /// Retypes [listed] as it is stored now; null when it changed since.
  Future<RetypedItem?> _retype(RetypeCandidate listed) async {
    final before = await _repository.getEquipmentById(listed.item.id);
    final candidate = before == null ? null : candidateFor(before);
    if (before == null || candidate == null || candidate.type != listed.type) {
      return null;
    }
    final thickness = candidate.thickness;
    await _repository.updateEquipment(
      before.copyWith(
        type: candidate.type,
        attributes: [
          ...before.attributes,
          if (thickness != null)
            EquipmentAttribute.curated(
              equipmentId: before.id,
              key: EquipmentAttrKeys.thicknessMm,
              valueText: thickness,
              valueNum: parsePrimaryThickness(thickness),
            ),
        ],
      ),
    );
    // Read back rather than built here, so Undo compares like with like.
    final after = await _repository.getEquipmentById(before.id);
    return RetypedItem(before: before, after: after!);
  }

  /// Puts back each item in [receipt] that is still exactly as the retype
  /// left it. An item edited, retyped again or deleted since, on this device
  /// or by a sync, is skipped rather than overwritten: Undo reverses only
  /// its own change. Each item is written in its own transaction, as in
  /// [apply].
  Future<RetypeUndoResult> undo(RetypeReceipt receipt) async {
    var restored = 0;
    var skipped = 0;
    var failed = 0;
    for (final change in receipt.retyped) {
      try {
        final undone = await _repository.transaction(() async {
          final current = await _repository.getEquipmentById(change.id);
          if (current != change.after) return false;
          await _repository.updateEquipment(change.before);
          return true;
        });
        if (undone) {
          restored++;
        } else {
          skipped++;
        }
      } catch (e, stackTrace) {
        _log.error(
          'Failed to undo retype of equipment: ${change.id}',
          error: e,
          stackTrace: stackTrace,
        );
        failed++;
      }
    }
    return RetypeUndoResult(
      restored: restored,
      skipped: skipped,
      failed: failed,
    );
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
