import 'package:flutter/material.dart';
import 'package:material_design_icons_flutter/material_design_icons_flutter.dart';
import 'package:submersion/core/constants/enums.dart';

/// Returns the icon representing a marine-life [SpeciesCategory].
///
/// Prefers the Material Design Icons marine set where a dedicated glyph exists
/// (fish, shark, dolphin, turtle, jellyfish) and falls back to botanical or
/// neutral Material icons for categories without a marine glyph. This is the
/// single source of truth for category icons across the dive log, dive sites,
/// marine life, and statistics features.
IconData iconForSpeciesCategory(SpeciesCategory category) {
  switch (category) {
    case SpeciesCategory.fish:
      return MdiIcons.fish;
    case SpeciesCategory.shark:
      return MdiIcons.shark;
    case SpeciesCategory.ray:
      // No dedicated ray glyph exists; rays are cartilaginous fish, so the
      // generic fish icon is the closest accurate representation.
      return MdiIcons.fish;
    case SpeciesCategory.mammal:
      return MdiIcons.dolphin;
    case SpeciesCategory.turtle:
      return MdiIcons.turtle;
    case SpeciesCategory.invertebrate:
      return MdiIcons.jellyfish;
    case SpeciesCategory.coral:
      return Icons.park;
    case SpeciesCategory.plant:
      return Icons.grass;
    case SpeciesCategory.other:
      return Icons.more_horiz;
  }
}
