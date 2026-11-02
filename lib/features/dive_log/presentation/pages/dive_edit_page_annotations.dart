part of 'dive_edit_page.dart';

/// Annotations from the notes editor (#4109): the pin asks when the
/// selected words happened, the link lands in the notes at once, and the
/// annotation rows are written, refreshed or deleted when the dive is
/// saved, from whatever the saved notes still link. A part of the page, so
/// the page itself grows by one field and two call sites.
extension _AnnotationEditing on _DiveEditPageState {
  /// Answers the notes editor's pin: opens the time sheet for the selected
  /// words (asking for words too when nothing was selected) and records the
  /// annotation to write on save.
  Future<AnnotationRequestResult?> _requestAnnotation(
    String selectedWords,
  ) async {
    final maxSeconds = _gasSwitchMaxTimestamp;
    if (maxSeconds == null || maxSeconds <= 0) return null;
    final result = await showAnnotationTimeSheet(
      context,
      words: selectedWords.isEmpty ? null : selectedWords,
      profile: _existingDive?.profile ?? const <DiveProfilePoint>[],
      maxSeconds: maxSeconds,
      units: UnitFormatter(ref.read(settingsProvider)),
    );
    if (result == null || !mounted) return null;
    final id = const Uuid().v4();
    _pendingAnnotations = [
      ..._pendingAnnotations,
      PendingAnnotation(
        id: id,
        timestamp: result.seconds,
        depth: result.depthMeters,
      ),
    ];
    _markDirty();
    return (id: id, words: selectedWords.isEmpty ? result.words : null);
  }

  /// After the dive row is saved: creates the pending annotations the saved
  /// notes still link, deletes the rows whose link is gone, and refreshes
  /// the cached words of the rest.
  Future<void> _reconcileAnnotations(String? savedDiveId) async {
    if (savedDiveId == null || widget.isBulk) return;
    await ref
        .read(annotationRepositoryProvider)
        .reconcile(
          diveId: savedDiveId,
          notes: _notesController.text,
          create: _pendingAnnotations,
        );
    _pendingAnnotations = const [];
  }
}
