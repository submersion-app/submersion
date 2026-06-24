import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:submersion/features/dive_log/domain/entities/dive.dart';
import 'package:submersion/features/dive_types/presentation/providers/dive_type_providers.dart';
import 'package:submersion/l10n/l10n_extension.dart';

/// Multi-select dive-type field: collapses to a row of chips for the selected
/// types and expands (as an anchored dropdown of checkboxes) to add or remove
/// types. Enforces the at-least-one invariant — the last selected type cannot
/// be unchecked. Includes an inline "Add custom type…" affordance.
class DiveTypeMultiSelectField extends ConsumerWidget {
  const DiveTypeMultiSelectField({
    super.key,
    required this.selectedTypeIds,
    required this.onChanged,
    this.labelText,
  });

  /// The currently selected dive-type slugs (>= 1 by invariant).
  final List<String> selectedTypeIds;

  /// Called with the new set whenever the selection changes.
  final ValueChanged<List<String>> onChanged;

  final String? labelText;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final typesAsync = ref.watch(diveTypesProvider);
    final label = labelText ?? context.l10n.diveLog_edit_label_diveTypes;

    return typesAsync.when(
      loading: () => const LinearProgressIndicator(),
      error: (e, _) =>
          Text(context.l10n.diveLog_edit_errorLoadingDiveTypes(e.toString())),
      data: (types) {
        final nameById = {for (final t in types) t.id: t.name};
        String nameOf(String id) =>
            nameById[id] ?? Dive.diveTypeDisplayName(id);

        void toggle(String id, bool selected) {
          final next = [...selectedTypeIds];
          if (selected) {
            if (!next.contains(id)) next.add(id);
          } else {
            next.remove(id);
            if (next.isEmpty) return; // enforce >= 1: ignore the last uncheck
          }
          onChanged(next);
        }

        return MenuAnchor(
          menuChildren: [
            for (final t in types)
              CheckboxMenuButton(
                value: selectedTypeIds.contains(t.id),
                onChanged: (v) => toggle(t.id, v ?? false),
                child: Text(t.name),
              ),
            MenuItemButton(
              leadingIcon: const Icon(Icons.add),
              onPressed: () => _addCustomType(context, ref),
              child: Text(context.l10n.diveLog_edit_addCustomDiveType),
            ),
          ],
          builder: (context, controller, child) {
            return InkWell(
              onTap: () =>
                  controller.isOpen ? controller.close() : controller.open(),
              child: InputDecorator(
                decoration: InputDecoration(
                  labelText: label,
                  suffixIcon: const Icon(Icons.arrow_drop_down),
                ),
                child: Wrap(
                  spacing: 6,
                  runSpacing: 4,
                  children: [
                    for (final id in selectedTypeIds)
                      Chip(
                        label: Text(nameOf(id)),
                        materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                        visualDensity: VisualDensity.compact,
                      ),
                  ],
                ),
              ),
            );
          },
        );
      },
    );
  }

  Future<void> _addCustomType(BuildContext context, WidgetRef ref) async {
    final controller = TextEditingController();
    final name = await showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(ctx.l10n.diveLog_edit_addCustomDiveType),
        content: TextField(
          controller: controller,
          autofocus: true,
          textCapitalization: TextCapitalization.words,
          decoration: InputDecoration(
            labelText: ctx.l10n.diveLog_edit_label_diveType,
          ),
          onSubmitted: (v) => Navigator.pop(ctx, v.trim()),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: Text(ctx.l10n.common_action_cancel),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, controller.text.trim()),
            child: Text(ctx.l10n.diveLog_edit_add),
          ),
        ],
      ),
    );
    if (name == null || name.isEmpty) return;
    try {
      final created = await ref
          .read(diveTypeListNotifierProvider.notifier)
          .addDiveTypeByName(name);
      if (!selectedTypeIds.contains(created.id)) {
        onChanged([...selectedTypeIds, created.id]);
      }
    } catch (_) {
      // e.g. no valid diver profile — leave the selection unchanged.
    }
  }
}
