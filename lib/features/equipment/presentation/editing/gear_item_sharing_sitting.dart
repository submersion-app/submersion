import 'package:submersion/features/equipment/domain/entities/equipment_item.dart';
import 'package:submersion/shared/widgets/record_editing/record_sharing_sitting.dart';

/// Who the item is shared with, held in its page's sitting (issue #4527,
/// phase 3, plan 6): chosen on the Details card, written at Save by the
/// active profile. A profile that may no longer share the item (it changed
/// hands on another device) fails the Save whole.
const gearItemSharing = RecordSharingSitting<EquipmentItem, Set<String>>(
  key: 'equipment.sharing',
  // GearItemCardId.details.
  cardId: 'details',
  recordIdOf: _idOf,
);

String _idOf(EquipmentItem item) => item.id;
