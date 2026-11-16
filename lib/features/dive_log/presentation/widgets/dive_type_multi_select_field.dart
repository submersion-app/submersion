import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:submersion/core/built_ins/built_in_catalog.dart';
import 'package:submersion/core/built_ins/visible_built_ins.dart';
import 'package:submersion/features/dive_log/domain/entities/dive.dart';
import 'package:submersion/features/dive_types/domain/entities/dive_type_entity.dart';
import 'package:submersion/features/dive_types/domain/favourite_dive_types.dart';
import 'package:submersion/features/dive_types/presentation/dive_type_display.dart';
import 'package:submersion/features/dive_types/presentation/providers/dive_type_providers.dart';
import 'package:submersion/features/dive_types/presentation/widgets/dive_type_favourite_button.dart';
import 'package:submersion/features/settings/presentation/providers/hidden_built_ins_provider.dart';
import 'package:submersion/l10n/l10n_extension.dart';

/// Multi-select dive-type field: shows the selected types as a row of chips and
/// opens a bottom-sheet checklist (tap the field) to add or remove types.
/// Enforces the at-least-one invariant -- the last selected type cannot be
/// unchecked -- unless [allowEmpty] is set (bulk-edit mode). Custom types are
/// managed on the dedicated dive-types page.
///
/// Uses a modal bottom sheet (mirroring [BuddyPicker]) rather than an anchored
/// menu: Flutter 3.44's MenuAnchor regressed and would not open on macOS, so a
/// tap on the field appeared dead. The sheet path is the one already proven in
/// this form.
class DiveTypeMultiSelectField extends ConsumerWidget {
  const DiveTypeMultiSelectField({
    super.key,
    required this.selectedTypeIds,
    required this.onChanged,
    this.labelText,
    this.allowEmpty = false,
    this.keepTypeIds = const [],
  });

  /// The currently selected dive-type slugs (>= 1 by invariant).
  final List<String> selectedTypeIds;

  /// Called with the new set whenever the selection changes.
  final ValueChanged<List<String>> onChanged;

  final String? labelText;

  /// When true (bulk-edit mode), the selection may be cleared to empty. The
  /// >= 1 invariant only applies to a single dive's own type set, not to the
  /// "which types to add/remove/replace" selection in bulk mode.
  final bool allowEmpty;

  /// Types to offer even when hidden from the pickers (issue #401): the ones
  /// the dive had when the editor opened, so unticking one and reopening the
  /// checklist can undo it.
  final List<String> keepTypeIds;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final typesAsync = ref.watch(diveTypesProvider);
    final hidden = ref.watch(
      hiddenBuiltInIdsProvider(BuiltInCatalog.diveTypes),
    );
    final label = labelText ?? context.l10n.diveLog_edit_label_diveTypes;

    // diveTypesProvider self-invalidates on every dive_types write (e.g. an
    // incoming sync), which drops it back into a loading state while Riverpod
    // keeps the previous value. Render from that retained value so a background
    // reload never flashes a bare progress bar over the chips; the spinner is
    // shown only on the very first load, before any data has arrived. This
    // mirrors the notifier's silent-reload behaviour. See #429.
    final types = typesAsync.value;
    if (types == null) {
      if (typesAsync.hasError) {
        return Text(
          context.l10n.diveLog_edit_errorLoadingDiveTypes(
            typesAsync.error.toString(),
          ),
        );
      }
      return const LinearProgressIndicator();
    }

    final nameById = {
      for (final t in types) t.id: t.localizedName(context.l10n),
    };
    String nameOf(String id) =>
        nameById[id] ??
        builtInDiveTypeName(context.l10n, id) ??
        Dive.diveTypeDisplayName(id);

    return InkWell(
      // Hidden built-ins leave the checklist (issue #401), except the ones
      // this dive already has; favourites then lead it (issue #4413). The
      // list is fixed while the sheet is open, so unticking a hidden type or
      // starring one there does not move or remove a row.
      onTap: () {
        final visible = visibleBuiltIns(
          types,
          hidden,
          isBuiltIn: (t) => t.isBuiltIn,
          idOf: (t) => t.id,
          keep: [...selectedTypeIds, ...keepTypeIds],
        );
        final favourites = ref.read(favouriteDiveTypeIdsProvider);
        _openPicker(
          context,
          favouritesFirst(visible, favourites, idOf: (t) => t.id),
          {
            for (final t in visible)
              if (favourites.contains(t.id)) t.id,
          },
          label,
        );
      },
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
  }

  Future<void> _openPicker(
    BuildContext context,
    List<DiveTypeEntity> types,
    Set<String> favouriteIds,
    String title,
  ) {
    return showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      showDragHandle: true,
      builder: (context) => _DiveTypePickerSheet(
        title: title,
        types: types,
        favouriteIds: favouriteIds,
        selectedTypeIds: selectedTypeIds,
        allowEmpty: allowEmpty,
        onChanged: onChanged,
      ),
    );
  }
}

/// The bottom-sheet checklist. Holds its own working selection while open and
/// reports each change live via [onChanged] (matching the original field's
/// per-toggle semantics), so the sheet stays open for multiple selections.
class _DiveTypePickerSheet extends StatefulWidget {
  const _DiveTypePickerSheet({
    required this.title,
    required this.types,
    required this.favouriteIds,
    required this.selectedTypeIds,
    required this.allowEmpty,
    required this.onChanged,
  });

  final String title;
  final List<DiveTypeEntity> types;

  /// The ids that were starred, and offered, when the sheet opened: the rows
  /// under the Favorites heading. Starring in the open sheet does not change
  /// it, so rows stay put until the sheet is reopened.
  final Set<String> favouriteIds;
  final List<String> selectedTypeIds;
  final bool allowEmpty;
  final ValueChanged<List<String>> onChanged;

  @override
  State<_DiveTypePickerSheet> createState() => _DiveTypePickerSheetState();
}

class _DiveTypePickerSheetState extends State<_DiveTypePickerSheet> {
  late List<String> _working = [...widget.selectedTypeIds];

  void _toggle(String id, bool selected) {
    final next = [..._working];
    if (selected) {
      if (!next.contains(id)) next.add(id);
    } else {
      next.remove(id);
      // Single-dive editor enforces >= 1; bulk mode allows clearing.
      if (next.isEmpty && !widget.allowEmpty) return;
    }
    setState(() => _working = next);
    widget.onChanged(next);
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return SafeArea(
      child: ConstrainedBox(
        constraints: BoxConstraints(
          maxHeight: MediaQuery.sizeOf(context).height * 0.6,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 0, 12, 4),
              child: Row(
                children: [
                  Expanded(
                    child: Text(
                      widget.title,
                      style: theme.textTheme.titleMedium,
                    ),
                  ),
                  TextButton(
                    onPressed: () => Navigator.of(context).pop(),
                    child: Text(context.l10n.common_action_close),
                  ),
                ],
              ),
            ),
            Flexible(
              child: ListView(
                shrinkWrap: true,
                children: [
                  if (widget.favouriteIds.isNotEmpty)
                    Padding(
                      padding: const EdgeInsets.fromLTRB(20, 8, 20, 4),
                      child: Semantics(
                        header: true,
                        child: Text(
                          context.l10n.diveTypes_favourites_header,
                          style: theme.textTheme.titleSmall?.copyWith(
                            color: theme.colorScheme.primary,
                          ),
                        ),
                      ),
                    ),
                  for (final (i, t) in widget.types.indexed) ...[
                    // The starred rows lead the list, so the divider goes
                    // right after the last of them.
                    if (widget.favouriteIds.isNotEmpty &&
                        i == widget.favouriteIds.length)
                      const Divider(),
                    // The star sits beside the tile, not in its `secondary`:
                    // CheckboxListTile merges its semantics, which would fold
                    // the star into the row for a screen reader.
                    Row(
                      children: [
                        Expanded(
                          child: CheckboxListTile(
                            value: _working.contains(t.id),
                            onChanged: (v) => _toggle(t.id, v ?? false),
                            controlAffinity: ListTileControlAffinity.leading,
                            title: Text(t.localizedName(context.l10n)),
                          ),
                        ),
                        Padding(
                          padding: const EdgeInsetsDirectional.only(end: 8),
                          child: DiveTypeFavouriteButton(
                            diveTypeId: t.id,
                            diveTypeName: t.localizedName(context.l10n),
                          ),
                        ),
                      ],
                    ),
                  ],
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
