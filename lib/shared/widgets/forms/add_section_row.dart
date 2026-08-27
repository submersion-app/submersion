import 'package:flutter/material.dart';

import 'package:submersion/l10n/l10n_extension.dart';

class AddSectionEntry {
  const AddSectionEntry({required this.label, required this.onTap});

  final String label;
  final VoidCallback onTap;
}

/// Trailing muted row listing rare sections not yet in use:
/// "+ Add: Course / Custom fields". Tapping a label expands that section.
class AddSectionRow extends StatelessWidget {
  const AddSectionRow({super.key, required this.entries});

  final List<AddSectionEntry> entries;

  @override
  Widget build(BuildContext context) {
    if (entries.isEmpty) return const SizedBox.shrink();
    final theme = Theme.of(context);
    final muted = theme.textTheme.bodyMedium!.copyWith(
      color: theme.colorScheme.onSurfaceVariant,
    );
    final link = theme.textTheme.bodyMedium!.copyWith(
      color: theme.colorScheme.primary,
      fontWeight: FontWeight.w600,
    );
    final children = <Widget>[
      Text('+ ${context.l10n.forms_addSection_prefix} ', style: muted),
    ];
    for (var i = 0; i < entries.length; i++) {
      children.add(
        InkWell(
          onTap: entries[i].onTap,
          borderRadius: BorderRadius.circular(6),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 2, vertical: 4),
            child: Text(entries[i].label, style: link),
          ),
        ),
      );
      if (i < entries.length - 1) {
        children.add(Text(' - ', style: muted));
      }
    }
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Wrap(
        alignment: WrapAlignment.center,
        crossAxisAlignment: WrapCrossAlignment.center,
        children: children,
      ),
    );
  }
}
