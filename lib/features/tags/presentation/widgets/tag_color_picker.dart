import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';

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

    Widget hueColumn(int hue) => Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        for (final entry in tagPalette.where((e) => e.hue == hue))
          paletteDot(entry),
      ],
    );

    final currentDot = current == null
        ? null
        : _ColorDot(
            key: const ValueKey('tag-color-current'),
            color: drawnTagColor(current),
            label: l10n.tags_color_current(current),
            selected: onCurrent,
            onTap: () => widget.onColorSelected(current),
          );
    final customDot = _ColorDot(
      key: const ValueKey('tag-color-custom'),
      label: l10n.tags_color_custom,
      selected: false,
      onTap: _pickCustom,
    );

    final geometry = _BandGeometry(
      slot: tagTapTarget(Theme.of(context).platform),
      lead: currentDot == null ? 0 : 1,
    );

    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _preview(),
        const SizedBox(height: 12),
        _BandIntrinsics(
          geometry: geometry,
          child: LayoutBuilder(
            builder: (context, constraints) {
              final slot = geometry.slot;
              final perBand = geometry.huesPerBand(constraints.maxWidth);
              final hues = tagLightShades.length;
              return Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                spacing: _gap,
                children: [
                  for (var start = 0; start < hues; start += perBand)
                    Row(
                      mainAxisSize: MainAxisSize.min,
                      crossAxisAlignment: CrossAxisAlignment.start,
                      spacing: _gap,
                      children: [
                        // The current colour leads the first band; later bands
                        // keep its slot empty so the hue columns line up.
                        if (currentDot != null)
                          start == 0 ? currentDot : SizedBox(width: slot),
                        for (var hue = start; hue < start + perBand; hue++)
                          hueColumn(hue),
                        if (start + perBand >= hues) customDot,
                      ],
                    ),
                ],
              );
            },
          ),
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

/// Space between dots, across and down.
const double _gap = 4;

/// The arithmetic of the dot grid: [slot] is a dot's square (the platform
/// tap target) and [lead] is 1 when a current-colour dot leads each band.
class _BandGeometry {
  const _BandGeometry({required this.slot, required this.lead});

  final double slot;
  final int lead;

  static const int _hues = 20;

  /// How many hue columns go in each band: the most of 10, 5, 4, 2 or 1
  /// (each divides the 20 hues, so every band is full) that fit beside the
  /// [lead] slot and the "+" dot. Ten across on a desktop dialog, fewer on a
  /// phone, and never a lopsided last band.
  int huesPerBand(double width) {
    if (!width.isFinite) return 10;
    final slots = ((width + _gap) / (slot + _gap)).floor();
    return const [
      10,
      5,
      4,
      2,
      1,
    ].firstWhere((n) => n + lead + 1 <= slots, orElse: () => 1);
  }

  /// The width of a band of [hues] columns with its lead and "+" slots.
  double widthFor(int hues) {
    final slots = hues + lead + 1;
    return slots * slot + (slots - 1) * _gap;
  }

  /// The height the grid takes at [width].
  double heightAt(double width) {
    final bands = _hues ~/ huesPerBand(width);
    return bands * 3 * slot + (bands - 1) * _gap;
  }
}

/// Answers intrinsic-size questions for the grid from [_BandGeometry].
///
/// AlertDialog sizes itself with IntrinsicWidth, and a LayoutBuilder cannot
/// answer an intrinsic size (it would have to run its builder speculatively),
/// so the question stops here: the grid would like ten hues across and can
/// shrink to one.
class _BandIntrinsics extends SingleChildRenderObjectWidget {
  const _BandIntrinsics({required this.geometry, required super.child});

  final _BandGeometry geometry;

  @override
  RenderObject createRenderObject(BuildContext context) =>
      _RenderBandIntrinsics(geometry);

  @override
  void updateRenderObject(
    BuildContext context,
    _RenderBandIntrinsics renderObject,
  ) => renderObject.geometry = geometry;
}

class _RenderBandIntrinsics extends RenderProxyBox {
  _RenderBandIntrinsics(this._geometry);

  _BandGeometry _geometry;

  set geometry(_BandGeometry value) {
    if (value.slot == _geometry.slot && value.lead == _geometry.lead) return;
    _geometry = value;
    markNeedsLayout();
  }

  @override
  double computeMinIntrinsicWidth(double height) => _geometry.widthFor(1);

  @override
  double computeMaxIntrinsicWidth(double height) => _geometry.widthFor(10);

  @override
  double computeMinIntrinsicHeight(double width) => _geometry.heightAt(width);

  @override
  double computeMaxIntrinsicHeight(double width) => _geometry.heightAt(width);
}
