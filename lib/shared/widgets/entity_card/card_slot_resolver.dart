import 'package:submersion/shared/constants/entity_field.dart';
import 'package:submersion/shared/models/entity_card_view_config.dart';

/// The field configured for [slotId], or [fallback] when the saved config
/// has no such slot (an older layout, or a slot this card added later).
F resolveCardSlot<F extends EntityField>(
  List<EntityCardSlotConfig<F>> slots,
  String slotId,
  F fallback,
) {
  for (final slot in slots) {
    if (slot.slotId == slotId) return slot.field;
  }
  return fallback;
}
