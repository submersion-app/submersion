import 'package:submersion/core/constants/enums.dart';
import 'package:submersion/features/equipment/domain/constants/equipment_attribute_catalog.dart';

/// The attribute kinds a catalogue record may carry: facts about a model.
/// Dates, colours and links belong to the diver's own item, never to a model.
const Set<AttributeKind> _offerableKinds = {
  AttributeKind.text,
  AttributeKind.number,
  AttributeKind.thickness,
  AttributeKind.choice,
  AttributeKind.flag,
  AttributeKind.focalLength,
};

/// Spec attributes that describe one physical item, not its model: the
/// diver's label for it, the size they bought, a prescription lens, the
/// slot a cell sits in, and how they use or carry it.
const Set<String> _perItemKeys = {
  EquipmentAttrKeys.identifier,
  'size',
  'prescription',
  'cell_slot',
  'cylinder_use',
  'worn_as',
};

/// The curated attributes a catalogue record of [type] may give a value
/// for: the type's spec attributes of an offerable kind that describe the
/// model. Purchase, appearance and app-written keys are the diver's, never
/// a model's.
List<EquipmentAttributeDef> catalogueAttributeDefs(EquipmentType type) => [
  for (final def in EquipmentAttributeCatalog.attributesFor(type))
    if (def.group == AttributeGroup.spec &&
        _offerableKinds.contains(def.kind) &&
        !_perItemKeys.contains(def.key))
      def,
];

/// Every type's offerable keys, as the equipment catalogue repository's
/// `schema/attribute-keys.json` holds them: type name to key to its kind
/// and, for a choice, its choice keys. Its validator checks records against
/// this, so the two repositories cannot drift silently. The fixture is
/// rewritten by running the equipment catalogue contract test with
/// UPDATE_EQUIPMENT_CATALOGUE_KEYS=1.
Map<String, Map<String, Map<String, Object>>> exportEquipmentAttributeKeys() =>
    {
      for (final type in EquipmentType.values)
        type.name: {
          for (final def in catalogueAttributeDefs(type))
            def.key: {
              'kind': def.kind.name,
              if (def.kind == AttributeKind.choice) 'choices': def.choiceKeys,
            },
        },
    };
