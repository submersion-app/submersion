import 'package:flutter/material.dart';

import 'package:submersion/features/dive_log/domain/entities/bulk_edit_request.dart';
import 'package:submersion/l10n/l10n_extension.dart';

/// A small segmented control for a bulk collection edit. Selecting a chip sets
/// the mode; tapping the selected chip again turns the edit off ([mode] null).
/// Owned collections pass `allowed: [add, replace]`; reference collections pass
/// all three.
class BulkCollectionModeSelector extends StatelessWidget {
  const BulkCollectionModeSelector({
    super.key,
    required this.mode,
    required this.allowed,
    required this.onChanged,
  });

  final BulkCollectionMode? mode;
  final List<BulkCollectionMode> allowed;
  final ValueChanged<BulkCollectionMode?> onChanged;

  @override
  Widget build(BuildContext context) {
    return Wrap(
      spacing: 6,
      children: [
        for (final m in allowed)
          ChoiceChip(
            label: Text(_label(context, m)),
            selected: mode == m,
            onSelected: (selected) => onChanged(selected ? m : null),
          ),
      ],
    );
  }

  String _label(BuildContext context, BulkCollectionMode m) => switch (m) {
    BulkCollectionMode.add => context.l10n.diveLog_bulkEdit_modeAdd,
    BulkCollectionMode.remove => context.l10n.diveLog_bulkEdit_modeRemove,
    BulkCollectionMode.replace => context.l10n.diveLog_bulkEdit_modeReplace,
  };
}
