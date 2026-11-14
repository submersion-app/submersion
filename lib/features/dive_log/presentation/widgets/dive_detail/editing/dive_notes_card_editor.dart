import 'package:flutter/material.dart';

import 'package:submersion/features/dive_log/domain/entities/dive.dart';
import 'package:submersion/features/dive_log/presentation/widgets/dive_detail/editing/dive_edit_cards.dart';
import 'package:submersion/shared/widgets/markdown_notes/markdown_notes_field.dart';
import 'package:submersion/shared/widgets/record_editing/edit_session.dart';

/// The Notes card's editor: the dive's notes as Markdown, written through
/// to the sitting as the diver types.
class DiveNotesCardEditor extends StatefulWidget {
  const DiveNotesCardEditor({super.key, required this.session});

  final EditSession<Dive> session;

  @override
  State<DiveNotesCardEditor> createState() => _DiveNotesCardEditorState();
}

class _DiveNotesCardEditorState extends State<DiveNotesCardEditor> {
  late final TextEditingController _controller = TextEditingController(
    text: widget.session.valueOf(diveNotesField),
  );

  @override
  void initState() {
    super.initState();
    widget.session.addListener(_followSession);
  }

  @override
  void didUpdateWidget(DiveNotesCardEditor oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.session == widget.session) return;
    oldWidget.session.removeListener(_followSession);
    widget.session.addListener(_followSession);
    _followSession();
  }

  /// Keeps the field showing the sitting's value. While the diver types the
  /// two already agree; they differ only when the stored dive changed
  /// underneath notes the diver has not touched.
  void _followSession() {
    final notes = widget.session.valueOf(diveNotesField);
    if (_controller.text != notes) _controller.text = notes;
  }

  @override
  void dispose() {
    widget.session.removeListener(_followSession);
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return MarkdownNotesField(
      controller: _controller,
      autofocus: true,
      onChanged: (notes) => widget.session.set(diveNotesField, notes),
    );
  }
}
