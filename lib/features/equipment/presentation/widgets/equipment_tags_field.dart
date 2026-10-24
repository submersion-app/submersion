import 'package:flutter/material.dart';

import 'package:submersion/features/tags/domain/entities/tag.dart';
import 'package:submersion/features/tags/presentation/widgets/scoped_tags_field.dart';
import 'package:submersion/l10n/l10n_extension.dart';

/// The Tags field on the equipment edit page (issue #1942): the shared
/// [ScopedTagsField] limited to equipment tags. A tag created here applies
/// to equipment; a name already used by a dive or site tag widens that tag
/// instead of creating a second one.
class EquipmentTagsField extends StatelessWidget {
  const EquipmentTagsField({
    super.key,
    required this.selectedTags,
    required this.onTagsChanged,
    this.enabled = true,
  });

  final List<Tag> selectedTags;
  final ValueChanged<List<Tag>> onTagsChanged;

  /// False when the stored tags could not be read. Editing then would save
  /// a set built without them, dropping them.
  final bool enabled;

  @override
  Widget build(BuildContext context) => ScopedTagsField(
    scope: TagScope.equipment,
    label: context.l10n.equipment_edit_tagsLabel,
    browseKey: const ValueKey('equipment_edit_tags_browse'),
    selectedTags: selectedTags,
    onTagsChanged: onTagsChanged,
    enabled: enabled,
  );
}
