import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:submersion/core/constants/site_detail_sections.dart';
import 'package:submersion/l10n/arb/app_localizations.dart';

List<SiteDetailSectionId> _ids(List<SiteDetailSectionConfig> list) => [
  for (final s in list) s.id,
];

void main() {
  group('SiteDetailSectionId', () {
    test('declares the order the site page shipped with', () {
      expect(SiteDetailSectionId.values, const [
        SiteDetailSectionId.diveStatistics,
        SiteDetailSectionId.description,
        SiteDetailSectionId.location,
        SiteDetailSectionId.depth,
        SiteDetailSectionId.altitude,
        SiteDetailSectionId.features,
        SiteDetailSectionId.tide,
        SiteDetailSectionId.reefHealth,
        SiteDetailSectionId.marineLife,
        SiteDetailSectionId.media,
        SiteDetailSectionId.tags,
        SiteDetailSectionId.difficulty,
        SiteDetailSectionId.rating,
        SiteDetailSectionId.hazards,
        SiteDetailSectionId.access,
        SiteDetailSectionId.notes,
      ]);
    });

    test('each card is named with the title the card itself shows', () {
      final l10n = lookupAppLocalizations(const Locale('en'));
      expect(
        {
          for (final id in SiteDetailSectionId.values)
            id: id.localizedDisplayName(l10n),
        },
        const {
          SiteDetailSectionId.diveStatistics: 'Dives at this Site',
          SiteDetailSectionId.description: 'Description',
          SiteDetailSectionId.location: 'Location',
          SiteDetailSectionId.depth: 'Depth Range',
          SiteDetailSectionId.altitude: 'Altitude',
          SiteDetailSectionId.features: 'Features',
          SiteDetailSectionId.tide: 'Tides',
          SiteDetailSectionId.reefHealth: 'Ecosystem',
          SiteDetailSectionId.marineLife: 'Species',
          SiteDetailSectionId.media: 'Site Media',
          SiteDetailSectionId.tags: 'Tags',
          SiteDetailSectionId.difficulty: 'Difficulty Level',
          SiteDetailSectionId.rating: 'Rating',
          SiteDetailSectionId.hazards: 'Hazards & Safety',
          SiteDetailSectionId.access: 'Access & Logistics',
          SiteDetailSectionId.notes: 'Notes',
        },
      );
    });

    test('every card has a description in every locale', () {
      for (final locale in AppLocalizations.supportedLocales) {
        final l10n = lookupAppLocalizations(locale);
        for (final id in SiteDetailSectionId.values) {
          expect(
            id.localizedDescription(l10n),
            isNotEmpty,
            reason: '${locale.languageCode} ${id.name}',
          );
        }
      }
    });

    test('every card has its own icon', () {
      final icons = {for (final id in SiteDetailSectionId.values) id.icon};
      expect(icons.length, SiteDetailSectionId.values.length);
    });
  });

  group('SiteDetailSectionConfig', () {
    test('the defaults list every card visible and folded, in order', () {
      const defaults = SiteDetailSectionConfig.defaultSections;
      expect(_ids(defaults), SiteDetailSectionId.values);
      expect(defaults.every((s) => s.visible && !s.expanded), isTrue);
    });

    test('toJson writes expanded only when a card is unfolded', () {
      expect(
        const SiteDetailSectionConfig(
          id: SiteDetailSectionId.notes,
          visible: false,
        ).toJson(),
        {'id': 'notes', 'visible': false},
      );
      expect(
        const SiteDetailSectionConfig(
          id: SiteDetailSectionId.notes,
          visible: true,
          expanded: true,
        ).toJson(),
        {'id': 'notes', 'visible': true, 'expanded': true},
      );
    });

    test('a custom order round-trips through JSON', () {
      final custom = [
        for (final id in SiteDetailSectionId.values.reversed)
          SiteDetailSectionConfig(
            id: id,
            visible: id != SiteDetailSectionId.notes,
            expanded: id == SiteDetailSectionId.depth,
          ),
      ];
      final back = SiteDetailSectionConfig.sectionsFromJson(
        SiteDetailSectionConfig.sectionsToJson(custom),
      );
      expect(_ids(back), _ids(custom));
      expect(
        [for (final s in back) s.visible],
        [for (final s in custom) s.visible],
      );
      expect(
        [for (final s in back) s.expanded],
        [for (final s in custom) s.expanded],
      );
    });

    test('null, empty and unreadable values read back as the defaults', () {
      for (final json in [null, '', 'not json', '{}', '[]']) {
        expect(
          _ids(SiteDetailSectionConfig.sectionsFromJson(json)),
          SiteDetailSectionId.values,
          reason: '$json',
        );
      }
    });

    test('unknown ids are dropped and known ones kept', () {
      final result = SiteDetailSectionConfig.sectionsFromJson(
        '[{"id":"bogus","visible":false},{"id":"notes","visible":false}]',
      );
      expect(result.length, SiteDetailSectionId.values.length);
      expect(
        result.firstWhere((s) => s.id == SiteDetailSectionId.notes).visible,
        isFalse,
      );
    });

    test('settings saved while Map was a card still read back', () {
      // Map was the first card before it became the pinned header's map.
      // A diver's stored order still names it, and nothing rewrites that
      // row, so the read has to drop it and keep the rest of the order.
      final result = SiteDetailSectionConfig.sectionsFromJson(
        '[{"id":"map","visible":false},'
        '{"id":"notes","visible":false},'
        '{"id":"description","visible":true}]',
      );

      // The saved cards keep their order and their visibility; the entry no
      // card answers to is simply dropped, and the rest are filled in.
      final ids = _ids(result);
      expect(
        ids.indexOf(SiteDetailSectionId.notes),
        lessThan(ids.indexOf(SiteDetailSectionId.description)),
      );
      expect(
        result.firstWhere((s) => s.id == SiteDetailSectionId.notes).visible,
        isFalse,
      );
      expect(result.length, SiteDetailSectionId.values.length);
    });

    test('a card missing from a saved order lands after its neighbour', () {
      // A saved order without Altitude, which belongs right after Depth.
      final saved = [
        for (final id in SiteDetailSectionId.values.reversed)
          if (id != SiteDetailSectionId.altitude)
            SiteDetailSectionConfig(id: id, visible: true),
      ];
      final ids = _ids(
        SiteDetailSectionConfig.sectionsFromJson(
          SiteDetailSectionConfig.sectionsToJson(saved),
        ),
      );
      expect(
        ids.indexOf(SiteDetailSectionId.altitude),
        ids.indexOf(SiteDetailSectionId.depth) + 1,
      );
    });

    test('moveRenderedSection leaves unrendered cards in place', () {
      const rendered = [
        SiteDetailSectionId.description,
        SiteDetailSectionId.depth,
        SiteDetailSectionId.notes,
      ];
      final ids = _ids(
        SiteDetailSectionConfig.moveRenderedSection(
          List.of(SiteDetailSectionConfig.defaultSections),
          rendered,
          2,
          0,
        ),
      );
      expect(ids.first, SiteDetailSectionId.diveStatistics);
      expect(
        ids.indexOf(SiteDetailSectionId.notes),
        ids.indexOf(SiteDetailSectionId.description) - 1,
      );
    });

    test('copyWith keeps the id and changes only what it is given', () {
      const config = SiteDetailSectionConfig(
        id: SiteDetailSectionId.tide,
        visible: true,
      );
      final hidden = config.copyWith(visible: false);
      expect(hidden.id, SiteDetailSectionId.tide);
      expect(hidden.visible, isFalse);
      expect(hidden.expanded, isFalse);
      expect(config.copyWith(expanded: true).visible, isTrue);
    });
  });
}
