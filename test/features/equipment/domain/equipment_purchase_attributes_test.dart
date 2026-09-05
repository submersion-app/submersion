import 'package:flutter_test/flutter_test.dart';

import 'package:submersion/core/constants/enums.dart';
import 'package:submersion/features/equipment/domain/constants/equipment_attribute_catalog.dart';
import 'package:submersion/features/equipment/domain/entities/equipment_attribute.dart';
import 'package:submersion/features/equipment/domain/entities/equipment_item.dart';

void main() {
  group('purchase attribute catalog', () {
    test('every equipment type offers SKU, retailer and product URL', () {
      for (final type in EquipmentType.values) {
        final keys = EquipmentAttributeCatalog.attributesFor(
          type,
        ).map((d) => d.key).toList();
        expect(
          keys,
          containsAll([
            EquipmentAttrKeys.sku,
            EquipmentAttrKeys.retailer,
            EquipmentAttrKeys.productUrl,
          ]),
          reason: '${type.name} is missing the purchase-record attributes',
        );
      }
    });

    test('purchase attributes are grouped apart from the physical specs', () {
      for (final key in [
        EquipmentAttrKeys.sku,
        EquipmentAttrKeys.retailer,
        EquipmentAttrKeys.productUrl,
      ]) {
        expect(
          EquipmentAttributeCatalog.defFor(key)?.group,
          AttributeGroup.purchase,
          reason: key,
        );
      }
      // The spec group is the default, so nothing else drifts into the
      // purchase block by accident.
      expect(
        EquipmentAttributeCatalog.defFor(EquipmentAttrKeys.size)?.group,
        AttributeGroup.spec,
      );
      expect(
        EquipmentAttributeCatalog.defFor(EquipmentAttrKeys.buoyancyKg)?.group,
        AttributeGroup.spec,
      );
    });

    test('purchase attributes come last, after the universal ones', () {
      final keys = EquipmentAttributeCatalog.attributesFor(
        EquipmentType.other,
      ).map((d) => d.key).toList();
      expect(keys, [
        EquipmentAttrKeys.buoyancyKg,
        EquipmentAttrKeys.dryWeightKg,
        EquipmentAttrKeys.sku,
        EquipmentAttrKeys.retailer,
        EquipmentAttrKeys.productUrl,
      ]);
    });

    test('SKU and retailer are plain text, the product link is a url', () {
      expect(
        EquipmentAttributeCatalog.defFor(EquipmentAttrKeys.sku)?.kind,
        AttributeKind.text,
      );
      expect(
        EquipmentAttributeCatalog.defFor(EquipmentAttrKeys.retailer)?.kind,
        AttributeKind.text,
      );
      expect(
        EquipmentAttributeCatalog.defFor(EquipmentAttrKeys.productUrl)?.kind,
        AttributeKind.url,
      );
    });
  });

  group('parseWebLink', () {
    test('accepts a full https url unchanged', () {
      expect(
        parseWebLink('https://shop.example.com/reg?sku=42').toString(),
        'https://shop.example.com/reg?sku=42',
      );
    });

    test('assumes https when the diver pastes a bare host', () {
      // Retailers are quoted as "scubashop.com" far more often than with a
      // scheme; refusing those would make the field feel broken.
      expect(
        parseWebLink('scubashop.com/item/1').toString(),
        'https://scubashop.com/item/1',
      );
      expect(
        parseWebLink('www.scubashop.com').toString(),
        'https://www.scubashop.com',
      );
    });

    test('keeps an explicit http scheme', () {
      expect(parseWebLink('http://old.example.com')?.scheme, 'http');
    });

    test('reads a bare host with a port as a host, not a scheme', () {
      // RFC 3986 allows dots in a scheme, so a naive scheme check parses
      // "shop.example.com:8080/item" as scheme "shop.example.com" and then
      // rejects it. Retailers do quote ports.
      expect(
        parseWebLink('shop.example.com:8080/item').toString(),
        'https://shop.example.com:8080/item',
      );
      expect(parseWebLink('shop.example.com:8080')?.port, 8080);
      expect(parseWebLink('shop.example.com:8080')?.host, 'shop.example.com');
    });

    test('refuses non-web schemes', () {
      // The stored value is handed to url_launcher, so anything that is not
      // http(s) is a launch we must never make on the diver's behalf.
      expect(parseWebLink('javascript:alert(1)'), isNull);
      expect(parseWebLink('file:///etc/passwd'), isNull);
      expect(parseWebLink('mailto:shop@example.com'), isNull);
    });

    test('a dotless prefix is still treated as a scheme and refused', () {
      // The host:port fix keys on the dot. Anything without one is a real
      // scheme, and prepending https:// to it would be the dangerous
      // substitution: "https://mailto:shop@example.com" parses as userInfo
      // "mailto:shop" on host "example.com", conjuring a launchable website
      // out of a mailto.
      expect(parseWebLink('mailto:shop@example.com'), isNull);
      expect(parseWebLink('ftp://files.example.com'), isNull);
      expect(parseWebLink('localhost:3000'), isNull);
    });

    test('refuses a userInfo host swap', () {
      // "shop.example.com@evil.com" parses with host evil.com while the
      // detail row still displays the stored text, so what the diver reads
      // and what the tap opens are different hosts. Nothing about a product
      // listing needs credentials in the URL, and the value can arrive from
      // a synced device or an import rather than from this diver's keyboard.
      expect(parseWebLink('shop.example.com@evil.com'), isNull);
      expect(parseWebLink('https://shop.example.com@evil.com/mk25'), isNull);
      expect(parseWebLink('user:pw@shop.example.com'), isNull);
    });

    test('refuses values that are not links at all', () {
      expect(parseWebLink(''), isNull);
      expect(parseWebLink('   '), isNull);
      expect(parseWebLink('no dots here'), isNull);
      expect(parseWebLink('receipt in the drawer'), isNull);
      expect(parseWebLink('https://'), isNull);
    });
  });

  group('EquipmentItem purchase getters', () {
    EquipmentItem itemWith(List<EquipmentAttribute> attrs) => EquipmentItem(
      id: 'e1',
      name: 'Reg',
      type: EquipmentType.regulator,
      attributes: attrs,
    );

    test('read through to the curated attribute rows', () {
      final item = itemWith([
        EquipmentAttribute.curated(
          equipmentId: 'e1',
          key: EquipmentAttrKeys.sku,
        ).copyWith(valueText: 'SP-MK25-EVO'),
        EquipmentAttribute.curated(
          equipmentId: 'e1',
          key: EquipmentAttrKeys.retailer,
        ).copyWith(valueText: 'Dive Shop Ltd'),
        EquipmentAttribute.curated(
          equipmentId: 'e1',
          key: EquipmentAttrKeys.productUrl,
        ).copyWith(valueText: 'https://example.com/mk25'),
      ]);

      expect(item.sku, 'SP-MK25-EVO');
      expect(item.retailer, 'Dive Shop Ltd');
      expect(item.productUrl, 'https://example.com/mk25');
    });

    test('are null when nothing was recorded', () {
      final item = itemWith(const []);
      expect(item.sku, isNull);
      expect(item.retailer, isNull);
      expect(item.productUrl, isNull);
    });
  });
}
