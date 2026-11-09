import 'package:flutter/material.dart';

import 'package:submersion/features/tags/domain/entities/tag.dart';
import 'package:submersion/features/tags/domain/tag_palette.dart';
import 'package:submersion/features/tags/presentation/tag_color_names.dart';
import 'package:submersion/features/tags/presentation/widgets/custom_tag_color_dialog.dart';
import 'package:submersion/features/tags/presentation/widgets/tag_chip.dart';
import 'package:submersion/l10n/l10n_extension.dart';

/// The colour choices for a tag (issues #2269 and #4384).
///
/// One preview chip shows the tag as it will look, drawn by the same
/// [tagChipColors] as everywhere else, carrying the name being typed. Below
/// it every palette colour is a dot, one column per hue with its light, base
/// and dark shades, and the columns wrap to the width there is.
///
/// A colour that is not on the palette (an import's, or a custom one) gets a
/// dot of its own at the front, so opening an editor and saving never
/// changes a tag's colour behind the diver's back. The dot stays for the
/// life of the picker, so a diver who tries a palette colour can go back. A
/// "+" dot at the end opens the custom colour dialog.
///
/// [selectedColor] is the stored value, untouched: null for a tag with no
/// colour, which is drawn and shown chosen as the palette Blue.
class TagColorPicker extends StatefulWidget {
  const TagColorPicker({
    super.key,
    required this.selectedColor,
    required this.onColorSelected,
    this.nameController,
  });

  final String? selectedColor;
  final ValueChanged<String> onColorSelected;

  /// The tag's name field, so the preview shows this tag and keeps up as
  /// the name is typed. Null leaves the preview unlabelled.
  final TextEditingController? nameController;

  @override
  State<TagColorPicker> createState() => _TagColorPickerState();
}

class _TagColorPickerState extends State<TagColorPicker> {
  /// The latest colour off the palette this picker was given.
  String? _current;

  static String? _offPalette(String? stored) =>
      stored != null && tagPaletteEntryFor(stored) == null ? stored : null;

  @override
  void initState() {
    super.initState();
    _current = _offPalette(widget.selectedColor);
  }

  @override
  void didUpdateWidget(TagColorPicker oldWidget) {
    super.didUpdateWidget(oldWidget);
    final next = _offPalette(widget.selectedColor);
    if (next != null) _current = next;
  }

  Future<void> _pickCustom() async {
    final picked = await showCustomTagColorDialog(
      context,
      initial: drawnTagColor(widget.selectedColor),
      name: widget.nameController?.text ?? '',
    );
    if (picked != null && mounted) widget.onColorSelected(picked);
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final current = _current;
    final onCurrent = current != null && widget.selectedColor == current;
    final chosen = onCurrent ? null : tagPaletteEntryFor(widget.selectedColor);

    _ColorDot paletteDot(TagPaletteEntry entry) => _ColorDot(
      key: ValueKey('tag-color-${entry.hex}'),
      color: TagColors.fromHex(entry.hex),
      label: tagColorName(l10n, entry),
      selected: entry == chosen,
      onTap: () => widget.onColorSelected(entry.hex),
    );

    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _preview(),
        const SizedBox(height: 12),
        Wrap(
          spacing: 4,
          runSpacing: 4,
          children: [
            if (current != null)
              _ColorDot(
                key: const ValueKey('tag-color-current'),
                color: drawnTagColor(current),
                label: l10n.tags_color_current(current),
                selected: onCurrent,
                onTap: () => widget.onColorSelected(current),
              ),
            for (var hue = 0; hue < tagLightShades.length; hue++)
              Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  for (final entry in tagPalette.where((e) => e.hue == hue))
                    paletteDot(entry),
                ],
              ),
            _ColorDot(
              key: const ValueKey('tag-color-custom'),
              label: l10n.tags_color_custom,
              selected: false,
              onTap: _pickCustom,
            ),
          ],
        ),
      ],
    );
  }

  Widget _preview() {
    Widget chip(String name) => ExcludeSemantics(
      // The name field above already says what this chip says; the dots
      // below carry the colour's name.
      child: ConstrainedBox(
        constraints: const BoxConstraints(minWidth: 32),
        child: TagChip.unsaved(
          name: name,
          color: drawnTagColor(widget.selectedColor),
        ),
      ),
    );

    final controller = widget.nameController;
    if (controller == null) return chip('');
    return ValueListenableBuilder<TextEditingValue>(
      valueListenable: controller,
      builder: (context, value, _) => chip(value.text),
    );
  }
}

/// One colour choice: a filled circle, or with no [color] the "+" that
/// opens the custom colour dialog.
class _ColorDot extends StatelessWidget {
  const _ColorDot({
    super.key,
    this.color,
    required this.label,
    required this.selected,
    required this.onTap,
  });

  final Color? color;
  final String label;
  final bool selected;
  final VoidCallback onTap;

  static const double _diameter = 26;

  /// The ring the chosen dot wears. Reserved on every dot and left
  /// transparent where it is not worn, so choosing one does not reflow the
  /// grid under the pointer.
  static const double _ringWidth = 2;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final target = tagTapTarget(Theme.of(context).platform);
    final fill = color;

    return Semantics(
      container: true,
      button: true,
      selected: selected,
      label: label,
      child: GestureDetector(
        onTap: onTap,
        behavior: HitTestBehavior.opaque,
        child: SizedBox.square(
          // The dot owns the platform's tap target: 48 dp for a finger,
          // 32 dp for a pointer. On a phone the grid grows taller rather
          // than the dots shrinking.
          dimension: target,
          child: Center(
            child: Container(
              padding: const EdgeInsets.all(2),
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                border: Border.all(
                  color: selected ? scheme.primary : Colors.transparent,
                  width: _ringWidth,
                ),
              ),
              child: Container(
                width: _diameter,
                height: _diameter,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: fill,
                  // A hairline keeps the palest shades visible on a light
                  // surface and the darkest on a dark one.
                  border: Border.all(color: scheme.outlineVariant),
                ),
                child: fill == null
                    ? Icon(Icons.add, size: 18, color: scheme.onSurfaceVariant)
                    : null,
              ),
            ),
          ),
        ),
      ),
    );
  }
}
