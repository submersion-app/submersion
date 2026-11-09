import 'package:flutter/material.dart';

import 'package:submersion/features/marine_life/domain/entities/sighting_abundance.dart';
import 'package:submersion/features/marine_life/presentation/sighting_abundance_display.dart';
import 'package:submersion/l10n/l10n_extension.dart';

/// The "How many" control for a sighting (issue #4337): one row of choice
/// chips (Seen, the four REEF groups, Exact), a line giving the REEF ranges,
/// and, while Exact is picked, the +/- stepper for the number.
///
/// The parent owns [value] and rebuilds the picker with whatever
/// [onChanged] reports. Seen and the groups are always reported with count
/// 1. The last exact count is remembered, so switching from Exact 7 to Few
/// and back to Exact shows 7 again.
class SightingAbundancePicker extends StatefulWidget {
  final SightingAmount value;
  final ValueChanged<SightingAmount> onChanged;

  const SightingAbundancePicker({
    super.key,
    required this.value,
    required this.onChanged,
  });

  @override
  State<SightingAbundancePicker> createState() =>
      _SightingAbundancePickerState();
}

class _SightingAbundancePickerState extends State<SightingAbundancePicker> {
  /// Set in initState, not by a `late` initializer: that would run on first
  /// read, after the parent had already switched the value to a group.
  late int _lastExactCount;

  @override
  void initState() {
    super.initState();
    _lastExactCount = _exactCountOf(widget.value);
  }

  static int _exactCountOf(SightingAmount value) =>
      value.abundance == SightingAbundance.exact && value.count > 1
      ? value.count
      : 1;

  @override
  void didUpdateWidget(SightingAbundancePicker oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.value.abundance == SightingAbundance.exact) {
      _lastExactCount = _exactCountOf(widget.value);
    }
  }

  void _pick(SightingAbundance abundance) {
    widget.onChanged((
      abundance: abundance,
      count: abundance == SightingAbundance.exact ? _lastExactCount : 1,
    ));
  }

  void _setCount(int count) {
    _lastExactCount = count;
    widget.onChanged((abundance: SightingAbundance.exact, count: count));
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final theme = Theme.of(context);
    final value = widget.value;
    final isExact = value.abundance == SightingAbundance.exact;
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(
          l10n.marineLife_abundance_label,
          style: theme.textTheme.labelLarge,
        ),
        const SizedBox(height: 8),
        Wrap(
          spacing: 6,
          runSpacing: 6,
          children: [
            for (final abundance in SightingAbundance.values)
              ChoiceChip(
                label: Text(sightingAbundanceName(l10n, abundance)),
                selected: value.abundance == abundance,
                onSelected: (_) => _pick(abundance),
              ),
          ],
        ),
        const SizedBox(height: 4),
        Text(
          l10n.marineLife_abundance_ranges,
          style: theme.textTheme.bodySmall?.copyWith(
            color: theme.colorScheme.onSurfaceVariant,
          ),
        ),
        if (isExact) ...[
          const SizedBox(height: 12),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              IconButton(
                icon: const Icon(Icons.remove_circle_outline),
                tooltip: l10n.diveLog_sighting_decreaseCount,
                onPressed: value.count > 1
                    ? () => _setCount(value.count - 1)
                    : null,
              ),
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 8,
                ),
                decoration: BoxDecoration(
                  border: Border.all(color: theme.colorScheme.outline),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  '${value.count}',
                  style: theme.textTheme.titleLarge,
                ),
              ),
              IconButton(
                icon: const Icon(Icons.add_circle_outline),
                tooltip: l10n.diveLog_sighting_increaseCount,
                onPressed: () => _setCount(value.count + 1),
              ),
            ],
          ),
        ],
      ],
    );
  }
}
