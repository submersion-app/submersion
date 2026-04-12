import 'package:flutter/material.dart';

import 'package:submersion/features/import_wizard/domain/models/tag_selection.dart';
import 'package:submersion/features/tags/domain/entities/tag.dart';
import 'package:submersion/l10n/l10n_extension.dart';

/// Multi-tag chip field with autocomplete for the import review step.
///
/// Displays current tags as removable [InputChip]s and provides an
/// autocomplete text field for adding existing or new tags.
class ImportTagsField extends StatefulWidget {
  const ImportTagsField({
    super.key,
    required this.tags,
    required this.existingTags,
    required this.onAdd,
    required this.onRemove,
  });

  /// Currently selected tags.
  final List<TagSelection> tags;

  /// All existing tags from the database for autocomplete suggestions.
  final List<Tag> existingTags;

  /// Called when the user adds a tag (existing or new).
  final ValueChanged<TagSelection> onAdd;

  /// Called when the user removes a tag by index.
  final ValueChanged<int> onRemove;

  @override
  State<ImportTagsField> createState() => _ImportTagsFieldState();
}

class _ImportTagsFieldState extends State<ImportTagsField> {
  final _textController = TextEditingController();
  final _focusNode = FocusNode();

  @override
  void dispose() {
    _textController.dispose();
    _focusNode.dispose();
    super.dispose();
  }

  void _submitTag(String text) {
    final trimmed = text.trim();
    if (trimmed.isEmpty) return;

    // Check if it matches an existing tag by name (case-insensitive).
    final match = widget.existingTags.cast<Tag?>().firstWhere(
      (t) => t!.name.toLowerCase() == trimmed.toLowerCase(),
      orElse: () => null,
    );

    if (match != null) {
      widget.onAdd(TagSelection(existingTagId: match.id, name: match.name));
    } else {
      widget.onAdd(TagSelection(name: trimmed));
    }

    _textController.clear();
  }

  /// Resolve the display color for a [TagSelection] by looking up its
  /// matching [Tag] in [widget.existingTags]. Falls back to the theme
  /// primary color for brand-new tags not yet in the database.
  Color _resolveColor(TagSelection selection) {
    final match = widget.existingTags.cast<Tag?>().firstWhere(
      (t) =>
          (selection.existingTagId != null &&
              t!.id == selection.existingTagId) ||
          t!.name.toLowerCase() == selection.name.toLowerCase(),
      orElse: () => null,
    );
    return match?.color ?? Theme.of(context).colorScheme.primary;
  }

  /// Filter existing tags that match the query and aren't already selected.
  List<Tag> _filteredSuggestions(String query) {
    if (query.isEmpty) return [];

    final selectedNames = widget.tags.map((t) => t.name.toLowerCase()).toSet();

    return widget.existingTags.where((tag) {
      final matchesQuery = tag.name.toLowerCase().contains(query.toLowerCase());
      final notAlreadySelected = !selectedNames.contains(
        tag.name.toLowerCase(),
      );
      return matchesQuery && notAlreadySelected;
    }).toList();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final l10n = context.l10n;

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: RawAutocomplete<Tag>(
        textEditingController: _textController,
        focusNode: _focusNode,
        optionsBuilder: (textEditingValue) {
          return _filteredSuggestions(textEditingValue.text);
        },
        onSelected: (tag) {
          widget.onAdd(TagSelection(existingTagId: tag.id, name: tag.name));
          _textController.clear();
        },
        fieldViewBuilder: (context, controller, focusNode, onSubmitted) {
          return Wrap(
            spacing: 8,
            runSpacing: 4,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: [
              // Icon + label as one atomic cell so they stay together when
              // the row wraps. Lives inline with the chips so the whole
              // field fits on one line when space permits.
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    Icons.label_outline,
                    size: 18,
                    color: colorScheme.primary,
                  ),
                  const SizedBox(width: 8),
                  Text(
                    l10n.importWizard_tagsLabel,
                    style: theme.textTheme.titleSmall?.copyWith(
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
              for (var i = 0; i < widget.tags.length; i++)
                () {
                  final tagColor = _resolveColor(widget.tags[i]);
                  return Chip(
                    label: Text(widget.tags[i].name),
                    backgroundColor: tagColor.withValues(alpha: 0.2),
                    side: BorderSide(color: tagColor),
                    labelStyle: TextStyle(color: tagColor),
                    deleteIcon: Icon(Icons.close, size: 18, color: tagColor),
                    onDeleted: () => widget.onRemove(i),
                    visualDensity: VisualDensity.compact,
                  );
                }(),
              IntrinsicWidth(
                child: TextField(
                  controller: controller,
                  focusNode: focusNode,
                  decoration: InputDecoration(
                    hintText: widget.tags.isEmpty
                        ? l10n.tags_hint_addTags
                        : l10n.tags_hint_addMoreTags,
                    border: InputBorder.none,
                    isDense: true,
                    contentPadding: const EdgeInsets.symmetric(vertical: 8),
                  ),
                  onSubmitted: (text) {
                    _submitTag(text);
                    onSubmitted();
                  },
                ),
              ),
            ],
          );
        },
        optionsViewBuilder: (context, onSelected, options) {
          return Align(
            alignment: Alignment.topLeft,
            child: Material(
              elevation: 4,
              borderRadius: BorderRadius.circular(8),
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxHeight: 200),
                child: ListView.builder(
                  padding: EdgeInsets.zero,
                  shrinkWrap: true,
                  itemCount: options.length,
                  itemBuilder: (context, index) {
                    final tag = options.elementAt(index);
                    return ListTile(
                      dense: true,
                      leading: Icon(Icons.label, color: tag.color, size: 20),
                      title: Text(tag.name),
                      onTap: () => onSelected(tag),
                    );
                  },
                ),
              ),
            ),
          );
        },
      ),
    );
  }
}
