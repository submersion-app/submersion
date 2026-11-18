import 'package:flutter/material.dart';

import 'package:submersion/features/dive_sites/domain/entities/dive_site.dart';
import 'package:submersion/shared/widgets/markdown_notes/markdown_notes_field.dart';
import 'package:submersion/shared/widgets/record_editing/edit_field.dart';
import 'package:submersion/shared/widgets/record_editing/edit_session.dart';
import 'package:submersion/shared/widgets/record_editing/field_text_binding.dart';

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
  /// Keeps the text in step with the sitting both ways: what the diver
  /// types goes to the sitting, and a stored change to a value the diver
  /// has not touched comes back into the text.
  late FieldTextBinding<DiveSite, String> _binding = _bind();

  FieldTextBinding<DiveSite, String> _bind() => FieldTextBinding(
    session: widget.session,
    field: widget.field,
    format: (text) => text,
    // Any text is a value: blank is an empty description.
    parse: FieldValue<String>.new,
  );

  @override
  void didUpdateWidget(SiteMarkdownCardEditor oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.session == widget.session &&
        oldWidget.field == widget.field) {
      return;
    }
    _binding.dispose();
    _binding = _bind();
  }

  @override
  void dispose() {
    _binding.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final placeholder = widget.placeholder;
    return MarkdownNotesField(
      controller: _binding.controller,
      autofocus: true,
      decoration: placeholder == null
          ? null
          : InputDecoration(hintText: placeholder),
    );
  }
}
