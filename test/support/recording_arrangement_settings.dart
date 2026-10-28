import 'dart:async';

import 'package:submersion/features/equipment/domain/models/equipment_arrangement.dart';
import 'package:submersion/features/settings/domain/list_arrangements.dart';

import '../helpers/mock_providers.dart';

/// A settings notifier that records each gear arrangement saved for the
/// diver (issue #3748), for the sheets that edit it.
///
/// [holdWrites] holds each change until the test completes it, as the real
/// notifier holds a change until the diver's settings have loaded, so
/// several taps can queue. [failWrite] makes every save throw, as a failed
/// database write would.
class RecordingArrangementSettings extends MockSettingsNotifier {
  final List<EquipmentArrangement> written = [];
  bool holdWrites = false;
  final List<Completer<void>> heldWrites = [];
  bool failWrite = false;

  /// The arrangement saved for the diver, or null when none is.
  EquipmentArrangement? get stored =>
      decodeEquipmentArrangement(state.listArrangements.equipmentArrangement);

  @override
  Future<void> updateListArrangements(
    ListArrangements Function(ListArrangements current) change,
  ) async {
    if (holdWrites) {
      final gate = Completer<void>();
      heldWrites.add(gate);
      await gate.future;
    }
    if (failWrite) throw StateError('write failed');
    final before = state.listArrangements.equipmentArrangement;
    await super.updateListArrangements(change);
    final after = state.listArrangements.equipmentArrangement;
    if (after != before) written.add(decodeEquipmentArrangement(after)!);
  }
}
