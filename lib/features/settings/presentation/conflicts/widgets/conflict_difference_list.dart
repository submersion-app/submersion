import 'package:collection/collection.dart';
import 'package:flutter/material.dart';
import 'package:submersion/features/settings/presentation/conflicts/conflict_comparison.dart';
import 'package:submersion/features/settings/presentation/conflicts/conflict_device_labels.dart';
import 'package:submersion/features/settings/presentation/conflicts/conflict_field.dart';
import 'package:submersion/features/settings/presentation/conflicts/widgets/conflict_text_diff.dart';
import 'package:submersion/features/settings/presentation/conflicts/word_diff.dart';
import 'package:submersion/l10n/l10n_extension.dart';

/// Below this width the three-column table cannot fit two values side by
/// side, so each field becomes a stacked block.
const kConflictTableMinWidth = 480.0;

/// Every field the two versions disagree on: a field, local, remote table
/// when there is room, one block per field when there is not.
class ConflictDifferenceList extends StatefulWidget {
  const ConflictDifferenceList({
    super.key,
    required this.differences,
    required this.devices,
    @visibleForTesting this.diff = diffWords,
  });

  final List<FieldDifference> differences;
  final ConflictDeviceLabels devices;

  /// Computes a long-text field's word diff.
  final WordDiff? Function(String local, String remote) diff;

  @override
  State<ConflictDifferenceList> createState() => _ConflictDifferenceListState();
}

class _ConflictDifferenceListState extends State<ConflictDifferenceList> {
  // The dialog rebuilds on every chip tap and provider tick, each time with
  // new FieldDifference objects for the same conflict. The word diff is an
  // LCS over the two texts, so it is kept until the texts themselves change.
  late Map<String, (String, String)> _texts;
  late Map<String, WordDiff> _diffs;

  @override
  void initState() {
    super.initState();
    _texts = _textsOf(widget.differences);
    _diffs = _compute(_texts);
  }

  @override
  void didUpdateWidget(ConflictDifferenceList oldWidget) {
    super.didUpdateWidget(oldWidget);
    final texts = _textsOf(widget.differences);
    if (widget.diff != oldWidget.diff || !_textEquality.equals(texts, _texts)) {
      _texts = texts;
      _diffs = _compute(texts);
    }
  }

  Map<String, WordDiff> _compute(Map<String, (String, String)> texts) =>
      Map.unmodifiable({
        for (final MapEntry(:key, value: (local, remote)) in texts.entries)
          key: ?widget.diff(local, remote),
      });

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) => Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (constraints.maxWidth >= kConflictTableMinWidth)
            _table(context, _diffs)
          else
            for (final d in widget.differences)
              _block(context, d, _diffs[d.key]),
          if (_diffs.isNotEmpty)
            Padding(
              padding: const EdgeInsets.only(top: 8),
              child: Text(
                context.l10n.settings_conflict_textDiffHint,
                style: Theme.of(
                  context,
                ).textTheme.bodySmall?.copyWith(fontStyle: FontStyle.italic),
              ),
            ),
        ],
      ),
    );
  }

  Widget _table(BuildContext context, Map<String, WordDiff> diffs) {
    final theme = Theme.of(context);
    final header = theme.textTheme.labelMedium?.copyWith(
      fontWeight: FontWeight.bold,
    );
    final label = theme.textTheme.bodySmall?.copyWith(
      fontWeight: FontWeight.bold,
    );
    Widget cell(Widget child) =>
        Padding(padding: const EdgeInsets.all(6), child: child);

    return Table(
      columnWidths: const {
        0: IntrinsicColumnWidth(flex: 1),
        1: FlexColumnWidth(2),
        2: FlexColumnWidth(2),
      },
      border: TableBorder(
        horizontalInside: BorderSide(color: theme.colorScheme.outlineVariant),
      ),
      children: [
        TableRow(
          children: [
            cell(
              Text(context.l10n.settings_conflict_fieldHeader, style: header),
            ),
            cell(Text(widget.devices.local, style: header)),
            cell(Text(widget.devices.remote, style: header)),
          ],
        ),
        for (final d in widget.differences)
          TableRow(
            children: [
              cell(Text(d.label, style: label)),
              cell(_value(context, d, diffs[d.key], local: true)),
              cell(_value(context, d, diffs[d.key], local: false)),
            ],
          ),
      ],
    );
  }

  Widget _block(BuildContext context, FieldDifference d, WordDiff? diff) {
    final theme = Theme.of(context);
    Widget line(String device, Widget value) => Padding(
      padding: const EdgeInsets.only(top: 2),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Loose, so a short name keeps its width and a long one wraps
          // instead of pushing the value off the screen.
          Flexible(
            flex: 2,
            child: Text(
              '$device: ',
              style: theme.textTheme.bodySmall?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
          ),
          Expanded(flex: 3, child: value),
        ],
      ),
    );

    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            d.label,
            style: theme.textTheme.bodySmall?.copyWith(
              fontWeight: FontWeight.bold,
            ),
          ),
          line(widget.devices.local, _value(context, d, diff, local: true)),
          line(widget.devices.remote, _value(context, d, diff, local: false)),
        ],
      ),
    );
  }

  Widget _value(
    BuildContext context,
    FieldDifference d,
    WordDiff? diff, {
    required bool local,
  }) {
    final style = Theme.of(context).textTheme.bodySmall;
    if (diff == null) {
      final text = Text(local ? d.localDisplay : d.remoteDisplay, style: style);
      // The stored values differ but read the same: they round to the same
      // text (30.04 m and 30.0 m), or differ only in spacing ('Blue Hole '
      // against 'Blue Hole'). Say why the row is listed, once, under the
      // local side.
      final String? note;
      if (d.localDisplay == d.remoteDisplay) {
        note = context.l10n.settings_conflict_finerThanShown;
      } else if (_collapsed(d.localDisplay) == _collapsed(d.remoteDisplay)) {
        note = context.l10n.settings_conflict_whitespaceOnly;
      } else {
        note = null;
      }
      if (!local || note == null) return text;
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          text,
          Text(note, style: style?.copyWith(fontStyle: FontStyle.italic)),
        ],
      );
    }
    final scheme = Theme.of(context).colorScheme;
    final text = ConflictTextDiff(
      spans: local ? diff.local : diff.remote,
      highlight: local ? scheme.primaryContainer : scheme.tertiaryContainer,
      onHighlight: local
          ? scheme.onPrimaryContainer
          : scheme.onTertiaryContainer,
    );
    if (diff.hasUniqueWords || !local) return text;
    // The texts hold the same words, so nothing is highlighted; say why the
    // field is listed at all. Shown once, under the local side.
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        text,
        Text(
          context.l10n.settings_conflict_whitespaceOnly,
          style: style?.copyWith(fontStyle: FontStyle.italic),
        ),
      ],
    );
  }
}

String _collapsed(String text) => text.trim().replaceAll(RegExp(r'\s+'), ' ');

/// The two texts of each long-text field, by key.
Map<String, (String, String)> _textsOf(List<FieldDifference> differences) => {
  for (final d in differences)
    if (_isText(d)) d.key: (d.localValue! as String, d.remoteValue! as String),
};

const _textEquality = MapEquality<String, (String, String)>();

bool _isText(FieldDifference d) =>
    d.kind == FieldKind.longText &&
    d.localValue is String &&
    d.remoteValue is String;
