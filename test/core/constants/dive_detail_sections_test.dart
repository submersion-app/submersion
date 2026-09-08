import 'dart:convert';
import 'dart:ui';

import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/core/constants/dive_detail_sections.dart';
import 'package:submersion/l10n/arb/app_localizations.dart';

void main() {
  group('DiveDetailSectionId', () {
    // Deliberate canary. Adding a section is a four-place change that the
    // compiler only partly checks, so this failing is the prompt to also
    // update defaultSections and the ARB keys for the localized switches.
    test('section count changes are intentional', () {
      expect(DiveDetailSectionId.values.length, 23);
    });

    test('values match expected IDs', () {
      expect(DiveDetailSectionId.values.first, DiveDetailSectionId.profile);
      expect(DiveDetailSectionId.values.last, DiveDetailSectionId.dataSources);
    });
  });

  group('DiveDetailSectionConfig', () {
    test('constructs with required fields', () {
      const config = DiveDetailSectionConfig(
        id: DiveDetailSectionId.decoStatus,
        visible: true,
      );
      expect(config.id, DiveDetailSectionId.decoStatus);
      expect(config.visible, true);
    });

    test('copyWith updates visible', () {
      const config = DiveDetailSectionConfig(
        id: DiveDetailSectionId.tanks,
        visible: true,
      );
      final updated = config.copyWith(visible: false);
      expect(updated.id, DiveDetailSectionId.tanks);
      expect(updated.visible, false);
    });

    test('toJson serializes correctly', () {
      const config = DiveDetailSectionConfig(
        id: DiveDetailSectionId.environment,
        visible: false,
      );
      final json = config.toJson();
      expect(json['id'], 'environment');
      expect(json['visible'], false);
    });

    test('fromJson deserializes correctly', () {
      final config = DiveDetailSectionConfig.fromJson({
        'id': 'environment',
        'visible': false,
      });
      expect(config.id, DiveDetailSectionId.environment);
      expect(config.visible, false);
    });

    test('fromJson ignores unknown section IDs', () {
      final config = DiveDetailSectionConfig.tryFromJson({
        'id': 'nonexistent',
        'visible': true,
      });
      expect(config, isNull);
    });
  });

  group('DiveDetailSectionConfig list serialization', () {
    test('sectionsToJson produces valid JSON string', () {
      const sections = [
        DiveDetailSectionConfig(
          id: DiveDetailSectionId.decoStatus,
          visible: true,
        ),
        DiveDetailSectionConfig(
          id: DiveDetailSectionId.details,
          visible: false,
        ),
      ];
      final jsonStr = DiveDetailSectionConfig.sectionsToJson(sections);
      final decoded = jsonDecode(jsonStr) as List;
      expect(decoded.length, 2);
      expect(decoded[0]['id'], 'decoStatus');
      expect(decoded[1]['visible'], false);
    });

    test('sectionsFromJson parses and ensures all sections', () {
      const jsonStr =
          '[{"id":"decoStatus","visible":true},{"id":"details","visible":false}]';
      final sections = DiveDetailSectionConfig.sectionsFromJson(jsonStr);
      expect(sections.length, DiveDetailSectionId.values.length);
      // Saved entries keep their relative order and their visibility.
      final ids = sections.map((s) => s.id).toList();
      expect(
        ids.indexOf(DiveDetailSectionId.decoStatus),
        lessThan(ids.indexOf(DiveDetailSectionId.details)),
      );
      expect(
        sections
            .firstWhere((s) => s.id == DiveDetailSectionId.decoStatus)
            .visible,
        true,
      );
      expect(
        sections.firstWhere((s) => s.id == DiveDetailSectionId.details).visible,
        false,
      );
      // Everything the saved config never named comes back visible.
      expect(
        sections
            .where(
              (s) =>
                  s.id != DiveDetailSectionId.decoStatus &&
                  s.id != DiveDetailSectionId.details,
            )
            .every((s) => s.visible),
        true,
      );
    });

    test('sectionsFromJson skips unknown IDs and ensures all sections', () {
      const jsonStr =
          '[{"id":"decoStatus","visible":true},{"id":"unknown","visible":true},{"id":"details","visible":false}]';
      final sections = DiveDetailSectionConfig.sectionsFromJson(jsonStr);
      // unknown ids skipped, the rest filled in
      expect(sections.length, DiveDetailSectionId.values.length);
      final ids = sections.map((s) => s.id).toList();
      expect(
        ids.indexOf(DiveDetailSectionId.decoStatus),
        lessThan(ids.indexOf(DiveDetailSectionId.details)),
      );
    });

    test('sectionsFromJson returns defaults for null input', () {
      final sections = DiveDetailSectionConfig.sectionsFromJson(null);
      expect(sections.length, DiveDetailSectionId.values.length);
      expect(sections.every((s) => s.visible), true);
    });

    test('sectionsFromJson returns defaults for empty string', () {
      final sections = DiveDetailSectionConfig.sectionsFromJson('');
      expect(sections.length, DiveDetailSectionId.values.length);
    });

    test('sectionsFromJson returns defaults for invalid JSON', () {
      final sections = DiveDetailSectionConfig.sectionsFromJson('not json');
      expect(sections.length, DiveDetailSectionId.values.length);
    });
  });

  group('defaultSections', () {
    test('contains every section ID', () {
      expect(
        DiveDetailSectionConfig.defaultSections.length,
        DiveDetailSectionId.values.length,
      );
      final ids = DiveDetailSectionConfig.defaultSections
          .map((s) => s.id)
          .toSet();
      expect(ids, DiveDetailSectionId.values.toSet());
    });

    test('all sections are visible by default', () {
      expect(
        DiveDetailSectionConfig.defaultSections.every((s) => s.visible),
        true,
      );
    });

    test('order matches enum declaration order', () {
      for (var i = 0; i < DiveDetailSectionId.values.length; i++) {
        expect(
          DiveDetailSectionConfig.defaultSections[i].id,
          DiveDetailSectionId.values[i],
        );
      }
    });
  });

  group('ensureAllSections', () {
    test('fills in missing sections, keeping the saved ones in order', () {
      const saved = [
        DiveDetailSectionConfig(
          id: DiveDetailSectionId.decoStatus,
          visible: true,
        ),
        DiveDetailSectionConfig(
          id: DiveDetailSectionId.details,
          visible: false,
        ),
      ];
      final result = DiveDetailSectionConfig.ensureAllSections(saved);
      expect(result.length, DiveDetailSectionId.values.length);
      final ids = result.map((s) => s.id).toList();
      expect(
        ids.indexOf(DiveDetailSectionId.decoStatus),
        lessThan(ids.indexOf(DiveDetailSectionId.details)),
      );
      expect(
        result.firstWhere((s) => s.id == DiveDetailSectionId.details).visible,
        false,
      );
      expect(
        result
            .where((s) => s.id != DiveDetailSectionId.details)
            .every((s) => s.visible),
        true,
      );
    });

    test('lands a missing section where the default order puts it', () {
      // A config saved before the profile chart became configurable. Appended,
      // the chart would come out below the Data Sources card; it belongs at
      // the top, where the default order has it.
      const saved = [
        DiveDetailSectionConfig(
          id: DiveDetailSectionId.decoStatus,
          visible: true,
        ),
        DiveDetailSectionConfig(id: DiveDetailSectionId.notes, visible: true),
      ];
      final result = DiveDetailSectionConfig.ensureAllSections(saved);
      expect(result.first.id, DiveDetailSectionId.profile);
      final ids = result.map((s) => s.id).toList();
      // Tissue Loading follows Deco Status, as it does by default.
      expect(
        ids.indexOf(DiveDetailSectionId.tissueLoading),
        ids.indexOf(DiveDetailSectionId.decoStatus) + 1,
      );
    });

    test('keeps a missing section behind a reordered predecessor', () {
      // Notes was dragged to the top; Custom Fields, which the saved config
      // never named, follows it rather than jumping to the default position.
      const saved = [
        DiveDetailSectionConfig(id: DiveDetailSectionId.notes, visible: true),
        DiveDetailSectionConfig(id: DiveDetailSectionId.details, visible: true),
      ];
      final result = DiveDetailSectionConfig.ensureAllSections(saved);
      final ids = result.map((s) => s.id).toList();
      expect(
        ids.indexOf(DiveDetailSectionId.customFields),
        ids.indexOf(DiveDetailSectionId.notes) + 1,
      );
    });

    test('returns saved config unchanged when all sections present', () {
      const saved = DiveDetailSectionConfig.defaultSections;
      final result = DiveDetailSectionConfig.ensureAllSections(saved);
      expect(result.length, DiveDetailSectionId.values.length);
      for (var i = 0; i < DiveDetailSectionId.values.length; i++) {
        expect(result[i].id, saved[i].id);
        expect(result[i].visible, saved[i].visible);
      }
    });
  });

  group('DiveDetailSectionConfig fromJson edge cases', () {
    test('fromJson defaults visible to true when missing', () {
      final config = DiveDetailSectionConfig.fromJson({'id': 'tanks'});
      expect(config.id, DiveDetailSectionId.tanks);
      expect(config.visible, true);
    });

    test('fromJson throws for unknown id', () {
      expect(
        () => DiveDetailSectionConfig.fromJson({
          'id': 'nonexistent',
          'visible': true,
        }),
        throwsStateError,
      );
    });

    test('fromJson with visible explicitly set to false', () {
      final config = DiveDetailSectionConfig.fromJson({
        'id': 'decoStatus',
        'visible': false,
      });
      expect(config.visible, false);
    });

    test('toJson then fromJson round-trip preserves single config', () {
      const original = DiveDetailSectionConfig(
        id: DiveDetailSectionId.sightings,
        visible: false,
      );
      final json = original.toJson();
      final restored = DiveDetailSectionConfig.fromJson(json);
      expect(restored.id, original.id);
      expect(restored.visible, original.visible);
    });
  });

  group('tryFromJson', () {
    test('returns config for valid JSON map', () {
      final config = DiveDetailSectionConfig.tryFromJson({
        'id': 'media',
        'visible': true,
      });
      expect(config, isNotNull);
      expect(config!.id, DiveDetailSectionId.media);
      expect(config.visible, true);
    });

    test('returns null for missing id key', () {
      final config = DiveDetailSectionConfig.tryFromJson({'visible': true});
      expect(config, isNull);
    });

    test('returns null for non-string id', () {
      final config = DiveDetailSectionConfig.tryFromJson({
        'id': 42,
        'visible': true,
      });
      expect(config, isNull);
    });
  });

  group('DiveDetailSectionConfig copyWith edge cases', () {
    test('copyWith without arguments preserves all values', () {
      const config = DiveDetailSectionConfig(
        id: DiveDetailSectionId.environment,
        visible: false,
      );
      final copy = config.copyWith();
      expect(copy.id, DiveDetailSectionId.environment);
      expect(copy.visible, false);
    });
  });

  group('round-trip serialization', () {
    test(
      'sectionsToJson then sectionsFromJson preserves order and visibility',
      () {
        const original = [
          DiveDetailSectionConfig(
            id: DiveDetailSectionId.tanks,
            visible: false,
          ),
          DiveDetailSectionConfig(id: DiveDetailSectionId.notes, visible: true),
          DiveDetailSectionConfig(
            id: DiveDetailSectionId.decoStatus,
            visible: true,
          ),
        ];
        final json = DiveDetailSectionConfig.sectionsToJson(original);
        final restored = DiveDetailSectionConfig.sectionsFromJson(json);
        // saved entries keep their relative order, the rest fill in around
        // them at their default positions
        expect(restored.length, DiveDetailSectionId.values.length);
        final ids = restored.map((s) => s.id).toList();
        expect(
          ids.indexOf(DiveDetailSectionId.tanks),
          lessThan(ids.indexOf(DiveDetailSectionId.notes)),
        );
        expect(
          ids.indexOf(DiveDetailSectionId.notes),
          lessThan(ids.indexOf(DiveDetailSectionId.decoStatus)),
        );
        expect(
          restored.firstWhere((s) => s.id == DiveDetailSectionId.tanks).visible,
          false,
        );
      },
    );

    test('full round-trip preserves exact order', () {
      final custom = List.of(DiveDetailSectionConfig.defaultSections);
      // Reverse order and toggle some off
      final reversed = custom.reversed.toList();
      reversed[0] = reversed[0].copyWith(visible: false);
      reversed[5] = reversed[5].copyWith(visible: false);
      final json = DiveDetailSectionConfig.sectionsToJson(reversed);
      final restored = DiveDetailSectionConfig.sectionsFromJson(json);
      expect(restored.length, DiveDetailSectionId.values.length);
      for (var i = 0; i < DiveDetailSectionId.values.length; i++) {
        expect(restored[i].id, reversed[i].id);
        expect(restored[i].visible, reversed[i].visible);
      }
    });
  });

  group('ensureAllSections edge cases', () {
    test('handles empty input list', () {
      final result = DiveDetailSectionConfig.ensureAllSections([]);
      expect(result.length, DiveDetailSectionId.values.length);
      expect(result.every((s) => s.visible), true);
    });

    test('preserves custom visibility for existing sections', () {
      const saved = [
        DiveDetailSectionConfig(id: DiveDetailSectionId.tanks, visible: false),
        DiveDetailSectionConfig(
          id: DiveDetailSectionId.buddies,
          visible: false,
        ),
      ];
      final result = DiveDetailSectionConfig.ensureAllSections(saved);
      final tanksConfig = result.firstWhere(
        (s) => s.id == DiveDetailSectionId.tanks,
      );
      final buddiesConfig = result.firstWhere(
        (s) => s.id == DiveDetailSectionId.buddies,
      );
      expect(tanksConfig.visible, false);
      expect(buddiesConfig.visible, false);
    });
  });

  group('sectionsFromJson error recovery', () {
    test('returns defaults when JSON is a map instead of a list', () {
      final sections = DiveDetailSectionConfig.sectionsFromJson(
        '{"foo":"bar"}',
      );
      expect(sections.length, DiveDetailSectionId.values.length);
      expect(sections.every((s) => s.visible), true);
    });

    test('returns defaults when JSON list contains non-map items', () {
      final sections = DiveDetailSectionConfig.sectionsFromJson('[1, 2, 3]');
      expect(sections.length, DiveDetailSectionId.values.length);
      expect(sections.every((s) => s.visible), true);
    });

    test('returns defaults when all entries have unknown IDs', () {
      const jsonStr =
          '[{"id":"foo","visible":true},{"id":"bar","visible":false}]';
      final sections = DiveDetailSectionConfig.sectionsFromJson(jsonStr);
      // All unknown → parsed list empty → returns defaults
      expect(sections.length, DiveDetailSectionId.values.length);
      expect(sections.every((s) => s.visible), true);
    });

    test(
      'preserves valid entries in JSON list with mixed valid/invalid types',
      () {
        const jsonStr = '[{"id":"decoStatus","visible":true}, "not a map", 42]';
        final sections = DiveDetailSectionConfig.sectionsFromJson(jsonStr);
        // Non-Map items are skipped; the valid decoStatus entry is kept and
        // ensureAllSections fills in the rest.
        expect(sections.length, DiveDetailSectionId.values.length);
        expect(
          sections
              .firstWhere((s) => s.id == DiveDetailSectionId.decoStatus)
              .visible,
          true,
        );
      },
    );
  });

  group('sectionsFromJson with all sections present', () {
    test('returns exact list when all sections are in JSON', () {
      final allSections = DiveDetailSectionConfig.defaultSections
          .map((s) => s.toJson())
          .toList();
      final json = jsonEncode(allSections);
      final sections = DiveDetailSectionConfig.sectionsFromJson(json);
      expect(sections.length, DiveDetailSectionId.values.length);
    });
  });

  group('DiveDetailSectionId metadata', () {
    test('displayName returns non-empty string for all values', () {
      for (final id in DiveDetailSectionId.values) {
        expect(id.displayName.isNotEmpty, true);
      }
    });

    test('description returns non-empty string for all values', () {
      for (final id in DiveDetailSectionId.values) {
        expect(id.description.isNotEmpty, true);
      }
    });

    test('displayName values are correct for each section', () {
      expect(DiveDetailSectionId.profile.displayName, 'Dive Profile');
      expect(DiveDetailSectionId.decoStatus.displayName, 'Deco Status');
      expect(DiveDetailSectionId.tissueLoading.displayName, 'Tissue Loading');
      expect(
        DiveDetailSectionId.sacSegments.displayName,
        'Gas consumption by segment',
      );
      expect(DiveDetailSectionId.details.displayName, 'Details');
      expect(DiveDetailSectionId.environment.displayName, 'Environment');
      expect(DiveDetailSectionId.altitude.displayName, 'Altitude');
      expect(DiveDetailSectionId.tide.displayName, 'Tide');
      expect(DiveDetailSectionId.weights.displayName, 'Weights');
      expect(DiveDetailSectionId.tanks.displayName, 'Cylinders');
      expect(DiveDetailSectionId.buddies.displayName, 'Buddies');
      expect(DiveDetailSectionId.signatures.displayName, 'Signatures');
      expect(DiveDetailSectionId.equipment.displayName, 'Equipment');
      expect(DiveDetailSectionId.sightings.displayName, 'Species Sightings');
      expect(DiveDetailSectionId.media.displayName, 'Media');
      expect(DiveDetailSectionId.tags.displayName, 'Tags');
      expect(DiveDetailSectionId.notes.displayName, 'Notes');
      expect(DiveDetailSectionId.customFields.displayName, 'Custom Fields');
      expect(DiveDetailSectionId.dataSources.displayName, 'Data Sources');
    });

    test('description values are correct for each section', () {
      expect(
        DiveDetailSectionId.decoStatus.description,
        'NDL, ceiling, stops, O2 toxicity',
      );
      expect(
        DiveDetailSectionId.tissueLoading.description,
        'Per-compartment saturation and heat map',
      );
      expect(
        DiveDetailSectionId.sacSegments.description,
        'SAC and RMV by phase or time',
      );
      expect(
        DiveDetailSectionId.details.description,
        'Type, location, trip, dive center, interval',
      );
      expect(
        DiveDetailSectionId.environment.description,
        'Air/water temp, visibility, current',
      );
      expect(
        DiveDetailSectionId.altitude.description,
        'Altitude value, category, deco requirement',
      );
      expect(
        DiveDetailSectionId.tide.description,
        'Tide cycle graph and timing',
      );
      expect(
        DiveDetailSectionId.weights.description,
        'Weight breakdown, total weight',
      );
      expect(
        DiveDetailSectionId.tanks.description,
        'Cylinder list, gas mixes, pressures, MOD/MND, per-tank consumption',
      );
      expect(DiveDetailSectionId.buddies.description, 'Buddy list with roles');
      expect(
        DiveDetailSectionId.signatures.description,
        'Buddy/instructor signature display and capture',
      );
      expect(
        DiveDetailSectionId.equipment.description,
        'Equipment used in dive',
      );
      expect(
        DiveDetailSectionId.sightings.description,
        'Species spotted, sighting details',
      );
      expect(DiveDetailSectionId.media.description, 'Photos/videos gallery');
      expect(DiveDetailSectionId.tags.description, 'Dive tags');
      expect(DiveDetailSectionId.notes.description, 'Dive notes/description');
      expect(
        DiveDetailSectionId.customFields.description,
        'User-defined custom fields',
      );
      expect(
        DiveDetailSectionId.dataSources.description,
        'Connected dive computers, source management',
      );
    });

    test('each section has a unique displayName', () {
      final names = DiveDetailSectionId.values
          .map((id) => id.displayName)
          .toList();
      expect(names.toSet().length, names.length);
    });
  });

  group('DiveDetailSectionId localized metadata', () {
    late AppLocalizations l10n;

    setUpAll(() {
      l10n = lookupAppLocalizations(const Locale('en'));
    });

    test('localizedDisplayName returns non-empty string for all values', () {
      for (final id in DiveDetailSectionId.values) {
        expect(id.localizedDisplayName(l10n).isNotEmpty, true);
      }
    });

    test('localizedDescription returns non-empty string for all values', () {
      for (final id in DiveDetailSectionId.values) {
        expect(id.localizedDescription(l10n).isNotEmpty, true);
      }
    });

    test('localizedDisplayName matches displayName for English locale', () {
      for (final id in DiveDetailSectionId.values) {
        expect(id.localizedDisplayName(l10n), id.displayName);
      }
    });

    test('localizedDescription matches description for English locale', () {
      for (final id in DiveDetailSectionId.values) {
        expect(id.localizedDescription(l10n), id.description);
      }
    });

    test('localizedDisplayName values are correct for each section', () {
      expect(
        DiveDetailSectionId.profile.localizedDisplayName(l10n),
        'Dive Profile',
      );
      expect(
        DiveDetailSectionId.decoStatus.localizedDisplayName(l10n),
        'Deco Status',
      );
      expect(
        DiveDetailSectionId.tissueLoading.localizedDisplayName(l10n),
        'Tissue Loading',
      );
      expect(
        DiveDetailSectionId.sacSegments.localizedDisplayName(l10n),
        'Gas consumption by segment',
      );
      expect(DiveDetailSectionId.details.localizedDisplayName(l10n), 'Details');
      expect(
        DiveDetailSectionId.environment.localizedDisplayName(l10n),
        'Environment',
      );
      expect(
        DiveDetailSectionId.altitude.localizedDisplayName(l10n),
        'Altitude',
      );
      expect(DiveDetailSectionId.tide.localizedDisplayName(l10n), 'Tide');
      expect(DiveDetailSectionId.weights.localizedDisplayName(l10n), 'Weights');
      expect(DiveDetailSectionId.tanks.localizedDisplayName(l10n), 'Cylinders');
      expect(DiveDetailSectionId.buddies.localizedDisplayName(l10n), 'Buddies');
      expect(
        DiveDetailSectionId.signatures.localizedDisplayName(l10n),
        'Signatures',
      );
      expect(
        DiveDetailSectionId.equipment.localizedDisplayName(l10n),
        'Equipment',
      );
      expect(
        DiveDetailSectionId.sightings.localizedDisplayName(l10n),
        'Species Sightings',
      );
      expect(DiveDetailSectionId.media.localizedDisplayName(l10n), 'Media');
      expect(DiveDetailSectionId.tags.localizedDisplayName(l10n), 'Tags');
      expect(DiveDetailSectionId.notes.localizedDisplayName(l10n), 'Notes');
      expect(
        DiveDetailSectionId.customFields.localizedDisplayName(l10n),
        'Custom Fields',
      );
      expect(
        DiveDetailSectionId.dataSources.localizedDisplayName(l10n),
        'Data Sources',
      );
    });

    test('localizedDescription values are correct for each section', () {
      expect(
        DiveDetailSectionId.decoStatus.localizedDescription(l10n),
        'NDL, ceiling, stops, O2 toxicity',
      );
      expect(
        DiveDetailSectionId.sacSegments.localizedDescription(l10n),
        'SAC and RMV by phase or time',
      );
      expect(
        DiveDetailSectionId.details.localizedDescription(l10n),
        'Type, location, trip, dive center, interval',
      );
      expect(
        DiveDetailSectionId.environment.localizedDescription(l10n),
        'Air/water temp, visibility, current',
      );
      expect(
        DiveDetailSectionId.altitude.localizedDescription(l10n),
        'Altitude value, category, deco requirement',
      );
      expect(
        DiveDetailSectionId.tide.localizedDescription(l10n),
        'Tide cycle graph and timing',
      );
      expect(
        DiveDetailSectionId.weights.localizedDescription(l10n),
        'Weight breakdown, total weight',
      );
      expect(
        DiveDetailSectionId.tanks.localizedDescription(l10n),
        'Cylinder list, gas mixes, pressures, MOD/MND, per-tank consumption',
      );
      expect(
        DiveDetailSectionId.buddies.localizedDescription(l10n),
        'Buddy list with roles',
      );
      expect(
        DiveDetailSectionId.signatures.localizedDescription(l10n),
        'Buddy/instructor signature display and capture',
      );
      expect(
        DiveDetailSectionId.equipment.localizedDescription(l10n),
        'Equipment used in dive',
      );
      expect(
        DiveDetailSectionId.sightings.localizedDescription(l10n),
        'Species spotted, sighting details',
      );
      expect(
        DiveDetailSectionId.media.localizedDescription(l10n),
        'Photos/videos gallery',
      );
      expect(DiveDetailSectionId.tags.localizedDescription(l10n), 'Dive tags');
      expect(
        DiveDetailSectionId.notes.localizedDescription(l10n),
        'Dive notes/description',
      );
      expect(
        DiveDetailSectionId.customFields.localizedDescription(l10n),
        'User-defined custom fields',
      );
      expect(
        DiveDetailSectionId.dataSources.localizedDescription(l10n),
        'Connected dive computers, source management',
      );
    });

    test('each section has a unique localizedDisplayName', () {
      final names = DiveDetailSectionId.values
          .map((id) => id.localizedDisplayName(l10n))
          .toList();
      expect(names.toSet().length, names.length);
    });
  });

  group('defaultSections stays in sync with the enum', () {
    // defaultSections is a hand-maintained const list that duplicates
    // DiveDetailSectionId. Adding an enum value without adding it here
    // compiles fine but omits the section from every fresh install's
    // default layout, where it would simply never appear.
    test('covers every enum value exactly once, in declaration order', () {
      final defaults = DiveDetailSectionConfig.defaultSections
          .map((s) => s.id)
          .toList();
      expect(
        defaults,
        DiveDetailSectionId.values,
        reason:
            'defaultSections drifted from DiveDetailSectionId; add the '
            'missing section in enum declaration order',
      );
    });
  });

  group('reef health section', () {
    test('is a registered section with name and description', () {
      expect(
        DiveDetailSectionId.values,
        contains(DiveDetailSectionId.reefHealth),
      );
      expect(DiveDetailSectionId.reefHealth.displayName, 'Water Conditions');
      expect(DiveDetailSectionId.reefHealth.description.isNotEmpty, isTrue);
    });

    test('ensureAllSections appends reefHealth to a legacy config', () {
      const legacy = [
        DiveDetailSectionConfig(
          id: DiveDetailSectionId.decoStatus,
          visible: true,
        ),
        DiveDetailSectionConfig(id: DiveDetailSectionId.tide, visible: true),
      ];
      final result = DiveDetailSectionConfig.ensureAllSections(legacy);
      expect(result.map((s) => s.id), contains(DiveDetailSectionId.reefHealth));
    });

    test('stays visible for gauge dives', () {
      expect(DiveDetailSectionId.reefHealth.hiddenInGaugeMode, isFalse);
    });
  });

  group('buoyancy section', () {
    test('is a registered section with a non-empty name', () {
      expect(
        DiveDetailSectionId.values,
        contains(DiveDetailSectionId.buoyancy),
      );
      expect(DiveDetailSectionId.buoyancy.displayName.isNotEmpty, isTrue);
    });

    test('ensureAllSections appends buoyancy to a legacy config', () {
      const legacy = [
        DiveDetailSectionConfig(
          id: DiveDetailSectionId.decoStatus,
          visible: true,
        ),
        DiveDetailSectionConfig(id: DiveDetailSectionId.tanks, visible: true),
      ];
      final result = DiveDetailSectionConfig.ensureAllSections(legacy);
      expect(result.map((s) => s.id), contains(DiveDetailSectionId.buoyancy));
    });

    test('round-trips through JSON', () {
      const config = DiveDetailSectionConfig(
        id: DiveDetailSectionId.buoyancy,
        visible: false,
      );
      final restored = DiveDetailSectionConfig.fromJson(config.toJson());
      expect(restored.id, DiveDetailSectionId.buoyancy);
      expect(restored.visible, isFalse);
    });

    test('stays visible for gauge dives', () {
      expect(DiveDetailSectionId.buoyancy.hiddenInGaugeMode, isFalse);
    });
  });

  group('hiddenInGaugeMode', () {
    test('gauge hides deco, tissue, SAC segments, and cylinders only', () {
      final hidden = DiveDetailSectionId.values
          .where((s) => s.hiddenInGaugeMode)
          .toSet();
      expect(hidden, {
        DiveDetailSectionId.decoStatus,
        DiveDetailSectionId.tissueLoading,
        DiveDetailSectionId.sacSegments,
        DiveDetailSectionId.tanks,
      });
    });

    test('the profile chart stays -- depth over time is what a gauge logs', () {
      expect(DiveDetailSectionId.profile.hiddenInGaugeMode, isFalse);
    });

    test('sections a gauge diver still wants remain visible', () {
      expect(DiveDetailSectionId.environment.hiddenInGaugeMode, isFalse);
      expect(DiveDetailSectionId.weights.hiddenInGaugeMode, isFalse);
      expect(DiveDetailSectionId.equipment.hiddenInGaugeMode, isFalse);
      expect(DiveDetailSectionId.notes.hiddenInGaugeMode, isFalse);
    });
  });

  // The deco/tissue panel used to be one section, `decoO2`. Orders saved
  // before the split still name it, and a diver who had hidden the panel must
  // not find both halves switched back on.
  group('legacy decoO2 configs', () {
    test('expands into Deco Status and Tissue Loading, in that order', () {
      const jsonStr = '[{"id":"decoO2","visible":true}]';
      final sections = DiveDetailSectionConfig.sectionsFromJson(jsonStr);
      final ids = sections.map((s) => s.id).toList();
      expect(
        ids.indexOf(DiveDetailSectionId.tissueLoading),
        ids.indexOf(DiveDetailSectionId.decoStatus) + 1,
      );
    });

    test('carries the panel\'s visibility to both halves', () {
      const jsonStr = '[{"id":"decoO2","visible":false}]';
      final sections = DiveDetailSectionConfig.sectionsFromJson(jsonStr);
      expect(
        sections
            .firstWhere((s) => s.id == DiveDetailSectionId.decoStatus)
            .visible,
        isFalse,
      );
      expect(
        sections
            .firstWhere((s) => s.id == DiveDetailSectionId.tissueLoading)
            .visible,
        isFalse,
      );
    });

    test('stays adjacent, and stays where the diver dragged the panel', () {
      // The panel was dragged below Notes and above Cylinders. Both halves
      // keep that slot -- they do not jump back to the default position --
      // and they stay next to each other so the pair can still form.
      const jsonStr =
          '[{"id":"notes","visible":true},{"id":"decoO2","visible":true},'
          '{"id":"tanks","visible":true}]';
      final ids = DiveDetailSectionConfig.sectionsFromJson(
        jsonStr,
      ).map((s) => s.id).toList();
      expect(
        ids.indexOf(DiveDetailSectionId.tissueLoading),
        ids.indexOf(DiveDetailSectionId.decoStatus) + 1,
      );
      expect(
        ids.indexOf(DiveDetailSectionId.decoStatus),
        greaterThan(ids.indexOf(DiveDetailSectionId.notes)),
      );
      expect(
        ids.indexOf(DiveDetailSectionId.tissueLoading),
        lessThan(ids.indexOf(DiveDetailSectionId.tanks)),
      );
    });

    test('a saved order that never knew the profile chart still gets it', () {
      const jsonStr =
          '[{"id":"decoO2","visible":true},'
          '{"id":"details","visible":true}]';
      final sections = DiveDetailSectionConfig.sectionsFromJson(jsonStr);
      expect(sections.first.id, DiveDetailSectionId.profile);
      expect(sections.first.visible, isTrue);
      expect(sections.length, DiveDetailSectionId.values.length);
    });
  });

  group('icons', () {
    test('every section has its own icon', () {
      final icons = DiveDetailSectionId.values.map((id) => id.icon).toSet();
      expect(icons.length, DiveDetailSectionId.values.length);
    });
  });

  group('DiveDetailSectionConfig expanded', () {
    test('defaults to folded', () {
      const config = DiveDetailSectionConfig(
        id: DiveDetailSectionId.notes,
        visible: true,
      );
      expect(config.expanded, isFalse);
      expect(
        DiveDetailSectionConfig.defaultSections.every((s) => !s.expanded),
        isTrue,
      );
    });

    test('round-trips through JSON', () {
      const config = DiveDetailSectionConfig(
        id: DiveDetailSectionId.notes,
        visible: true,
        expanded: true,
      );
      final restored = DiveDetailSectionConfig.fromJson(config.toJson());
      expect(restored.expanded, isTrue);
      expect(restored.id, DiveDetailSectionId.notes);
      expect(restored.visible, isTrue);
    });

    // Folded is the default, so writing the flag only when it is set keeps
    // the stored blob -- and therefore the sync changeset -- unchanged for
    // divers who never unfold anything.
    test('toJson omits the flag while folded', () {
      const config = DiveDetailSectionConfig(
        id: DiveDetailSectionId.notes,
        visible: true,
      );
      expect(config.toJson().containsKey('expanded'), isFalse);
      expect(
        const DiveDetailSectionConfig(
          id: DiveDetailSectionId.notes,
          visible: true,
          expanded: true,
        ).toJson()['expanded'],
        isTrue,
      );
    });

    test('an entry saved before the flag existed reads back folded', () {
      final config = DiveDetailSectionConfig.fromJson({
        'id': 'notes',
        'visible': true,
      });
      expect(config.expanded, isFalse);
    });

    test('copyWith changes expanded without touching the rest', () {
      const config = DiveDetailSectionConfig(
        id: DiveDetailSectionId.tanks,
        visible: false,
      );
      final unfolded = config.copyWith(expanded: true);
      expect(unfolded.expanded, isTrue);
      expect(unfolded.visible, isFalse);
      expect(unfolded.id, DiveDetailSectionId.tanks);
      expect(config.expanded, isFalse);
    });

    test('survives a full sectionsToJson/sectionsFromJson round-trip', () {
      final sections = [
        for (final section in DiveDetailSectionConfig.defaultSections)
          section.id == DiveDetailSectionId.notes
              ? section.copyWith(expanded: true)
              : section,
      ];
      final restored = DiveDetailSectionConfig.sectionsFromJson(
        DiveDetailSectionConfig.sectionsToJson(sections),
      );
      final unfolded = restored
          .where((s) => s.expanded)
          .map((s) => s.id)
          .toList();
      expect(unfolded, [DiveDetailSectionId.notes]);
    });

    // The retired combined panel becomes two sections; a diver who had it
    // unfolded should find both halves unfolded rather than one of each.
    test('the legacy decoO2 entry carries its fold state to both halves', () {
      final restored = DiveDetailSectionConfig.sectionsFromJson(
        jsonEncode([
          {'id': 'decoO2', 'visible': true, 'expanded': true},
          {'id': 'notes', 'visible': true},
        ]),
      );
      final byId = {for (final s in restored) s.id: s};
      expect(byId[DiveDetailSectionId.decoStatus]!.expanded, isTrue);
      expect(byId[DiveDetailSectionId.tissueLoading]!.expanded, isTrue);
      expect(byId[DiveDetailSectionId.notes]!.expanded, isFalse);
    });

    // A section the saved order predates is inserted for the diver, and an
    // inserted section they have never seen must not open itself.
    test('ensureAllSections inserts missing sections folded', () {
      final filled = DiveDetailSectionConfig.ensureAllSections([
        const DiveDetailSectionConfig(
          id: DiveDetailSectionId.notes,
          visible: true,
          expanded: true,
        ),
      ]);
      final inserted = filled.where((s) => s.id != DiveDetailSectionId.notes);
      expect(inserted.every((s) => !s.expanded), isTrue);
      expect(
        filled.firstWhere((s) => s.id == DiveDetailSectionId.notes).expanded,
        isTrue,
      );
    });
  });

  group('DiveDetailSectionConfig.moveRenderedSection', () {
    List<DiveDetailSectionId> ids(List<DiveDetailSectionConfig> sections) =>
        sections.map((s) => s.id).toList();

    const a = DiveDetailSectionId.profile;
    const b = DiveDetailSectionId.notes;
    const c = DiveDetailSectionId.tanks;
    const hidden = DiveDetailSectionId.media;

    List<DiveDetailSectionConfig> configs(
      List<DiveDetailSectionId> order, {
      List<DiveDetailSectionId> invisible = const [],
    }) => [
      for (final id in order)
        DiveDetailSectionConfig(id: id, visible: !invisible.contains(id)),
    ];

    test('moves a section down', () {
      final moved = DiveDetailSectionConfig.moveRenderedSection(
        configs([a, b, c]),
        [a, b, c],
        0,
        2,
      );
      expect(ids(moved), [b, c, a]);
    });

    test('moves a section up', () {
      final moved = DiveDetailSectionConfig.moveRenderedSection(
        configs([a, b, c]),
        [a, b, c],
        2,
        0,
      );
      expect(ids(moved), [c, a, b]);
    });

    test('a drop back onto the same index changes nothing', () {
      final sections = configs([a, b, c]);
      final moved = DiveDetailSectionConfig.moveRenderedSection(
        sections,
        [a, b, c],
        1,
        1,
      );
      expect(ids(moved), [a, b, c]);
    });

    // The dive page renders only the sections that are visible and have
    // content, so a drop index in that subset is not an index into the
    // saved list.
    test('a hidden section between two rendered ones keeps its place', () {
      final moved = DiveDetailSectionConfig.moveRenderedSection(
        configs([a, hidden, b], invisible: [hidden]),
        [a, b],
        0,
        1,
      );
      expect(ids(moved), [hidden, b, a]);
      expect(moved.firstWhere((s) => s.id == hidden).visible, isFalse);
    });

    test('a section dropped last still precedes a trailing hidden one', () {
      final moved = DiveDetailSectionConfig.moveRenderedSection(
        configs([a, b, hidden], invisible: [hidden]),
        [a, b],
        0,
        1,
      );
      expect(ids(moved), [b, a, hidden]);
    });

    test('moving within a subset leaves the untouched sections alone', () {
      final moved = DiveDetailSectionConfig.moveRenderedSection(
        configs([a, b, c, hidden], invisible: [hidden]),
        [b, c],
        0,
        1,
      );
      expect(ids(moved), [a, c, b, hidden]);
    });

    test('every section survives the move', () {
      const sections = DiveDetailSectionConfig.defaultSections;
      final rendered = ids(sections);
      final moved = DiveDetailSectionConfig.moveRenderedSection(
        sections,
        rendered,
        3,
        0,
      );
      expect(moved.length, sections.length);
      expect(ids(moved).toSet(), rendered.toSet());
    });

    // Fold state and visibility travel with the section, not its slot.
    test('the moved section keeps its own flags', () {
      final sections = [
        const DiveDetailSectionConfig(id: a, visible: true),
        const DiveDetailSectionConfig(id: b, visible: true, expanded: true),
      ];
      final moved = DiveDetailSectionConfig.moveRenderedSection(
        sections,
        [a, b],
        1,
        0,
      );
      expect(ids(moved), [b, a]);
      expect(moved.first.expanded, isTrue);
    });

    test('a single rendered section cannot move', () {
      final moved = DiveDetailSectionConfig.moveRenderedSection(
        configs([a, b], invisible: [b]),
        [a],
        0,
        0,
      );
      expect(ids(moved), [a, b]);
    });
  });
}
