import 'package:flutter/material.dart';

import 'package:submersion/core/providers/provider.dart';
import 'package:submersion/core/utils/number_input.dart';
import 'package:submersion/core/utils/unit_formatter.dart';
import 'package:submersion/features/insights/domain/focus/focus_metric.dart';
import 'package:submersion/features/insights/domain/focus/focus_selection.dart';
import 'package:submersion/features/insights/presentation/formatters/focus_labels.dart';
import 'package:submersion/features/insights/presentation/formatters/focus_metric_units.dart';
import 'package:submersion/features/insights/presentation/providers/insights_focus_providers.dart';
import 'package:submersion/features/insights/presentation/widgets/focus/focus_count_dialog.dart';
import 'package:submersion/features/settings/presentation/providers/settings_providers.dart';
import 'package:submersion/l10n/l10n_extension.dart';
import 'package:submersion/shared/widgets/forms/number_input_validation.dart';

/// Slots the localised sentence templates carry; each becomes a control.
const List<String> focusSentenceMarkers = [
  '<count>',
  '<mode>',
  '<metric>',
  '<value>',
];

/// The preset group sizes in the count menu; anything else is Custom.
const List<int> focusCountChoices = [5, 10, 20, 50];

/// Stands for "Custom..." in the count menu: never a valid count, since
/// [FocusSelection.minCount] is 1.
const int _customCount = 0;

final RegExp _marker = RegExp('<(count|mode|metric|value)>');

/// Splits a rendered template into trimmed text fragments and markers, in
/// order, dropping empty fragments. `"Show the <count> dives"` gives
/// `["Show the", "<count>", "dives"]`.
List<String> splitFocusSentence(String template) {
  final out = <String>[];
  var last = 0;
  for (final m in _marker.allMatches(template)) {
    final text = template.substring(last, m.start).trim();
    if (text.isNotEmpty) out.add(text);
    out.add(m.group(0)!);
    last = m.end;
  }
  final tail = template.substring(last).trim();
  if (tail.isNotEmpty) out.add(tail);
  return out;
}

/// Dive focus's group picker, read as a sentence: "Show the [10] dives with
/// the [best] [RMV]", or "Show the dives with [RMV] [above] [15 L/min]".
class FocusSentence extends ConsumerStatefulWidget {
  const FocusSentence({super.key});

  @override
  ConsumerState<FocusSentence> createState() => _FocusSentenceState();
}

class _FocusSentenceState extends ConsumerState<FocusSentence> {
  late final TextEditingController _threshold;
  String? _thresholdError;

  @override
  void initState() {
    super.initState();
    final selection = ref.read(focusSelectionProvider);
    _threshold = TextEditingController(
      text: _thresholdText(
        selection.threshold,
        _units(selection.metric, ref.read(settingsProvider)),
      ),
    );
  }

  @override
  void dispose() {
    _threshold.dispose();
    super.dispose();
  }

  static FocusMetricUnits _units(FocusMetric metric, AppSettings settings) =>
      FocusMetricUnits(metric, UnitFormatter(settings));

  static String _thresholdText(double? threshold, FocusMetricUnits units) =>
      threshold == null
      ? ''
      : formatRoundedForInput(units.toDisplay(threshold), 2);

  void _set(FocusSelection next) =>
      ref.read(focusSelectionProvider.notifier).state = next;

  /// Re-renders the stored threshold when this metric's unit changes, so
  /// the digits match the new suffix (#3017). Other settings changes leave a
  /// half-typed entry alone.
  void _onSettingsChanged(AppSettings? previous, AppSettings next) {
    if (previous == null) return;
    final selection = ref.read(focusSelectionProvider);
    final l10n = context.l10n;
    final before = _units(selection.metric, previous);
    final after = _units(selection.metric, next);
    if (before.symbol(l10n) == after.symbol(l10n)) return;
    _threshold.text = _thresholdText(selection.threshold, after);
    setState(() => _thresholdError = null);
  }

  /// A threshold mode with no value takes the metric's mean once it is
  /// known, so the page never sits on an empty box over an empty page.
  void _applyDefault(AsyncValue<double?> value) {
    // While the provider reloads for a new metric, `value` still carries
    // the previous metric's mean; applying it would file RMV litres as
    // metres. Wait for the new mean to land.
    if (value.isLoading) return;
    final mean = value.value;
    final selection = ref.read(focusSelectionProvider);
    if (mean == null ||
        selection.mode.isRanked ||
        selection.threshold != null) {
      return;
    }
    _threshold.text = _thresholdText(
      mean,
      _units(selection.metric, ref.read(settingsProvider)),
    );
    setState(() => _thresholdError = null);
    _set(selection.copyWith(threshold: mean));
  }

  void _onMetric(FocusMetric? metric, FocusSelection selection) {
    if (metric == null || metric == selection.metric) return;
    _threshold.clear();
    setState(() => _thresholdError = null);
    // A threshold means nothing in another metric's units; the default
    // listener refills it from the new metric's mean.
    _set(selection.copyWith(metric: metric, clearThreshold: true));
  }

  void _onMode(FocusMode? mode, FocusSelection selection) {
    if (mode == null || mode == selection.mode) return;
    _set(selection.copyWith(mode: mode));
    if (!mode.isRanked && selection.threshold == null) {
      // Apply an already-loaded default at once rather than waiting for the
      // listener, which only fires on a change.
      _applyDefault(ref.read(focusThresholdDefaultProvider));
    }
  }

  Future<void> _onCount(int? choice, FocusSelection selection) async {
    if (choice == null) return;
    if (choice != _customCount) {
      _set(selection.copyWith(count: choice));
      return;
    }
    final n = await showFocusCountDialog(context, initial: selection.count);
    // The page can be popped under the dialog; ref is gone with the State.
    if (!mounted || n == null) return;
    _set(selection.copyWith(count: n));
  }

  void _onThreshold(
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
      _set(selection.copyWith(clearThreshold: true));
    } else if (error == null && value != null) {
      _set(selection.copyWith(threshold: units.toStorage(value)));
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    ref.listen(settingsProvider, _onSettingsChanged);
    ref.listen(focusThresholdDefaultProvider, (_, next) => _applyDefault(next));
    final selection = ref.watch(focusSelectionProvider);
    final units = _units(selection.metric, ref.watch(settingsProvider));
    final style = Theme.of(context).textTheme.titleMedium;

    final template = selection.mode.isRanked
        ? l10n.insights_focus_sentence_ranked('<count>', '<mode>', '<metric>')
        : l10n.insights_focus_sentence_threshold(
            '<metric>',
            '<mode>',
            '<value>',
          );

    Widget slot(String marker) => switch (marker) {
      '<count>' => _CountWord(
        selection: selection,
        onChanged: (c) => _onCount(c, selection),
      ),
      '<mode>' => _ModeWord(
        selection: selection,
        onChanged: (m) => _onMode(m, selection),
      ),
      '<metric>' => _MetricWord(
        selection: selection,
        onChanged: (m) => _onMetric(m, selection),
      ),
      _ => SizedBox(
        width: 160,
        child: TextField(
          key: const ValueKey('focus-threshold-field'),
          controller: _threshold,
          keyboardType: const TextInputType.numberWithOptions(
            decimal: true,
            signed: true,
          ),
          decoration: InputDecoration(
            suffixText: units.symbol(l10n),
            errorText: _thresholdError,
            errorMaxLines: 2,
            isDense: true,
          ),
          onChanged: (text) => _onThreshold(text, selection, units),
        ),
      ),
    };

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Wrap(
          spacing: 8,
          runSpacing: 8,
          crossAxisAlignment: WrapCrossAlignment.center,
          children: [
            for (final part in splitFocusSentence(template))
              if (focusSentenceMarkers.contains(part))
                slot(part)
              else
                Text(part, style: style),
          ],
        ),
      ),
    );
  }
}

/// A word of the sentence that opens a menu. The underline is dropped so
/// the control reads as part of the sentence, with the arrow as the cue.
class _Word<T> extends StatelessWidget {
  const _Word({
    required this.menuKey,
    required this.value,
    required this.items,
    required this.onChanged,
  });

  final Key menuKey;
  final T value;
  final List<DropdownMenuItem<T>> items;
  final ValueChanged<T?> onChanged;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return DropdownButton<T>(
      key: menuKey,
      value: value,
      items: items,
      onChanged: onChanged,
      underline: const SizedBox.shrink(),
      isDense: true,
      style: theme.textTheme.titleMedium?.copyWith(
        color: theme.colorScheme.primary,
        fontWeight: FontWeight.w600,
      ),
    );
  }
}

class _CountWord extends StatelessWidget {
  const _CountWord({required this.selection, required this.onChanged});

  final FocusSelection selection;
  final ValueChanged<int?> onChanged;

  @override
  Widget build(BuildContext context) {
    final custom = !focusCountChoices.contains(selection.count);
    return _Word<int>(
      menuKey: const ValueKey('focus-count'),
      value: selection.count,
      items: [
        for (final n in focusCountChoices)
          DropdownMenuItem(value: n, child: Text('$n')),
        if (custom)
          DropdownMenuItem(
            value: selection.count,
            child: Text('${selection.count}'),
          ),
        DropdownMenuItem(
          value: _customCount,
          child: Text(context.l10n.insights_focus_count_custom),
        ),
      ],
      onChanged: onChanged,
    );
  }
}

class _ModeWord extends StatelessWidget {
  const _ModeWord({required this.selection, required this.onChanged});

  final FocusSelection selection;
  final ValueChanged<FocusMode?> onChanged;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    return _Word<FocusMode>(
      menuKey: const ValueKey('focus-mode'),
      value: selection.mode,
      items: [
        for (final mode in FocusMode.values)
          DropdownMenuItem(
            value: mode,
            child: Text(focusModeLabel(mode, selection.metric, l10n)),
          ),
      ],
      onChanged: onChanged,
    );
  }
}

class _MetricWord extends StatelessWidget {
  const _MetricWord({required this.selection, required this.onChanged});

  final FocusSelection selection;
  final ValueChanged<FocusMetric?> onChanged;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final theme = Theme.of(context);
    final heading = theme.textTheme.labelSmall?.copyWith(
      color: theme.colorScheme.onSurfaceVariant,
    );
    return _Word<FocusMetric?>(
      menuKey: const ValueKey('focus-metric'),
      value: selection.metric,
      items: [
        for (final group in FocusMetricGroup.values) ...[
          // A disabled, valueless item is the group's heading.
          DropdownMenuItem<FocusMetric?>(
            enabled: false,
            child: Text(focusMetricGroupLabel(group, l10n), style: heading),
          ),
          for (final m in FocusMetric.values)
            if (m.group == group)
              DropdownMenuItem<FocusMetric?>(
                value: m,
                child: Text(focusMetricLabel(m, l10n)),
              ),
        ],
      ],
      onChanged: onChanged,
    );
  }
}
