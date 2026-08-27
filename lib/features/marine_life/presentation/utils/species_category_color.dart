import 'package:flutter/material.dart';

import 'package:submersion/core/constants/enums.dart';

/// Returns the avatar color for a marine-life [SpeciesCategory].
///
/// Category hues are semantic (fish = blue, turtle = green, ...) rather than
/// theme-derived so species stay recognizable across the app's theme
/// variants; only the shade adapts to [brightness] so avatars keep contrast
/// in dark mode. Single source of truth shared by the dive log sighting list
/// and the species pickers.
Color colorForSpeciesCategory(
  SpeciesCategory? category,
  Brightness brightness,
) {
  final dark = brightness == Brightness.dark;
  switch (category) {
    case SpeciesCategory.fish:
      return dark ? Colors.blue.shade400 : Colors.blue.shade600;
    case SpeciesCategory.shark:
      return dark ? Colors.grey.shade500 : Colors.grey.shade700;
    case SpeciesCategory.ray:
      return dark ? Colors.indigo.shade400 : Colors.indigo.shade600;
    case SpeciesCategory.mammal:
      return dark ? Colors.brown.shade400 : Colors.brown.shade600;
    case SpeciesCategory.turtle:
      return dark ? Colors.green.shade500 : Colors.green.shade700;
    case SpeciesCategory.invertebrate:
      return dark ? Colors.purple.shade400 : Colors.purple.shade600;
    case SpeciesCategory.coral:
      return dark ? Colors.pink.shade400 : Colors.pink.shade600;
    case SpeciesCategory.plant:
      return dark ? Colors.green.shade400 : Colors.green.shade600;
    case SpeciesCategory.other:
    case null:
      return dark ? Colors.grey.shade500 : Colors.grey.shade600;
  }
}
