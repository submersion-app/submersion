import 'package:flutter/material.dart';

import 'package:submersion/features/site_types/domain/entities/site_type_entity.dart';
import 'package:submersion/features/site_types/presentation/site_type_display.dart';
import 'package:submersion/features/tags/domain/entities/tag.dart';
import 'package:submersion/features/tags/presentation/widgets/tag_input_widget.dart';
import 'package:submersion/l10n/l10n_extension.dart';
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
  });

  /// Every type the diver can choose: built-ins first, then custom types.
  final List<SiteTypeEntity> allTypes;
  final Set<String> selectedTypeIds;
  final ValueChanged<Set<String>> onTypesChanged;
  final List<Tag> selectedTags;
  final ValueChanged<List<Tag>> onTagsChanged;

  /// Opens Settings > Site Types; the link is hidden when null.
  final VoidCallback? onManageTypes;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final labelStyle = Theme.of(context).textTheme.titleSmall;
    return FormSection(
      label: l10n.diveSites_edit_group_typeTags,
      icon: Icons.category_outlined,
      expanded: true,
      onToggle: null,
      children: [
        Text(l10n.diveSites_edit_typeTags_typesLabel, style: labelStyle),
        const SizedBox(height: 8),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          crossAxisAlignment: WrapCrossAlignment.center,
          children: [
            for (final type in allTypes)
              FilterChip(
                label: Text(type.localizedName(l10n)),
                selected: selectedTypeIds.contains(type.id),
                onSelected: (selected) {
                  // Insertion order is kept: types read back in the order
                  // the diver picked them.
                  final next = {...selectedTypeIds};
                  if (selected) {
                    next.add(type.id);
                  } else {
                    next.remove(type.id);
                  }
                  onTypesChanged(next);
                },
              ),
            if (onManageTypes != null)
              TextButton.icon(
                onPressed: onManageTypes,
                icon: const Icon(Icons.tune, size: 18),
                label: Text(l10n.diveSites_edit_typeTags_manageTypes),
              ),
          ],
        ),
        const SizedBox(height: 16),
        Text(l10n.diveSites_edit_typeTags_tagsLabel, style: labelStyle),
        const SizedBox(height: 8),
        TagInputWidget(
          selectedTags: selectedTags,
          onTagsChanged: onTagsChanged,
          scope: TagScope.sites,
        ),
      ],
    );
  }
}
