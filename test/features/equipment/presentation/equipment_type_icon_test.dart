import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/core/constants/enums.dart';
import 'package:submersion/core/icons/mdi_icons.dart';
import 'package:submersion/core/icons/submersion_icons.dart';
import 'package:submersion/features/equipment/presentation/utils/equipment_type_icon.dart';

void main() {
  test('every equipment type resolves to an icon', () {
    for (final type in EquipmentType.values) {
      expect(equipmentTypeIcon(type), isA<IconData>(), reason: type.name);
    }
  });

  test('a DPV shows the scooter glyph everywhere', () {
    expect(equipmentTypeIcon(EquipmentType.dpv), SubmersionIcons.dpv);
  });

  test('only the catch-all type gets the generic glyph', () {
    // The list and detail pages used to fall through to a generic icon for
    // every type their switch had not caught up with (rebreather, smb, reel,
    // knife, hood, gloves, boots, and any new type). A shared exhaustive
    // helper means "generic" is now a deliberate choice for `other` alone.
    final generic = equipmentTypeIcon(EquipmentType.other);
    for (final type in EquipmentType.values) {
      if (type == EquipmentType.other) continue;
      expect(
        equipmentTypeIcon(type),
        isNot(generic),
        reason: '${type.name} should have its own glyph',
      );
    }
  });

  test('the drysuit layers are told apart from the suits (#1537)', () {
    // An undersuit reuses the suit silhouette, so the quilting is the only
    // thing keeping it from reading as a wetsuit in the equipment list.
    final layers = [EquipmentType.undersuit, EquipmentType.baselayer];
    final suits = [EquipmentType.wetsuit, EquipmentType.drysuit];
    for (final layer in layers) {
      for (final suit in suits) {
        expect(
          equipmentTypeIcon(layer),
          isNot(equipmentTypeIcon(suit)),
          reason: '${layer.name} vs ${suit.name}',
        );
      }
    }
    expect(
      equipmentTypeIcon(EquipmentType.undersuit),
      isNot(equipmentTypeIcon(EquipmentType.baselayer)),
    );
  });

  test('a tool no longer looks like the catch-all', () {
    // `other` was a wrench until Tool became a type of its own; two wrenches
    // in one list is the ambiguity #1189 complained about.
    expect(
      equipmentTypeIcon(EquipmentType.tool),
      isNot(equipmentTypeIcon(EquipmentType.other)),
    );
  });

  test('the two exposure suits no longer share a glyph', () {
    // They did until #1189, which reported the shared hanger as a defect: the
    // drysuit is drawn with its attached hood and boots.
    expect(
      equipmentTypeIcon(EquipmentType.wetsuit),
      isNot(equipmentTypeIcon(EquipmentType.drysuit)),
    );
  });

  group('the drawn glyphs', () {
    // Every type whose glyph had to be drawn because no icon font has the
    // shape. This pins the type-to-constant wiring and the family string
    // only; that the code point exists in the committed `.ttf` is a separate
    // question, answered by
    // test/core/icons/vendored_icon_font_coverage_test.dart, which reads the
    // font's cmap.
    const drawn = <EquipmentType, IconData>{
      EquipmentType.regulator: SubmersionIcons.regulator,
      EquipmentType.bcd: SubmersionIcons.bcd,
      EquipmentType.wetsuit: SubmersionIcons.wetsuit,
      EquipmentType.drysuit: SubmersionIcons.drysuit,
      EquipmentType.rebreather: SubmersionIcons.rebreather,
      EquipmentType.hood: SubmersionIcons.hood,
      EquipmentType.gloves: SubmersionIcons.gloves,
      EquipmentType.boots: SubmersionIcons.boots,
      EquipmentType.reel: SubmersionIcons.reel,
      EquipmentType.dpv: SubmersionIcons.dpv,
      EquipmentType.undersuit: SubmersionIcons.undersuit,
      EquipmentType.baselayer: SubmersionIcons.baselayer,
    };

    test('are wired to the equipment font', () {
      for (final entry in drawn.entries) {
        expect(
          equipmentTypeIcon(entry.key),
          entry.value,
          reason: entry.key.name,
        );
        expect(
          entry.value.fontFamily,
          SubmersionIcons.fontFamily,
          reason: entry.key.name,
        );
      }
    });

    test('have distinct code points', () {
      // A copy-paste in the constants file would otherwise alias two types to
      // one glyph, which the uniqueness test above cannot see because it
      // compares only against the generic glyph.
      final codePoints = drawn.values.map((icon) => icon.codePoint).toSet();
      expect(codePoints, hasLength(drawn.length));
    });
  });

  test(
    'the types on the bundled Material Design Icons font keep their glyph',
    () {
      // Five of these swapped from a Material metaphor (waves for fins, an
      // eyeball for a mask) to dive glyphs that were already in the bundled
      // webfont. `tank` was not remapped and is here as a regression guard: it
      // was the only type already pointing at the MDI font, so it is what
      // proves the family assertion below can fail. As above, the family
      // string is all that is asserted here; whether the vendored font
      // actually maps these code points is checked by
      // test/core/icons/vendored_icon_font_coverage_test.dart.
      const onMdiFont = <EquipmentType, IconData>{
        EquipmentType.fins: MdiIcons.divingFlippers,
        EquipmentType.mask: MdiIcons.divingScubaMask,
        EquipmentType.knife: MdiIcons.knifeMilitary,
        EquipmentType.weights: MdiIcons.weight,
        EquipmentType.smb: MdiIcons.divingScubaFlag,
        EquipmentType.tank: MdiIcons.divingScubaTank,
        // Added with the types themselves in #1518. These five code points
        // were transcribed by hand from the Material Design Icons release
        // notes, which is why the cmap test exists alongside this one.
        EquipmentType.snorkel: MdiIcons.divingSnorkel,
        EquipmentType.compass: MdiIcons.compass,
        EquipmentType.instrument: MdiIcons.gauge,
        EquipmentType.tool: MdiIcons.tools,
        EquipmentType.rashGuard: MdiIcons.tshirtCrew,
      };

      for (final entry in onMdiFont.entries) {
        expect(
          equipmentTypeIcon(entry.key),
          entry.value,
          reason: entry.key.name,
        );
        expect(
          entry.value.fontFamily,
          MdiIcons.fontFamily,
          reason: entry.key.name,
        );
      }
    },
  );
}
