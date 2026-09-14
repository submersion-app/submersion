import 'package:submersion/core/constants/enums.dart';
import 'package:submersion/features/universal_import/data/services/macdive_value_mapper.dart';
import 'package:submersion/features/universal_import/data/services/suit_classifier.dart';

/// A type read from an equipment item's name, with the wetsuit thickness the
/// name states when it states exactly one.
typedef TypeFromName = ({EquipmentType type, String? thickness});

/// Reads what an item is from its [name] alone (issue #1886), for gear that
/// earlier imports stored as [EquipmentType.other]: CSV suits before #1885
/// and MacDive XML gear before #1871. Once stored, such an item keeps only
/// its name, so the name is the only signal left.
///
/// Uses the same two readers as the importers. [classifySuit] decides which
/// suit a suit is, and is careful where the free-text mapper is not: a
/// "Semi dry suit" is a wetsuit, and "Dry gloves" name no suit. The mapper
/// covers every other type. [classifySuit] was written for a column known to
/// hold a suit, though, so a thickness token or the word "dry" is weaker in
/// a general item name: when the mapper names a specific item that is not a
/// suit, the mapper wins. "O-ring kit 2.5mm" is a tool and "Drysuit thigh
/// pocket" a pocket.
///
/// Returns null when the name does not say what the item is.
TypeFromName? typeFromName(String name) {
  final mapped = MacDiveValueMapper.equipmentType(name);
  final readsNothing = mapped == null || mapped == EquipmentType.other;
  final suit = classifySuit(name);
  if (suit != null && (readsNothing || _suits.contains(mapped))) return suit;
  if (readsNothing) return null;
  return (type: mapped, thickness: null);
}

const _suits = {EquipmentType.wetsuit, EquipmentType.drysuit};
