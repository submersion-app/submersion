import 'package:flutter/material.dart';

/// Scrollable, checkbox-per-row list of the dives fetched so far in a
/// cloud import wizard's fetch step.
///
/// Lets the diver deselect dives they don't want carried into the rest of
/// the wizard before advancing, rather than only deciding that later in the
/// shared Review step.
class CloudImportDiveList extends StatelessWidget {
  const CloudImportDiveList({
    super.key,
    required this.itemCount,
    required this.selectedIndices,
    required this.summaryOf,
    required this.onToggle,
  });

  final int itemCount;
  final Set<int> selectedIndices;

  /// Title and subtitle for one row, computed together so a caller that
  /// derives both from a single formatting pass runs it once per row rather
  /// than once per line of text.
  final ({String title, String subtitle}) Function(int index) summaryOf;
  final ValueChanged<int> onToggle;

  @override
  Widget build(BuildContext context) {
    return ListView.builder(
      itemCount: itemCount,
      itemBuilder: (context, index) {
        final summary = summaryOf(index);
        return CheckboxListTile(
          value: selectedIndices.contains(index),
          onChanged: (_) => onToggle(index),
          controlAffinity: ListTileControlAffinity.leading,
          title: Text(summary.title),
          subtitle: Text(summary.subtitle),
        );
      },
    );
  }
}
