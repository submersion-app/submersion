import 'package:collection/collection.dart';

import 'package:submersion/features/equipment/domain/catalogue/equipment_catalogue.dart';
import 'package:submersion/features/equipment/domain/catalogue/equipment_catalogue_record.dart';
import 'package:submersion/features/equipment/domain/entities/equipment_attribute.dart';
import 'package:submersion/features/equipment/domain/entities/equipment_item.dart';

/// What part of an item a catalogue offer row would set.
enum CatalogueOfferFieldKind { brand, model, attribute }

/// One field a catalogue record would give an item (issue #5118).
class CatalogueOfferRow {
  const CatalogueOfferRow({
    required this.kind,
    required this.fieldName,
    required this.itemValue,
    required this.recordValue,
    required this.startTicked,
  });

  final CatalogueOfferFieldKind kind;

  /// `brand`, `model` or the attribute key. Stored in the item's answers
  /// when the diver leaves an empty field unticked, so never renamed.
  final String fieldName;

  /// The item's value now: a [String] for brand, model, text and choice
  /// attributes, a [double] for numbers and flags (1 or 0); null when empty.
  final Object? itemValue;

  /// The record's value, in the same shape as [itemValue].
  final Object recordValue;

  /// Ticked when the item has the field empty; a value the diver holds is
  /// shown beside the record's but never replaced without a tick.
  final bool startTicked;

  /// The attribute key, for an attribute row.
  String? get attributeKey =>
      kind == CatalogueOfferFieldKind.attribute ? fieldName : null;
}

/// What linking an item to [record] would add: the link, and a row per
/// field where the two differ.
class CatalogueOffer {
  const CatalogueOffer({
    required this.record,
    required this.addsLink,
    required this.rows,
  });

  final EquipmentCatalogueRecord record;
  final bool addsLink;
  final List<CatalogueOfferRow> rows;

  int get tickedByDefault => rows.where((r) => r.startTicked).length;
}

String? _blankToNull(String? value) {
  final trimmed = value?.trim();
  return trimmed == null || trimmed.isEmpty ? null : trimmed;
}

/// The comparable value of an item's curated attribute, or null when the
/// item has none with content.
Object? _attributeValue(EquipmentItem item, String key) =>
    catalogueComparableValue(
      item.attributes.firstWhereOrNull((a) => !a.isCustom && a.key == key),
    );

/// An attribute's value as an offer row holds it ([CatalogueOfferRow.itemValue]),
/// or null when it has no content.
Object? catalogueComparableValue(EquipmentAttribute? attr) =>
    attr == null || !attr.hasContent ? null : _valueOf(attr);

/// A brand or model as an offer row holds it: trimmed, or null when blank.
String? catalogueComparableText(String? value) => _blankToNull(value);

Object? _valueOf(EquipmentAttribute attr) =>
    _blankToNull(attr.valueText) ?? attr.valueNum;

/// The rows [record] offers [working], the item as the editor holds it now.
///
/// Brand and model are offered only as a spelling the diver may take
/// (unticked): the names already resolved to the record. For each of the
/// record's attributes, an empty field is offered ticked, a different value
/// unticked, and an equal value not at all. An empty field the diver turned
/// down for this record before is not offered again.
CatalogueOffer offerFor(
  EquipmentItem working,
  EquipmentCatalogueRecord record,
) {
  final declined =
      working.catalogueAnswers.declined[record.id] ?? const <String>{};
  final rows = <CatalogueOfferRow>[
    for (final (kind, name, mine, theirs) in [
      (
        CatalogueOfferFieldKind.brand,
        'brand',
        _blankToNull(working.brand),
        record.manufacturer,
      ),
      (
        CatalogueOfferFieldKind.model,
        'model',
        _blankToNull(working.model),
        record.model,
      ),
    ])
      if (mine != theirs && !(mine == null && declined.contains(name)))
        CatalogueOfferRow(
          kind: kind,
          fieldName: name,
          itemValue: mine,
          recordValue: theirs,
          startTicked: mine == null,
        ),
    for (final key in record.attributes.keys)
      if (record.attributeFor(key) case final attr?)
        if ((_attributeValue(working, key), _valueOf(attr)) case (
          final mine,
          final theirs?,
        ) when mine != theirs && !(mine == null && declined.contains(key)))
          CatalogueOfferRow(
            kind: CatalogueOfferFieldKind.attribute,
            fieldName: key,
            itemValue: mine,
            recordValue: theirs,
            startTicked: mine == null,
          ),
  ];
  return CatalogueOffer(
    record: record,
    addsLink: working.catalogueId != record.id,
    rows: rows,
  );
}

/// Whether the gear editor shows the catalogue line for [offer].
///
/// Never for a record the diver said is not this item, nor for an item
/// linked to another record. An unlinked item always sees it, so the link
/// can be made even when every value already agrees. A linked item sees it
/// only while the record has an empty field to fill.
bool showOfferLine(EquipmentItem working, CatalogueOffer offer) {
  if (working.catalogueAnswers.notSame.contains(offer.record.id)) return false;
  final linked = working.catalogueId;
  if (linked == null) return true;
  if (linked != offer.record.id) return false;
  return offer.tickedByDefault > 0;
}

/// The link [working] keeps at Save: dropped when its record is in
/// [catalogue] and the item's brand and model no longer name it (the item
/// is no longer that model). A record this copy of the catalogue lacks
/// keeps its link: another device may know it.
String? catalogueIdAfterRename(
  EquipmentItem working,
  EquipmentCatalogue catalogue,
) {
  final linked = working.catalogueId;
  if (linked == null || catalogue.byId(linked) == null) return linked;
  final resolved = catalogue.resolve(
    working.type,
    working.brand,
    working.model,
  );
  return resolved?.id == linked ? linked : null;
}
