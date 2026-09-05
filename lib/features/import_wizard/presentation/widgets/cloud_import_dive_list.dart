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
    required this.titleOf,
    required this.subtitleOf,
    required this.onToggle,
  });

  final int itemCount;
  final Set<int> selectedIndices;
  final String Function(int index) titleOf;
  final String Function(int index) subtitleOf;
  final ValueChanged<int> onToggle;

  @override
  Widget build(BuildContext context) {
    return ListView.builder(
      itemCount: itemCount,
      itemBuilder: (context, index) {
        return CheckboxListTile(
          value: selectedIndices.contains(index),
          onChanged: (_) => onToggle(index),
          controlAffinity: ListTileControlAffinity.leading,
          title: Text(titleOf(index)),
          subtitle: Text(subtitleOf(index)),
        );
      },
    );
  }
}
