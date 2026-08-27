import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:submersion/core/utils/unit_formatter.dart';
import 'package:submersion/features/dive_3d/domain/compare/comparison_profile.dart';
import 'package:submersion/features/dive_3d/domain/compare/divergence_builder.dart';
import 'package:submersion/features/settings/presentation/providers/settings_providers.dart';
import 'package:submersion/l10n/l10n_extension.dart';

/// Legend for the comparison scene: one row per profile (color swatch +
/// label). Tapping a row focuses that profile (drives the overlay gap
/// surface); the star makes it the reference. Each non-reference row shows
/// its largest divergence from the reference, in the diver's depth unit.
class CompareLegend extends ConsumerWidget {
  final List<ComparisonProfile> profiles;
  final int referenceIndex;
  final int? focusedIndex;
  final void Function(int index) onFocus;
  final void Function(int index) onSetReference;
  final List<DivergenceMark> maxGaps;

  const CompareLegend({
    super.key,
    required this.profiles,
    required this.referenceIndex,
    required this.onFocus,
    required this.onSetReference,
    this.focusedIndex,
    this.maxGaps = const [],
  });

  DivergenceMark? _markFor(String id) {
    for (final m in maxGaps) {
      if (m.profileId == id) return m;
    }
    return null;
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final units = UnitFormatter(ref.watch(settingsProvider));
    return DecoratedBox(
      decoration: BoxDecoration(
        color: theme.colorScheme.surface.withValues(alpha: 0.82),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 4),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            for (var i = 0; i < profiles.length; i++)
              _row(context, theme, units, i),
          ],
        ),
      ),
    );
  }

  Widget _row(
    BuildContext context,
    ThemeData theme,
    UnitFormatter units,
    int i,
  ) {
    final p = profiles[i];
    final isRef = i == referenceIndex;
    final isFocused = i == focusedIndex;
    final mark = _markFor(p.id);
    return InkWell(
      onTap: () => onFocus(i),
      borderRadius: BorderRadius.circular(6),
      child: Container(
        decoration: BoxDecoration(
          color: isFocused
              ? theme.colorScheme.primary.withValues(alpha: 0.14)
              : null,
          borderRadius: BorderRadius.circular(6),
        ),
        padding: const EdgeInsets.only(left: 6, right: 2, top: 2, bottom: 2),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 10,
              height: 10,
              decoration: BoxDecoration(color: p.color, shape: BoxShape.circle),
            ),
            const SizedBox(width: 6),
            Text(p.label, style: theme.textTheme.labelMedium),
            if (mark != null && !isRef) ...[
              const SizedBox(width: 6),
              Text(
                _deltaText(units, mark.gapMeters),
                style: theme.textTheme.labelSmall?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                ),
              ),
            ],
            const SizedBox(width: 2),
            IconButton(
              icon: Icon(isRef ? Icons.star : Icons.star_border, size: 15),
              tooltip: context.l10n.dive3d_compare_setReference,
              visualDensity: VisualDensity.compact,
              constraints: const BoxConstraints.tightFor(width: 28, height: 28),
              padding: EdgeInsets.zero,
              onPressed: () => onSetReference(i),
            ),
          ],
        ),
      ),
    );
  }

  String _deltaText(UnitFormatter units, double gapMeters) {
    final sign = gapMeters >= 0 ? '+' : '-';
    return '$sign${units.formatDepth(gapMeters.abs())}';
  }
}
