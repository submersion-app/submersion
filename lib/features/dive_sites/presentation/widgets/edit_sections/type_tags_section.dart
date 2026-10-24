import 'package:flutter/material.dart';

import 'package:submersion/core/built_ins/visible_built_ins.dart';
import 'package:submersion/features/site_types/domain/entities/site_type_entity.dart';
import 'package:submersion/features/site_types/presentation/site_type_display.dart';
import 'package:submersion/features/tags/domain/entities/tag.dart';
import 'package:submersion/features/tags/presentation/widgets/tag_form_block.dart';
import 'package:submersion/l10n/l10n_extension.dart';
import 'package:submersion/shared/widgets/forms/form_overline.dart';
import 'package:submersion/shared/widgets/forms/form_section.dart';

/// Site types (multi-select chips) and site tags on the site edit page
/// (issue #1765).
class TypeTagsSection extends StatelessWidget {
  const TypeTagsSection({
    super.key,
    required this.allTypes,
    required this.selectedTypeIds,
    required this.onTypesChanged,
    required this.selectedTags,
    required this.onTagsChanged,
    this.onManageTypes,
    this.hiddenTypeIds = const {},
    this.keepTypeIds = const {},
  });

  /// Every type the diver can choose: built-ins first, then custom types.
  final List<SiteTypeEntity> allTypes;
  final Set<String> selectedTypeIds;
  final ValueChanged<Set<String>> onTypesChanged;
  final List<Tag> selectedTags;
  final ValueChanged<List<Tag>> onTagsChanged;

  /// Opens Settings > Site Types; the link is hidden when null.
  final VoidCallback? onManageTypes;

  /// Built-in types the diver hid from the pickers (issue #401).
  final Set<String> hiddenTypeIds;

  /// Types to offer even when hidden: the ones the site had when the editor
  /// opened, so unticking one does not make its chip vanish.
  final Set<String> keepTypeIds;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final shownTypes = visibleBuiltIns(
      allTypes,
      hiddenTypeIds,
      isBuiltIn: (t) => t.isBuiltIn,
      idOf: (t) => t.id,
      keep: {...keepTypeIds, ...selectedTypeIds},
    );
    return FormSection(
      label: l10n.diveSites_edit_group_typeTags,
      icon: Icons.category_outlined,
      expanded: true,
      onToggle: null,
      // FormSection draws a divider between children, so each block (its
      // overline plus content) is one child that pads itself (issue #3578).
      children: [
        Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            FormOverline(
              label: l10n.diveSites_edit_typeTags_typesLabel,
              actions: [
                if (onManageTypes != null)
                  FormOverlineAction(
                    label: l10n.diveSites_edit_typeTags_manageTypes,
                    icon: Icons.tune,
                    onPressed: onManageTypes,
                  ),
              ],
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(14, 6, 14, 12),
              child: Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  for (final type in shownTypes)
                    FilterChip(
                      label: Text(type.localizedName(l10n)),
                      selected: selectedTypeIds.contains(type.id),
                      onSelected: (selected) {
                        // Insertion order is kept: types read back in the
                        // order the diver picked them.
                        final next = {...selectedTypeIds};
                        if (selected) {
                          next.add(type.id);
                        } else {
                          next.remove(type.id);
                        }
                        onTypesChanged(next);
                      },
                    ),
                ],
              ),
            ),
          ],
        ),
        // The same tags block the dive edit page shows, limited to site tags.
        TagFormBlock(
          label: l10n.diveSites_edit_typeTags_tagsLabel,
          selectedTags: selectedTags,
          onTagsChanged: onTagsChanged,
          scope: TagScope.sites,
        ),
      ],
    );
  }
}
