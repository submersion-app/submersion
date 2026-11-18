import 'package:flutter/material.dart';

import 'package:submersion/features/dive_sites/domain/entities/dive_site.dart';
import 'package:submersion/shared/widgets/markdown_notes/markdown_notes_field.dart';
import 'package:submersion/shared/widgets/record_editing/edit_field.dart';
import 'package:submersion/shared/widgets/record_editing/edit_session.dart';
import 'package:submersion/shared/widgets/record_editing/text_keeping_caret.dart';

/// The editor of a site card holding one Markdown field (Description,
/// Notes): the field as Markdown, written through to the sitting as the
/// diver types (issue #4527, phase 2).
class SiteMarkdownCardEditor extends StatefulWidget {
  const SiteMarkdownCardEditor({
    super.key,
    required this.session,
    required this.field,
    this.placeholder,
  });

  final EditSession<DiveSite> session;
  final EditField<DiveSite, String> field;

  /// Shown while the field is empty.
  final String? placeholder;

  @override
  State<SiteMarkdownCardEditor> createState() => _SiteMarkdownCardEditorState();
}

class _SiteMarkdownCardEditorState extends State<SiteMarkdownCardEditor> {
  late final TextEditingController _controller = TextEditingController(
    text: widget.session.valueOf(widget.field),
  );

  @override
  void initState() {
    super.initState();
    widget.session.addListener(_followSession);
  }

  @override
  void didUpdateWidget(SiteMarkdownCardEditor oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.session == widget.session &&
        oldWidget.field == widget.field) {
      return;
    }
    oldWidget.session.removeListener(_followSession);
    widget.session.addListener(_followSession);
    _followSession();
  }

  /// Keeps the field showing the sitting's value. While the diver types the
  /// two already agree; they differ only when the stored site changed
  /// underneath a value the diver has not touched.
  void _followSession() {
    final value = widget.session.valueOf(widget.field);
    if (_controller.text == value) return;
    // The caret stays where it was, or at the end of a shorter text.
    _controller.replaceTextKeepingCaret(value);
  }

  @override
  void dispose() {
    widget.session.removeListener(_followSession);
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final placeholder = widget.placeholder;
    return MarkdownNotesField(
      controller: _controller,
      autofocus: true,
      decoration: placeholder == null
          ? null
          : InputDecoration(hintText: placeholder),
      onChanged: (text) => widget.session.set(widget.field, text),
    );
  }
}
