import 'package:flutter/material.dart';

import 'package:submersion/l10n/l10n_extension.dart';
import 'package:submersion/shared/utils/color_hex.dart';
import 'package:submersion/shared/widgets/color_picker/hsv_color_controls.dart';

/// Opens the custom colour dialog on [initial] (issues #4384 and #4537).
/// Completes with the chosen colour as `#RRGGBB` in capitals, or null when
/// the diver cancels or dismisses it.
///
/// [preview] draws the colour being picked as the caller's screen will show
/// it (a tag chip, an equipment swatch). It is hidden from screen readers:
/// the code field below it already reads the colour out.
Future<String?> showCustomColorDialog(
  BuildContext context, {
  required Color initial,
  required String title,
  required Widget Function(Color color) preview,
}) {
  return showDialog<String>(
    context: context,
    builder: (_) =>
        _CustomColorDialog(initial: initial, title: title, preview: preview),
  );
}

class _CustomColorDialog extends StatefulWidget {
  const _CustomColorDialog({
    required this.initial,
    required this.title,
    required this.preview,
  });

  final Color initial;
  final String title;
  final Widget Function(Color color) preview;

  @override
  State<_CustomColorDialog> createState() => _CustomColorDialogState();
}

class _CustomColorDialogState extends State<_CustomColorDialog> {
  late HSVColor _hsv = HSVColor.fromColor(widget.initial.withValues(alpha: 1));
  late final TextEditingController _hex = TextEditingController(
    text: colorHexOf(widget.initial),
  );

  /// The code in the field, or null while it is not a valid one.
  late String? _code = colorHexOf(widget.initial);

  @override
  void dispose() {
    _hex.dispose();
    super.dispose();
  }

  /// A drag on the square or the slider: the field follows.
  void _fromControls(HSVColor hsv) {
    final code = colorHexOf(hsv.toColor());
    setState(() {
      _hsv = hsv;
      _code = code;
    });
    _hex.text = code;
  }

  /// A typed code: the square and slider follow. A grey has no hue of its
  /// own, so the slider stays where it was rather than jumping to red.
  void _fromField(String text) {
    final code = parseColorHexInput(text);
    setState(() {
      _code = code;
      if (code == null) return;
      final typed = HSVColor.fromColor(colorFromHex(code));
      _hsv = typed.saturation == 0 ? typed.withHue(_hsv.hue) : typed;
    });
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final code = _code;
    final shown = code != null ? colorFromHex(code) : _hsv.toColor();

    return AlertDialog(
      title: Text(widget.title),
      content: SizedBox(
        width: 280,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              ExcludeSemantics(child: widget.preview(shown)),
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
                key: const ValueKey('custom-color-hex'),
                controller: _hex,
                onChanged: _fromField,
                decoration: InputDecoration(
                  labelText: l10n.common_color_hexLabel,
                  errorText: code == null ? l10n.common_color_hexError : null,
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
          key: const ValueKey('custom-color-use'),
          onPressed: code == null ? null : () => Navigator.pop(context, code),
          child: Text(l10n.common_color_use),
        ),
      ],
    );
  }
}
