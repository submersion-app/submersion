import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'package:submersion/shared/widgets/markdown_notes/markdown_editing.dart';
import 'package:submersion/shared/widgets/markdown_notes/markdown_notes_toolbar.dart';
import 'package:submersion/shared/widgets/markdown_notes/markdown_notes_view.dart';

/// The shared editor for every Markdown notes field (#3683): a plain
/// multi-line text field showing the Markdown as typed, a formatting bar
/// above it, and a Preview toggle that swaps the field for the formatted
/// note at the same height.
///
/// It is a [TextFormField] underneath, so it takes part in a [Form]; while
/// previewing, the field stays mounted (offstage) so validation still sees
/// it.
class MarkdownNotesField extends StatefulWidget {
  const MarkdownNotesField({
    super.key,
    required this.controller,
    this.focusNode,
    this.decoration,
    this.maxLines = 5,
    this.minLines,
    this.maxLength,
    this.autofocus = false,
    this.validator,
    this.onChanged,
    this.textCapitalization = TextCapitalization.sentences,
    this.style,
    this.onPreviewChanged,
  });

  final TextEditingController controller;
  final FocusNode? focusNode;
  final InputDecoration? decoration;
  final int maxLines;
  final int? minLines;
  final int? maxLength;
  final bool autofocus;
  final FormFieldValidator<String>? validator;
  final ValueChanged<String>? onChanged;
  final TextCapitalization textCapitalization;
  final TextStyle? style;

  /// Told when the Preview toggle changes, so a host that ends editing on
  /// focus loss (a collapsing form row) can stay open while previewing.
  final ValueChanged<bool>? onPreviewChanged;

  @override
  State<MarkdownNotesField> createState() => _MarkdownNotesFieldState();
}

class _MarkdownNotesFieldState extends State<MarkdownNotesField> {
  final _fieldKey = GlobalKey();
  FocusNode? _ownFocusNode;
  bool _previewing = false;
  double? _previewHeight;

  FocusNode get _focusNode =>
      widget.focusNode ?? (_ownFocusNode ??= FocusNode());

  @override
  void dispose() {
    _ownFocusNode?.dispose();
    super.dispose();
  }

  void _apply(TextEditingValue Function(TextEditingValue) edit) {
    if (_previewing) return;
    final next = edit(widget.controller.value);
    if (next == widget.controller.value) return;
    // The length limiter only sees typing; a toolbar edit that would grow
    // the notes past the limit is refused rather than saved over it. One
    // that shortens notes already over it (removing marks) still applies.
    final limit = widget.maxLength;
    final length = next.text.characters.length;
    if (limit != null &&
        length > limit &&
        length > widget.controller.text.characters.length) {
      return;
    }
    widget.controller.value = next;
    widget.onChanged?.call(next.text);
  }

  void _setPreview(bool on) {
    if (on == _previewing) return;
    final selection = widget.controller.selection;
    // Told first, so a host that rests on focus loss knows before the
    // unfocus below reaches it.
    widget.onPreviewChanged?.call(on);
    setState(() {
      _previewing = on;
      _previewHeight = on ? _fieldKey.currentContext?.size?.height : null;
    });
    if (on) {
      _focusNode.unfocus();
    } else {
      // After the rebuild: until then the field is still out of focus
      // traversal, and a focus request would be ignored. Focus can move the
      // caret, so the diver's selection is put back after it.
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) return;
        _focusNode.requestFocus();
        if (selection.isValid) widget.controller.selection = selection;
      });
    }
  }

  bool get _apple =>
      defaultTargetPlatform == TargetPlatform.macOS ||
      defaultTargetPlatform == TargetPlatform.iOS;

  void _bold() => _apply((v) => toggleInlineMark(v, '**'));
  void _italic() => _apply((v) => toggleInlineMark(v, '*'));

  @override
  Widget build(BuildContext context) {
    final field = CallbackShortcuts(
      bindings: {
        SingleActivator(
          LogicalKeyboardKey.keyB,
          meta: _apple,
          control: !_apple,
        ): _bold,
        SingleActivator(
          LogicalKeyboardKey.keyI,
          meta: _apple,
          control: !_apple,
        ): _italic,
      },
      child: TextFormField(
        key: _fieldKey,
        controller: widget.controller,
        focusNode: _focusNode,
        autofocus: widget.autofocus,
        maxLines: widget.maxLines,
        minLines: widget.minLines,
        maxLength: widget.maxLength,
        keyboardType: TextInputType.multiline,
        textCapitalization: widget.textCapitalization,
        inputFormatters: [NotesListContinuationFormatter()],
        validator: widget.validator,
        onChanged: widget.onChanged,
        style: widget.style,
        decoration: widget.decoration ?? const InputDecoration(),
      ),
    );

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      mainAxisSize: MainAxisSize.min,
      children: [
        MarkdownNotesToolbar(
          previewing: _previewing,
          onHeading: () =>
              _apply((v) => toggleLinePrefix(v, NotesLinePrefix.heading)),
          onBold: _bold,
          onItalic: _italic,
          onBulletList: () =>
              _apply((v) => toggleLinePrefix(v, NotesLinePrefix.bullet)),
          onNumberedList: () =>
              _apply((v) => toggleLinePrefix(v, NotesLinePrefix.numbered)),
          onPreviewChanged: _setPreview,
        ),
        if (_previewing) ...[
          SizedBox(
            key: const ValueKey('markdownNotesPreview'),
            height: _previewHeight,
            // The field's own decoration (label, icon, outline) stays around
            // the preview, so the diver can still tell which notes these are.
            child: InputDecorator(
              decoration: (widget.decoration ?? const InputDecoration())
                  .applyDefaults(Theme.of(context).inputDecorationTheme),
              expands: _previewHeight != null,
              child: SingleChildScrollView(
                // Follows the notes, so a change made while previewing (a
                // merge cycle) shows at once.
                child: ValueListenableBuilder<TextEditingValue>(
                  valueListenable: widget.controller,
                  builder: (context, value, _) =>
                      MarkdownNotesView(value.text, style: widget.style),
                ),
              ),
            ),
          ),
          // Mounted but hidden, so a Form still validates the notes.
          // Out of focus traversal too, so Tab cannot type into it unseen.
          Offstage(
            child: ExcludeFocus(
              child: TickerMode(enabled: false, child: field),
            ),
          ),
        ] else
          field,
      ],
    );
  }
}
