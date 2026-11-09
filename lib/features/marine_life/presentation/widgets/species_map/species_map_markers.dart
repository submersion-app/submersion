import 'dart:math' as math;

import 'package:flutter/material.dart';

/// Pin size on the places view: 32 at one species, growing by 8 for each
/// doubling, capped at 52 so a rich site never swallows its neighbours.
double siteSpeciesMarkerSize(int speciesCount) {
  final count = math.max(1, speciesCount);
  return (32 + 8 * math.log(count) / math.ln2).clamp(32, 52).toDouble();
}

/// A site on the places view, labelled with the species logged there.
class SiteSpeciesMarker extends StatelessWidget {
  final int speciesCount;
  final bool selected;

  const SiteSpeciesMarker({
    super.key,
    required this.speciesCount,
    required this.selected,
  });

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return _FilledCircle(
      size: siteSpeciesMarkerSize(speciesCount),
      fill: scheme.primary,
      foreground: scheme.onPrimary,
      selected: selected,
      label: '$speciesCount',
    );
  }
}

/// A site where the diver logged the picked species, labelled with the
/// summed sighting count there.
class LoggedSpeciesMarker extends StatelessWidget {
  final int sightingCount;
  final bool selected;

  const LoggedSpeciesMarker({
    super.key,
    required this.sightingCount,
    required this.selected,
  });

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return _FilledCircle(
      size: 34,
      fill: scheme.primary,
      foreground: scheme.onPrimary,
      selected: selected,
      label: '$sightingCount',
    );
  }
}

/// A site whose expected list names the picked species, not yet logged
/// there: hollow, so it never reads as a sighting.
class ExpectedSpeciesMarker extends StatelessWidget {
  final bool selected;

  const ExpectedSpeciesMarker({super.key, required this.selected});

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final size = selected ? 26.0 : 22.0;
    return Center(
      child: Container(
        width: size,
        height: size,
        decoration: BoxDecoration(
          color: scheme.surface,
          shape: BoxShape.circle,
          border: Border.all(color: scheme.primary, width: 2),
          boxShadow: _shadow,
        ),
      ),
    );
  }
}

const _shadow = [
  BoxShadow(color: Color(0x55000000), blurRadius: 3, offset: Offset(0, 1)),
];

class _FilledCircle extends StatelessWidget {
  final double size;
  final Color fill;
  final Color foreground;
  final bool selected;
  final String label;

  const _FilledCircle({
    required this.size,
    required this.fill,
    required this.foreground,
    required this.selected,
    required this.label,
  });

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final diameter = selected ? size + 6 : size;
    return Center(
      child: Container(
        width: diameter,
        height: diameter,
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: fill,
          shape: BoxShape.circle,
          border: Border.all(
            color: selected ? scheme.onSurface : scheme.surface,
            width: selected ? 3 : 2,
          ),
          boxShadow: _shadow,
        ),
        child: FittedBox(
          child: Padding(
            padding: const EdgeInsets.all(4),
            child: Text(
              label,
              style: TextStyle(
                color: foreground,
                fontWeight: FontWeight.bold,
                fontSize: 13,
              ),
            ),
          ),
        ),
      ),
    );
  }
}
