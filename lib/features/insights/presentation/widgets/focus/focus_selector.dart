import 'package:flutter/material.dart';

import 'package:submersion/core/providers/provider.dart';
import 'package:submersion/core/utils/number_input.dart';
import 'package:submersion/shared/widgets/forms/number_input_validation.dart';
import 'package:submersion/core/utils/unit_formatter.dart';
import 'package:submersion/features/insights/domain/focus/focus_metric.dart';
import 'package:submersion/features/insights/domain/focus/focus_selection.dart';
import 'package:submersion/features/insights/presentation/formatters/focus_labels.dart';
import 'package:submersion/features/insights/presentation/formatters/focus_metric_units.dart';
import 'package:submersion/features/insights/presentation/providers/insights_focus_providers.dart';
import 'package:submersion/features/settings/presentation/providers/settings_providers.dart';
import 'package:submersion/l10n/l10n_extension.dart';

/// Metric, mode and value for Dive focus, on one wrapping row.
class FocusSelector extends ConsumerStatefulWidget {
  const FocusSelector({super.key});

  @override
  ConsumerState<FocusSelector> createState() => _FocusSelectorState();
}

class _FocusSelectorState extends ConsumerState<FocusSelector> {
  static const _countChips = [5, 10, 20];

  late final TextEditingController _count;
  late final TextEditingController _threshold;
  String? _countError;
  String? _thresholdError;

  @override
  void initState() {
    super.initState();
    final selection = ref.read(focusSelectionProvider);
    _count = TextEditingController(text: '${selection.count}');
    final threshold = selection.threshold;
    final units = FocusMetricUnits(
      selection.metric,
      UnitFormatter(ref.read(settingsProvider)),
    );
    _threshold = TextEditingController(
      text: threshold == null
          ? ''
          : formatRoundedForInput(units.toDisplay(threshold), 2),
    );
  }

  @override
  void dispose() {
    _count.dispose();
    _threshold.dispose();
    super.dispose();
  }

  void _set(FocusSelection next) =>
      ref.read(focusSelectionProvider.notifier).state = next;

  void _onCountChanged(String text, FocusSelection selection) {
    final read = readNumber(text, integer: true, allowNegative: false);
    final n = read is NumberValue ? read.value.toInt() : null;
    final valid =
        n != null &&
        n >= FocusSelection.minCount &&
        n <= FocusSelection.maxCount;
    setState(
      () =>
          _countError = valid ? null : context.l10n.insights_focus_count_error,
    );
    if (valid) _set(selection.copyWith(count: n));
  }

  void _onThresholdChanged(
    String text,
    FocusSelection selection,
    FocusMetricUnits units,
  ) {
    // Read with negatives allowed, so a sub-zero entry can be told apart
    // from unreadable text and named as the problem it is.
    final read = readNumber(text);
    final value = read is NumberValue ? read.value : null;
    String? error;
    if (read is NumberInvalid) {
      error = context.l10n.insights_focus_threshold_error;
    } else if (value != null && value < 0 && !units.allowsNegative) {
      error = context.l10n.insights_focus_threshold_negativeError;
    }
    setState(() => _thresholdError = error);
    if (read is NumberBlank) {
      // An emptied field means no threshold, so the page asks for one again
      // rather than keep showing the group for the value that was deleted.
      _set(selection.copyWith(clearThreshold: true));
    } else if (error == null && value != null) {
      _set(selection.copyWith(threshold: units.toStorage(value)));
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final selection = ref.watch(focusSelectionProvider);
    final units = FocusMetricUnits(
      selection.metric,
      UnitFormatter(ref.watch(settingsProvider)),
    );

    return Wrap(
      spacing: 12,
      runSpacing: 12,
      crossAxisAlignment: WrapCrossAlignment.center,
      children: [
        DropdownButton<FocusMetric>(
          key: const ValueKey('focus-metric'),
          value: selection.metric,
          onChanged: (metric) {
            if (metric == null || metric == selection.metric) return;
            _threshold.clear();
            setState(() => _thresholdError = null);
            // A threshold means nothing in another metric's units.
            _set(selection.copyWith(metric: metric, clearThreshold: true));
          },
          items: [
            for (final m in FocusMetric.values)
              DropdownMenuItem(
                value: m,
                child: Text(focusMetricLabel(m, l10n)),
              ),
          ],
        ),
        SegmentedButton<FocusMode>(
          key: const ValueKey('focus-mode'),
          showSelectedIcon: false,
          segments: [
            for (final mode in FocusMode.values)
              ButtonSegment(
                value: mode,
                // One line, shrunk to fit: a long word such as German
                // "Schlechteste" would otherwise break mid-word on a phone.
                label: FittedBox(
                  fit: BoxFit.scaleDown,
                  child: Text(
                    focusModeLabel(mode, selection.metric, l10n),
                    maxLines: 1,
                    softWrap: false,
                  ),
                ),
              ),
          ],
          selected: {selection.mode},
          onSelectionChanged: (modes) =>
              _set(selection.copyWith(mode: modes.first)),
        ),
        if (selection.mode.isRanked) ...[
          for (final n in _countChips)
            ChoiceChip(
              key: ValueKey('focus-count-$n'),
              label: Text('$n'),
              selected: selection.count == n,
              onSelected: (_) {
                _count.text = '$n';
                setState(() => _countError = null);
                _set(selection.copyWith(count: n));
              },
            ),
          SizedBox(
            // Room for the label in long locales ("Tauchgänge", "Inmersiones").
            width: 128,
            child: TextField(
              key: const ValueKey('focus-count-field'),
              controller: _count,
              keyboardType: TextInputType.number,
              decoration: InputDecoration(
                labelText: l10n.insights_focus_count_label,
                errorText: _countError,
                errorMaxLines: 3,
                isDense: true,
              ),
              onChanged: (text) => _onCountChanged(text, selection),
            ),
          ),
        ] else
          SizedBox(
            width: 180,
            child: TextField(
              key: const ValueKey('focus-threshold-field'),
              controller: _threshold,
              keyboardType: const TextInputType.numberWithOptions(
                decimal: true,
                signed: true,
              ),
              decoration: InputDecoration(
                labelText: l10n.insights_focus_threshold_label,
                suffixText: units.symbol(l10n),
                errorText: _thresholdError,
                errorMaxLines: 2,
                isDense: true,
              ),
              onChanged: (text) => _onThresholdChanged(text, selection, units),
            ),
          ),
      ],
    );
  }
}
