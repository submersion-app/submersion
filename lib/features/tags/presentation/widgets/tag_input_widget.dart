import 'package:flutter/material.dart';
import 'package:submersion/core/providers/provider.dart';

import 'package:submersion/features/tags/domain/entities/tag.dart';
import 'package:submersion/features/tags/presentation/widgets/tag_chip.dart';
import 'package:submersion/l10n/l10n_extension.dart';
import 'package:submersion/features/tags/presentation/providers/tag_providers.dart';

/// Widget for selecting and creating tags
class TagInputWidget extends ConsumerStatefulWidget {
  final List<Tag> selectedTags;
  final void Function(List<Tag> tags) onTagsChanged;
  final bool enabled;

  /// Which tags are suggested and what a new tag applies to (issue #1765).
  /// A name already used by a tag of the other scope widens that tag rather
  /// than creating a second one.
  final TagScope scope;

  const TagInputWidget({
    super.key,
    required this.selectedTags,
    required this.onTagsChanged,
    this.enabled = true,
    this.scope = TagScope.dives,
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
      colorHex: TagColors
          .predefined[widget.selectedTags.length % TagColors.predefined.length],
      scope: widget.scope,
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
              return TagChip(
                tag: tag,
                onDeleted: widget.enabled ? () => _removeTag(tag) : null,
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
                    ? context.l10n.tags_hint_addTags
                    : context.l10n.tags_hint_addMoreTags,
                prefixIcon: const Icon(Icons.label_outline),
                suffixIcon: _textController.text.isNotEmpty
                    ? IconButton(
                        icon: const Icon(Icons.add),
                        onPressed: () => _createAndAddTag(_textController.text),
                        tooltip: context.l10n.tags_action_createTag,
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
              data: (everyTag) {
                // Only tags offered where this input is. Typing the name of
                // a tag from the other scope still offers "create", which
                // widens that tag instead of duplicating it.
                final allTags = everyTag
                    .where((tag) => tag.appliesTo(widget.scope))
                    .toList();
                final query = _textController.text.toLowerCase();
                final filteredTags = allTags
                    .where(
                      (tag) =>
                          tag.name.toLowerCase().contains(query) &&
                          !widget.selectedTags.any((t) => t.id == tag.id),
                    )
                    .take(5)
                    .toList();

                final exactMatch = allTags.any(
                  (tag) => tag.name.toLowerCase() == query.toLowerCase(),
                );

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
                  // The tiles need a Material of their own inside the
                  // decorated box, or their ink paints behind its background
                  // (and Flutter asserts in debug builds).
                  child: Material(
                    type: MaterialType.transparency,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        // Existing tag suggestions
                        ...filteredTags.map(
                          (tag) => ListTile(
                            dense: true,
                            leading: CircleAvatar(
                              radius: 12,
                              backgroundColor: tag.color,
                            ),
                            title: Text(tag.name),
                            onTap: () => _addTag(tag),
                          ),
                        ),

                        // Create new tag option
                        if (!exactMatch)
                          ListTile(
                            dense: true,
                            leading: CircleAvatar(
                              radius: 12,
                              backgroundColor: TagColors.fromHex(
                                TagColors.predefined[widget
                                        .selectedTags
                                        .length %
                                    TagColors.predefined.length],
                              ),
                              child: const Icon(
                                Icons.add,
                                size: 14,
                                color: Colors.white,
                              ),
                            ),
                            title: Text(
                              context.l10n.tags_action_createNamed(
                                _textController.text,
                              ),
                            ),
                            onTap: () => _createAndAddTag(_textController.text),
                          ),
                      ],
                    ),
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

  const TagChips({super.key, required this.tags, this.maxTags = 3});

  @override
  Widget build(BuildContext context) {
    if (tags.isEmpty) return const SizedBox.shrink();

    final displayTags = tags.take(maxTags).toList();
    final remaining = tags.length - maxTags;

    return Wrap(
      spacing: 4,
      runSpacing: 2,
      children: [
        ...displayTags.map((tag) => TagChip(tag: tag, dense: true)),
        if (remaining > 0)
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
            decoration: BoxDecoration(
              color: Colors.grey.withValues(alpha: 0.15),
              borderRadius: BorderRadius.circular(4),
            ),
            child: Text(
              '+$remaining',
              style: TextStyle(fontSize: 11, color: Colors.grey[600]),
            ),
          ),
      ],
    );
  }
}

/// The colour choices for a tag, each shown as the chip the tag will become
/// (issue #2269).
///
/// The swatches used to be solid 28 dp dots of the stored hex, which is a
/// colour a tag never actually displays: a chip is a tint of it. Offering the
/// raw hex here is what made Settings disagree with the rest of the app in
/// issue #2254. Every swatch is now a real [TagChip] drawn by the same
/// [tagChipColors], carrying the name being typed, so choosing a colour is
/// choosing a preview rather than a code.
class TagColorPicker extends StatelessWidget {
  final String? selectedColor;
  final void Function(String color) onColorSelected;

  /// The tag's name field, so each swatch previews this tag rather than a
  /// generic one and keeps up as the name is typed. A null or empty
  /// controller leaves the swatches unlabelled, which is what the Add dialog
  /// shows before anything has been entered.
  final TextEditingController? nameController;

  const TagColorPicker({
    super.key,
    this.selectedColor,
    required this.onColorSelected,
    this.nameController,
  });

  @override
  Widget build(BuildContext context) {
    final controller = nameController;
    if (controller == null) return _swatches('');

    return ValueListenableBuilder<TextEditingValue>(
      valueListenable: controller,
      builder: (context, value, _) => _swatches(value.text),
    );
  }

  Widget _swatches(String name) => Wrap(
    spacing: 8,
    runSpacing: 8,
    children: [
      for (final hex in TagColors.predefined)
        _ColorSwatch(
          hex: hex,
          name: name,
          isSelected: hex == selectedColor,
          onTap: () => onColorSelected(hex),
        ),
    ],
  );
}

/// One colour choice, shown as the chip it produces.
class _ColorSwatch extends StatelessWidget {
  const _ColorSwatch({
    required this.hex,
    required this.name,
    required this.isSelected,
    required this.onTap,
  });

  final String hex;
  final String name;
  final bool isSelected;
  final VoidCallback onTap;

  /// Enough of a long tag name to recognise the preview by, without one
  /// swatch driving the grid down to a single column. Twenty labelled chips
  /// wrap to several times the height of twenty dots, so the grid is kept
  /// tight and the dialog's own scroll view carries the rest.
  static const double _maxChipWidth = 96;

  /// A swatch with nothing to label it is still a chip, not a hairline.
  static const double _minChipWidth = 32;

  /// The ring the chosen swatch wears. Reserved on every swatch and left
  /// transparent where it is not worn, so choosing one does not reflow the
  /// grid under the pointer.
  static const double _ringWidth = 2;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final target = tagTapTarget(Theme.of(context).platform);

    return Semantics(
      button: true,
      label: 'Select color $hex',
      selected: isSelected,
      child: GestureDetector(
        onTap: onTap,
        // Opaque so the whole target answers the tap, not only the pixels the
        // chip happens to cover.
        behavior: HitTestBehavior.opaque,
        child: ConstrainedBox(
          // The swatch is a control the diver taps, so it owns the platform's
          // tap target even though the chip it previews is 29 dp tall. The
          // dots it replaced were 28 dp and cleared neither floor either.
          constraints: BoxConstraints(minWidth: target, minHeight: target),
          child: Center(
            widthFactor: 1,
            child: Container(
              padding: const EdgeInsets.all(3),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                  color: isSelected ? scheme.primary : Colors.transparent,
                  width: _ringWidth,
                ),
              ),
              child: ConstrainedBox(
                constraints: const BoxConstraints(
                  minWidth: _minChipWidth,
                  maxWidth: _maxChipWidth,
                ),
                // The chip is this control's picture, not its description.
                // Its label repeats the name field above on all twenty
                // swatches, and announcing it once per swatch would bury the
                // colour, which is the only thing that differs between them.
                child: ExcludeSemantics(
                  child: TagChip.unsaved(
                    name: name,
                    color: TagColors.fromHex(hex),
                    dense: true,
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
