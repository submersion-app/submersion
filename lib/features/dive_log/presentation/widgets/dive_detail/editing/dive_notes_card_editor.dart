import 'package:flutter/material.dart';
import 'package:uuid/uuid.dart';

import 'package:submersion/core/providers/provider.dart';
import 'package:submersion/shared/widgets/markdown_notes/markdown_editing.dart';
import 'package:submersion/features/dive_log/data/repositories/annotation_repository.dart';
import 'package:submersion/features/dive_log/presentation/widgets/dive_detail/editing/dive_annotations_sitting.dart';
import 'package:submersion/features/dive_log/presentation/widgets/edit_sections/annotation_time_sheet.dart';
import 'package:submersion/core/utils/unit_formatter.dart';

import 'package:submersion/features/dive_log/domain/entities/dive.dart';
import 'package:submersion/features/dive_log/presentation/widgets/dive_detail/editing/dive_edit_cards.dart';
import 'package:submersion/l10n/l10n_extension.dart';
import 'package:submersion/shared/widgets/markdown_notes/markdown_notes_field.dart';
import 'package:submersion/shared/widgets/record_editing/edit_session.dart';
import 'package:submersion/shared/widgets/record_editing/text_keeping_caret.dart';

/// The Notes card's editor: the dive's notes as Markdown, written through
/// to the sitting as the diver types.
class DiveNotesCardEditor extends ConsumerStatefulWidget {
  const DiveNotesCardEditor({super.key, required this.session});

  final EditSession<Dive> session;

  @override
  ConsumerState<DiveNotesCardEditor> createState() =>
      _DiveNotesCardEditorState();
}

class _DiveNotesCardEditorState extends ConsumerState<DiveNotesCardEditor> {
  late final TextEditingController _controller = TextEditingController(
    text: widget.session.valueOf(diveNotesField),
  );

  @override
  void initState() {
    super.initState();
    widget.session.addListener(_followSession);
    _redrawAfter(annotationsRead(widget.session));
  }

  @override
  void didUpdateWidget(DiveNotesCardEditor oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.session == widget.session) return;
    oldWidget.session.removeListener(_followSession);
    widget.session.addListener(_followSession);
    _followSession();
    _redrawAfter(annotationsRead(widget.session));
  }

  /// Offers annotating once the sitting holds the annotations, and checks
  /// the links against them: keeping them does not notify the sitting's
  /// listeners.
  void _redrawAfter(Future<void> read) => read.then((_) {
    if (!mounted) return;
    _followLinks();
    setState(() {});
  });

  /// Keeps the field showing the sitting's value. While the diver types the
  /// two already agree; they differ only when the stored dive changed
  /// underneath notes the diver has not touched.
  void _followSession() {
    _followLinks();
    final notes = widget.session.valueOf(diveNotesField);
    if (_controller.text == notes) return;
    // The caret stays where it was, or at the end of a shorter note.
    _controller.replaceTextKeepingCaret(notes);
  }

  /// Whether the notes break no annotation link (#4815): while one is
  /// broken the field says so, and Save is held by the card's check.
  late bool _linksIntact = annotationLinksIntact(widget.session);

  /// The notes, working and stored, and the annotations the sitting holds
  /// (kept anew on each change), as [_linksIntact] last answered for them,
  /// so a change on another card does not read the notes again.
  (String, String, SittingAnnotations?)? _linksCheckedFor;

  /// Redraws only when the answer changes, not on every keystroke.
  void _followLinks() {
    final session = widget.session;
    if (session.isDisposed) return;
    final notes = (
      session.valueOf(diveNotesField),
      session.stored.notes,
      sittingAnnotations(session),
    );
    if (notes == _linksCheckedFor) return;
    _linksCheckedFor = notes;
    final intact = annotationLinksIntact(session);
    if (intact == _linksIntact || !mounted) return;
    setState(() => _linksIntact = intact);
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
      decoration: _linksIntact
          ? null
          : InputDecoration(
              errorText: context.l10n.diveLog_annotation_brokenLink,
              errorMaxLines: 4,
            ),
      onChanged: (notes) => widget.session.set(diveNotesField, notes),
      // Only while the sitting holds the annotations: a pin asked for
      // before they are read, or after the read failed, would go nowhere.
      onAnnotate: sittingAnnotations(widget.session) == null ? null : _annotate,
    );
  }

  /// The notes editor's pin (#4109), as the dive form answers it: asks when
  /// the selected words happened (and for words when nothing was selected),
  /// and holds the annotation in the sitting. The editor writes its link
  /// into the notes; the row is written at Save (issue #4527, plan 6).
  Future<AnnotationRequestResult?> _annotate(String selectedWords) async {
    final session = widget.session;
    if (sittingAnnotations(session) == null) return null;
    final result = await showAnnotationTimeSheet(
      context,
      words: selectedWords.isEmpty ? null : selectedWords,
      profile: session.stored.profile,
      maxSeconds: annotationTimeLimits(session).max,
      units: ref.read(unitFormatterProvider),
    );
    if (result == null || !mounted) return null;
    if (session.isDisposed || session.isFrozen) return null;
    final id = const Uuid().v4();
    holdNotesPin(
      session,
      PendingAnnotation(
        id: id,
        timestamp: result.seconds,
        depth: result.depthMeters,
      ),
    );
    return (id: id, words: selectedWords.isEmpty ? result.words : null);
  }
}
