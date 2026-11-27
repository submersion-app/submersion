import 'dart:convert';

import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:submersion/core/constants/equipment_detail_sections.dart';
import 'package:submersion/l10n/arb/app_localizations.dart';

List<EquipmentDetailSectionId> _ids(List<EquipmentDetailSectionConfig> list) =>
    [for (final s in list) s.id];

void main() {
  group('EquipmentDetailSectionId', () {
    test('declares the order the page shipped with (issue #4975)', () {
      expect(EquipmentDetailSectionId.values, const [
        EquipmentDetailSectionId.diveComputer,
        EquipmentDetailSectionId.details,
        EquipmentDetailSectionId.transmitter,
        EquipmentDetailSectionId.location,
        EquipmentDetailSectionId.passport,
        EquipmentDetailSectionId.twinSet,
        EquipmentDetailSectionId.serviceClocks,
        EquipmentDetailSectionId.exposure,
        EquipmentDetailSectionId.condition,
        EquipmentDetailSectionId.childItems,
        EquipmentDetailSectionId.photos,
        EquipmentDetailSectionId.observations,
        EquipmentDetailSectionId.components,
        EquipmentDetailSectionId.unitConfigurations,
        EquipmentDetailSectionId.linkedFiles,
        EquipmentDetailSectionId.sharingHistory,
        EquipmentDetailSectionId.serviceHistory,
        EquipmentDetailSectionId.notes,
        EquipmentDetailSectionId.documents,
      ]);
    });

    test('each card is named with the title the card itself shows', () {
      final l10n = lookupAppLocalizations(const Locale('en'));
      expect(
        {
          for (final id in EquipmentDetailSectionId.values)
            id: id.localizedDisplayName(l10n),
        },
        const {
          EquipmentDetailSectionId.diveComputer: 'Dive Computer',
          EquipmentDetailSectionId.details: 'Details',
          EquipmentDetailSectionId.transmitter: 'Transmitter',
          EquipmentDetailSectionId.location: 'Location',
          EquipmentDetailSectionId.passport: 'Passport',
          EquipmentDetailSectionId.twinSet: 'Twin set',
          EquipmentDetailSectionId.serviceClocks: 'Service clocks',
          EquipmentDetailSectionId.exposure: 'Exposure',
          EquipmentDetailSectionId.condition: 'Condition',
          EquipmentDetailSectionId.childItems: 'Installed parts',
          EquipmentDetailSectionId.photos: 'Photos',
          EquipmentDetailSectionId.observations: 'Check-ins',
          EquipmentDetailSectionId.components: 'Components',
          EquipmentDetailSectionId.unitConfigurations: 'Configurations',
          EquipmentDetailSectionId.linkedFiles: 'Linked files',
          EquipmentDetailSectionId.sharingHistory: 'Usage and sharing',
          EquipmentDetailSectionId.serviceHistory: 'Service History',
          EquipmentDetailSectionId.notes: 'Notes',
          EquipmentDetailSectionId.documents: 'Documents',
        },
      );
    });

    test('every card has a description', () {
      final l10n = lookupAppLocalizations(const Locale('en'));
      for (final id in EquipmentDetailSectionId.values) {
        expect(id.localizedDescription(l10n), isNotEmpty, reason: id.name);
      }
    });
  });

  group('EquipmentDetailSectionConfig', () {
    test('the defaults list every card, visible, in declaration order', () {
      const defaults = EquipmentDetailSectionConfig.defaultSections;
      expect(_ids(defaults), EquipmentDetailSectionId.values);
      expect(defaults.every((s) => s.visible), isTrue);
    });

    test('a saved order survives a JSON round trip', () {
      final saved = [
        for (final id in EquipmentDetailSectionId.values.reversed)
          EquipmentDetailSectionConfig(
            id: id,
            visible: id != EquipmentDetailSectionId.exposure,
          ),
      ];
      final read = EquipmentDetailSectionConfig.sectionsFromJson(
        EquipmentDetailSectionConfig.sectionsToJson(saved),
      );
      expect(_ids(read), EquipmentDetailSectionId.values.reversed);
      expect(
        read
            .firstWhere((s) => s.id == EquipmentDetailSectionId.exposure)
            .visible,
        isFalse,
      );
    });

    test('null, empty and unreadable JSON read as the defaults', () {
      for (final json in [null, '', 'not json', '{}', '[]', '[1, 2]']) {
        expect(
          _ids(EquipmentDetailSectionConfig.sectionsFromJson(json)),
          EquipmentDetailSectionId.values,
          reason: '$json',
        );
      }
    });

    test('unknown and repeated ids are dropped', () {
      final read = EquipmentDetailSectionConfig.sectionsFromJson(
        jsonEncode([
          {'id': 'notes', 'visible': false},
          {'id': 'fromTheFuture', 'visible': true},
          {'id': 'notes', 'visible': true},
          {'id': 42},
        ]),
      );
      expect(read.length, EquipmentDetailSectionId.values.length);
      expect(read.first.id, EquipmentDetailSectionId.notes);
      expect(read.first.visible, isFalse);
    });

    test('a missing visible flag reads as visible', () {
      final read = EquipmentDetailSectionConfig.sectionsFromJson(
        jsonEncode([
          {'id': 'documents'},
        ]),
      );
      expect(read.first.id, EquipmentDetailSectionId.documents);
      expect(read.first.visible, isTrue);
    });

    test('a card missing from a saved order joins it after its '
        'default predecessor', () {
      // A saved order from before Exposure existed, Service clocks moved
      // to the top.
      final saved = [
        const EquipmentDetailSectionConfig(
          id: EquipmentDetailSectionId.serviceClocks,
          visible: true,
        ),
        for (final id in EquipmentDetailSectionId.values)
          if (id != EquipmentDetailSectionId.serviceClocks &&
              id != EquipmentDetailSectionId.exposure)
            EquipmentDetailSectionConfig(id: id, visible: true),
      ];
      final read = EquipmentDetailSectionConfig.ensureAllSections(saved);
      final ids = _ids(read);
      expect(ids.first, EquipmentDetailSectionId.serviceClocks);
      expect(
        ids.indexOf(EquipmentDetailSectionId.exposure),
        ids.indexOf(EquipmentDetailSectionId.serviceClocks) + 1,
      );
    });

    test('a drop moves the card and keeps the others in place', () {
      final moved = EquipmentDetailSectionConfig.moveRenderedSection(
        EquipmentDetailSectionConfig.defaultSections,
        EquipmentDetailSectionId.values,
        EquipmentDetailSectionId.values.indexOf(
          EquipmentDetailSectionId.serviceHistory,
        ),
        0,
      );
      expect(moved.first.id, EquipmentDetailSectionId.serviceHistory);
      expect(moved.length, EquipmentDetailSectionId.values.length);
    });

    test('copyWith changes only the visibility', () {
      const config = EquipmentDetailSectionConfig(
        id: EquipmentDetailSectionId.photos,
        visible: true,
      );
      final hidden = config.copyWith(visible: false);
      expect(hidden.id, EquipmentDetailSectionId.photos);
      expect(hidden.visible, isFalse);
      expect(config.copyWith().visible, isTrue);
    });
  });
}
