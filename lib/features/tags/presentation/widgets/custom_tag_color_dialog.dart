import 'package:flutter/material.dart';

import 'package:submersion/features/tags/domain/entities/tag.dart';
import 'package:submersion/features/tags/domain/tag_palette.dart';
import 'package:submersion/features/tags/presentation/widgets/hsv_color_controls.dart';
import 'package:submersion/features/tags/presentation/widgets/tag_chip.dart';
import 'package:submersion/l10n/l10n_extension.dart';

/// Opens the custom tag colour dialog on [initial] (issue #4384). Completes
/// with the chosen colour as `#RRGGBB` in capitals, or null when the diver
/// cancels or dismisses it. [name] labels the preview chip.
Future<String?> showCustomTagColorDialog(
  BuildContext context, {
  required Color initial,
  required String name,
}) {
  return showDialog<String>(
    context: context,
    builder: (_) => _CustomTagColorDialog(initial: initial, name: name),
  );
}

class _CustomTagColorDialog extends StatefulWidget {
  const _CustomTagColorDialog({required this.initial, required this.name});

  final Color initial;
  final String name;

  @override
  State<_CustomTagColorDialog> createState() => _CustomTagColorDialogState();
}

class _CustomTagColorDialogState extends State<_CustomTagColorDialog> {
  late HSVColor _hsv = HSVColor.fromColor(widget.initial.withValues(alpha: 1));
  late final TextEditingController _hex = TextEditingController(
    text: tagHexOf(widget.initial),
  );

  /// The code in the field, or null while it is not a valid one.
  late String? _code = tagHexOf(widget.initial);

  @override
  void dispose() {
    _hex.dispose();
    super.dispose();
  }

  /// A drag on the square or the slider: the field follows.
  void _fromControls(HSVColor hsv) {
    final code = tagHexOf(hsv.toColor());
    setState(() {
      _hsv = hsv;
      _code = code;
    });
    _hex.text = code;
  }

  /// A typed code: the square and slider follow. A grey has no hue of its
  /// own, so the slider stays where it was rather than jumping to red.
  void _fromField(String text) {
    final code = parseTagHexInput(text);
    setState(() {
      _code = code;
      if (code == null) return;
      final typed = HSVColor.fromColor(TagColors.fromHex(code));
      _hsv = typed.saturation == 0 ? typed.withHue(_hsv.hue) : typed;
    });
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final code = _code;
    final preview = code != null ? TagColors.fromHex(code) : _hsv.toColor();

    return AlertDialog(
      title: Text(l10n.tags_color_custom),
      content: SizedBox(
        width: 280,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              ExcludeSemantics(
                child: TagChip.unsaved(name: widget.name, color: preview),
              ),
              const SizedBox(height: 16),
              SizedBox(
                height: 160,
                child: SaturationValueSquare(
                  color: _hsv,
                  onChanged: _fromControls,
                ),
              ),
              const SizedBox(height: 12),
              HueSlider(color: _hsv, onChanged: _fromControls),
              const SizedBox(height: 16),
              TextField(
                key: const ValueKey('tag-color-hex'),
                controller: _hex,
                onChanged: _fromField,
                decoration: InputDecoration(
                  labelText: l10n.tags_color_hexLabel,
                  errorText: code == null ? l10n.tags_color_hexError : null,
                  errorMaxLines: 2,
                  border: const OutlineInputBorder(),
                ),
              ),
            ],
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: Text(l10n.common_action_cancel),
        ),
        TextButton(
          key: const ValueKey('tag-color-use'),
          onPressed: code == null ? null : () => Navigator.pop(context, code),
          child: Text(l10n.tags_color_use),
        ),
      ],
    );
  }
}
