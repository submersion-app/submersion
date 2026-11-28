import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/core/constants/enums.dart';
import 'package:submersion/features/equipment/domain/catalogue/equipment_catalogue_offer.dart';
import 'package:submersion/features/equipment/domain/catalogue/equipment_catalogue_record.dart';
import 'package:submersion/features/equipment/domain/entities/equipment_attribute.dart';
import 'package:submersion/features/equipment/domain/entities/equipment_item.dart';
import 'package:submersion/features/equipment/presentation/editing/gear_item_catalogue_sitting.dart';
import 'package:submersion/features/equipment/presentation/editing/gear_item_edit_fields.dart';
import 'package:submersion/shared/widgets/record_editing/edit_session.dart';

const _perdix = EquipmentCatalogueRecord(
  id: 'shearwater-perdix-2',
  manufacturer: 'Shearwater',
  model: 'Perdix 2',
  type: EquipmentType.computer,
  attributes: {'connectivity': 'ble', 'mount': 'wrist'},
);

EquipmentItem _item({List<EquipmentAttribute> attributes = const []}) =>
    EquipmentItem(
      id: 'e1',
      name: 'Perdix',
      type: EquipmentType.computer,
      brand: 'Shearwater',
      model: 'perdix2',
      attributes: attributes,
    );

const _console = EquipmentAttribute(
  id: 'a',
  equipmentId: 'e1',
  key: 'mount',
  valueText: 'console',
);

String? _text(EditSession<EquipmentItem> s, String key) =>
    s.valueOf(gearAttributeField(key))?.valueText;

void main() {
  late EditSession<EquipmentItem> session;
  tearDown(() => session.dispose());

  test('Apply holds the ticked values and the link, not yet saved', () {
    session = EditSession(_item());
    final offer = offerFor(session.working, _perdix);
    holdGearCatalogueReview(
      session,
      offer,
      const GearCatalogueApply({'connectivity', 'mount'}),
    );
    expect(_text(session, 'connectivity'), 'ble');
    expect(_text(session, 'mount'), 'wrist');
    expect(session.valueOf(gearCatalogueIdField), 'shearwater-perdix-2');
    // Nothing is written: the stored item is as it was.
    expect(session.stored.catalogueId, isNull);
    expect(session.stored.attributes, isEmpty);
    expect(gearCatalogueRevision(session), 1);
  });

  test('a discarded sitting leaves nothing behind', () {
    session = EditSession(_item());
    holdGearCatalogueReview(
      session,
      offerFor(session.working, _perdix),
      const GearCatalogueApply({'connectivity'}),
    );
    // Cancel ends the sitting without a write; the stored item never had it.
    expect(session.stored.catalogueId, isNull);
    expect(
      session.stored.attributes.where((a) => a.key == 'connectivity'),
      isEmpty,
    );
  });

  test('a value typed after the sheet opened is not overwritten', () {
    session = EditSession(_item());
    final offer = offerFor(session.working, _perdix);
    // The diver types a connectivity while the sheet is open.
    session.set(
      gearAttributeField('connectivity'),
      const EquipmentAttribute(
        id: 'c',
        equipmentId: 'e1',
        key: 'connectivity',
        valueText: 'usb',
      ),
    );
    holdGearCatalogueReview(
      session,
      offer,
      const GearCatalogueApply({'connectivity'}),
    );
    expect(_text(session, 'connectivity'), 'usb');
    expect(session.valueOf(gearCatalogueIdField), 'shearwater-perdix-2');
  });

  test('a ticked differing value replaces the diver value', () {
    session = EditSession(_item(attributes: [_console]));
    holdGearCatalogueReview(
      session,
      offerFor(session.working, _perdix),
      const GearCatalogueApply({'mount'}),
    );
    expect(_text(session, 'mount'), 'wrist');
  });

  test('a ticked model spelling replaces the typed one', () {
    session = EditSession(_item());
    holdGearCatalogueReview(
      session,
      offerFor(session.working, _perdix),
      const GearCatalogueApply({'model'}),
    );
    expect(session.valueOf(gearModelField), 'Perdix 2');
  });

  test('empty fields left unticked are declined; differing ones are not', () {
    session = EditSession(_item(attributes: [_console]));
    holdGearCatalogueReview(
      session,
      offerFor(session.working, _perdix),
      const GearCatalogueApply({}),
    );
    final answers = session.valueOf(gearCatalogueAnswersField);
    expect(answers.declined['shearwater-perdix-2'], {'connectivity'});
    expect(_text(session, 'mount'), 'console');
    expect(session.valueOf(gearCatalogueIdField), 'shearwater-perdix-2');
  });

  test('Not this model records the answer and no link', () {
    session = EditSession(_item());
    holdGearCatalogueReview(
      session,
      offerFor(session.working, _perdix),
      const GearCatalogueNotThisModel(),
    );
    expect(session.valueOf(gearCatalogueAnswersField).notSame, {
      'shearwater-perdix-2',
    });
    expect(session.valueOf(gearCatalogueIdField), isNull);
    expect(_text(session, 'connectivity'), isNull);
  });

  test('Not this model on a linked item also unlinks it', () {
    session = EditSession(_item().copyWith(catalogueId: 'shearwater-perdix-2'));
    holdGearCatalogueReview(
      session,
      offerFor(session.working, _perdix),
      const GearCatalogueNotThisModel(),
    );
    expect(session.valueOf(gearCatalogueIdField), isNull);
    expect(session.valueOf(gearCatalogueAnswersField).notSame, {
      'shearwater-perdix-2',
    });
  });
}
