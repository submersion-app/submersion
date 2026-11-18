import 'package:flutter/material.dart';

import 'package:submersion/features/dive_sites/presentation/widgets/edit_sections/site_type_chips.dart';
import 'package:submersion/features/site_types/domain/entities/site_type_entity.dart';
import 'package:submersion/features/tags/domain/entities/tag.dart';
import 'package:submersion/features/tags/presentation/widgets/tag_form_block.dart';
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
    return FormSection(
      label: l10n.diveSites_edit_group_typeTags,
      icon: Icons.category_outlined,
      expanded: true,
      onToggle: null,
      // FormSection draws a divider between children, so each block (its
      // overline plus content) is one child that pads itself (issue #3578).
      children: [
        SiteTypeChips(
          allTypes: allTypes,
          selectedTypeIds: selectedTypeIds,
          onTypesChanged: onTypesChanged,
          onManageTypes: onManageTypes,
          hiddenTypeIds: hiddenTypeIds,
          keepTypeIds: keepTypeIds,
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
