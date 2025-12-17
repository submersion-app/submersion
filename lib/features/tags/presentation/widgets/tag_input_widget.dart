import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../domain/entities/tag.dart';
import '../providers/tag_providers.dart';

/// Widget for selecting and creating tags
class TagInputWidget extends ConsumerStatefulWidget {
  final List<Tag> selectedTags;
  final void Function(List<Tag> tags) onTagsChanged;
  final bool enabled;

  const TagInputWidget({
    super.key,
    required this.selectedTags,
    required this.onTagsChanged,
    this.enabled = true,
  });

  @override
  ConsumerState<TagInputWidget> createState() => _TagInputWidgetState();
}

class _TagInputWidgetState extends ConsumerState<TagInputWidget> {
  final _textController = TextEditingController();
  final _focusNode = FocusNode();
  bool _showSuggestions = false;

  @override
  void dispose() {
    _textController.dispose();
    _focusNode.dispose();
    super.dispose();
  }

  void _addTag(Tag tag) {
    if (!widget.selectedTags.any((t) => t.id == tag.id)) {
      widget.onTagsChanged([...widget.selectedTags, tag]);
    }
    _textController.clear();
    setState(() => _showSuggestions = false);
  }

  void _removeTag(Tag tag) {
    widget.onTagsChanged(
      widget.selectedTags.where((t) => t.id != tag.id).toList(),
    );
  }

  Future<void> _createAndAddTag(String name) async {
    if (name.trim().isEmpty) return;

    final tagNotifier = ref.read(tagListNotifierProvider.notifier);
    final newTag = await tagNotifier.getOrCreateTag(
      name.trim(),
      colorHex: TagColors.predefined[
          widget.selectedTags.length % TagColors.predefined.length],
    );
    _addTag(newTag);
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final allTagsAsync = ref.watch(tagListNotifierProvider);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Selected tags chips
        if (widget.selectedTags.isNotEmpty) ...[
          Wrap(
            spacing: 8,
            runSpacing: 4,
            children: widget.selectedTags.map((tag) {
              return Chip(
                label: Text(tag.name),
                backgroundColor: tag.color.withValues(alpha: 0.2),
                side: BorderSide(color: tag.color),
                deleteIcon: widget.enabled
                    ? Icon(Icons.close, size: 18, color: tag.color)
                    : null,
                onDeleted: widget.enabled ? () => _removeTag(tag) : null,
                labelStyle: TextStyle(color: tag.color),
                visualDensity: VisualDensity.compact,
              );
            }).toList(),
          ),
          const SizedBox(height: 8),
        ],

        // Tag input field
        if (widget.enabled) ...[
          Focus(
            onFocusChange: (hasFocus) {
              if (!hasFocus) {
                // Delay hiding to allow tap on suggestion
                Future.delayed(const Duration(milliseconds: 200), () {
                  if (mounted) {
                    setState(() => _showSuggestions = false);
                  }
                });
              }
            },
            child: TextField(
              controller: _textController,
              focusNode: _focusNode,
              decoration: InputDecoration(
                hintText: widget.selectedTags.isEmpty
                    ? 'Add tags...'
                    : 'Add more tags...',
                prefixIcon: const Icon(Icons.label_outline),
                suffixIcon: _textController.text.isNotEmpty
                    ? IconButton(
                        icon: const Icon(Icons.add),
                        onPressed: () => _createAndAddTag(_textController.text),
                        tooltip: 'Create tag',
                      )
                    : null,
                border: const OutlineInputBorder(),
                contentPadding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 8,
                ),
              ),
              onChanged: (value) {
                setState(() => _showSuggestions = value.isNotEmpty);
              },
              onSubmitted: (value) {
                if (value.trim().isNotEmpty) {
                  _createAndAddTag(value);
                }
              },
            ),
          ),

          // Suggestions dropdown
          if (_showSuggestions && _textController.text.isNotEmpty)
            allTagsAsync.when(
              data: (allTags) {
                final query = _textController.text.toLowerCase();
                final filteredTags = allTags
                    .where((tag) =>
                        tag.name.toLowerCase().contains(query) &&
                        !widget.selectedTags.any((t) => t.id == tag.id))
                    .take(5)
                    .toList();

                final exactMatch = allTags.any(
                    (tag) => tag.name.toLowerCase() == query.toLowerCase());

                if (filteredTags.isEmpty && exactMatch) {
                  return const SizedBox.shrink();
                }

                return Container(
                  margin: const EdgeInsets.only(top: 4),
                  decoration: BoxDecoration(
                    color: theme.colorScheme.surface,
                    borderRadius: BorderRadius.circular(8),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withValues(alpha: 0.1),
                        blurRadius: 8,
                        offset: const Offset(0, 2),
                      ),
                    ],
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      // Existing tag suggestions
                      ...filteredTags.map((tag) => ListTile(
                            dense: true,
                            leading: CircleAvatar(
                              radius: 12,
                              backgroundColor: tag.color,
                            ),
                            title: Text(tag.name),
                            onTap: () => _addTag(tag),
                          )),

                      // Create new tag option
                      if (!exactMatch)
                        ListTile(
                          dense: true,
                          leading: CircleAvatar(
                            radius: 12,
                            backgroundColor: TagColors.fromHex(
                              TagColors.predefined[widget.selectedTags.length %
                                  TagColors.predefined.length],
                            ),
                            child: const Icon(Icons.add,
                                size: 14, color: Colors.white),
                          ),
                          title: Text('Create "${_textController.text}"'),
                          onTap: () => _createAndAddTag(_textController.text),
                        ),
                    ],
                  ),
                );
              },
              loading: () => const Padding(
                padding: EdgeInsets.all(8.0),
                child: Center(child: CircularProgressIndicator()),
              ),
              error: (e, _) => const SizedBox.shrink(),
            ),
        ],
      ],
    );
  }
}

/// Compact tag display widget (for list views)
class TagChips extends StatelessWidget {
  final List<Tag> tags;
  final int maxTags;

  const TagChips({
    super.key,
    required this.tags,
    this.maxTags = 3,
  });

  @override
  Widget build(BuildContext context) {
    if (tags.isEmpty) return const SizedBox.shrink();

    final displayTags = tags.take(maxTags).toList();
    final remaining = tags.length - maxTags;

    return Wrap(
      spacing: 4,
      runSpacing: 2,
      children: [
        ...displayTags.map((tag) => Container(
              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
              decoration: BoxDecoration(
                color: tag.color.withValues(alpha: 0.15),
                borderRadius: BorderRadius.circular(4),
                border: Border.all(color: tag.color.withValues(alpha: 0.3)),
              ),
              child: Text(
                tag.name,
                style: TextStyle(
                  fontSize: 11,
                  color: tag.color,
                ),
              ),
            )),
        if (remaining > 0)
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
            decoration: BoxDecoration(
              color: Colors.grey.withValues(alpha: 0.15),
              borderRadius: BorderRadius.circular(4),
            ),
            child: Text(
              '+$remaining',
              style: TextStyle(
                fontSize: 11,
                color: Colors.grey[600],
              ),
            ),
          ),
      ],
    );
  }
}

/// Dialog for managing all tags
class TagManagementDialog extends ConsumerWidget {
  const TagManagementDialog({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final tagsAsync = ref.watch(tagListNotifierProvider);

    return AlertDialog(
      title: const Text('Manage Tags'),
      content: SizedBox(
        width: 300,
        height: 400,
        child: tagsAsync.when(
          data: (tags) {
            if (tags.isEmpty) {
              return const Center(
                child: Text('No tags yet. Create tags when editing dives.'),
              );
            }
            return ListView.builder(
              itemCount: tags.length,
              itemBuilder: (context, index) {
                final tag = tags[index];
                return ListTile(
                  leading: CircleAvatar(
                    radius: 16,
                    backgroundColor: tag.color,
                  ),
                  title: Text(tag.name),
                  trailing: IconButton(
                    icon: const Icon(Icons.delete_outline),
                    onPressed: () => _confirmDelete(context, ref, tag),
                  ),
                  onTap: () => _editTag(context, ref, tag),
                );
              },
            );
          },
          loading: () => const Center(child: CircularProgressIndicator()),
          error: (e, _) => Center(child: Text('Error: $e')),
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Close'),
        ),
      ],
    );
  }

  void _confirmDelete(BuildContext context, WidgetRef ref, Tag tag) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete Tag?'),
        content: Text(
            'Are you sure you want to delete "${tag.name}"? This will remove it from all dives.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () {
              ref.read(tagListNotifierProvider.notifier).deleteTag(tag.id);
              Navigator.pop(context);
            },
            style: TextButton.styleFrom(foregroundColor: Colors.red),
            child: const Text('Delete'),
          ),
        ],
      ),
    );
  }

  void _editTag(BuildContext context, WidgetRef ref, Tag tag) {
    final controller = TextEditingController(text: tag.name);
    String selectedColor = tag.colorHex ?? TagColors.predefined.first;

    showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setState) => AlertDialog(
          title: const Text('Edit Tag'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: controller,
                decoration: const InputDecoration(
                  labelText: 'Tag Name',
                  border: OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 16),
              const Text('Color'),
              const SizedBox(height: 8),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: TagColors.predefined.map((color) {
                  final isSelected = color == selectedColor;
                  return GestureDetector(
                    onTap: () => setState(() => selectedColor = color),
                    child: Container(
                      width: 32,
                      height: 32,
                      decoration: BoxDecoration(
                        color: TagColors.fromHex(color),
                        shape: BoxShape.circle,
                        border: isSelected
                            ? Border.all(
                                color: Colors.white,
                                width: 3,
                              )
                            : null,
                        boxShadow: isSelected
                            ? [
                                BoxShadow(
                                  color: TagColors.fromHex(color)
                                      .withValues(alpha: 0.5),
                                  blurRadius: 8,
                                )
                              ]
                            : null,
                      ),
                    ),
                  );
                }).toList(),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Cancel'),
            ),
            TextButton(
              onPressed: () {
                if (controller.text.trim().isNotEmpty) {
                  ref.read(tagListNotifierProvider.notifier).updateTag(
                        tag.copyWith(
                          name: controller.text.trim(),
                          colorHex: selectedColor,
                          updatedAt: DateTime.now(),
                        ),
                      );
                  Navigator.pop(context);
                }
              },
              child: const Text('Save'),
            ),
          ],
        ),
      ),
    );
  }
}

/// Color picker for tags
class TagColorPicker extends StatelessWidget {
  final String? selectedColor;
  final void Function(String color) onColorSelected;

  const TagColorPicker({
    super.key,
    this.selectedColor,
    required this.onColorSelected,
  });

  @override
  Widget build(BuildContext context) {
    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: TagColors.predefined.map((color) {
        final isSelected = color == selectedColor;
        return GestureDetector(
          onTap: () => onColorSelected(color),
          child: Container(
            width: 28,
            height: 28,
            decoration: BoxDecoration(
              color: TagColors.fromHex(color),
              shape: BoxShape.circle,
              border: isSelected
                  ? Border.all(color: Colors.white, width: 2)
                  : null,
              boxShadow: isSelected
                  ? [
                      BoxShadow(
                        color: TagColors.fromHex(color).withValues(alpha: 0.5),
                        blurRadius: 6,
                      )
                    ]
                  : null,
            ),
            child: isSelected
                ? const Icon(Icons.check, size: 16, color: Colors.white)
                : null,
          ),
        );
      }).toList(),
    );
  }
}
