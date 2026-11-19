part of 'course_detail_page.dart';

/// The course page's use of the shared editing host (issue #4527, phase 3):
/// what is its own about saving, reading back, its cards and the frames its
/// sections sit in.
mixin _CourseDetailPageEditing
    on
        ConsumerState<CourseDetailPage>,
        RecordEditHost<CourseDetailPage, Course>,
        RecordOpenUnlocked<CourseDetailPage, Course> {
  @override
  String get hostRecordId => widget.courseId;

  @override
  String recordIdOf(Course record) => record.id;

  @override
  bool get hostsEditing => widget.unlockEditing;

  @override
  bool openUnlockedOf(CourseDetailPage widget) => widget.openUnlocked;

  @override
  VoidCallback? get onOpenedSittingEnded => widget.onSittingEnded;

  @override
  void onEditChanged() {
    noteOpenedSittingEnded();
    super.onEditChanged();
  }

  @override
  Iterable<EditCard<Course>> get hostEditCards => courseEditCards.values;

  @override
  Course? get storedForUnlock =>
      ref.read(courseByIdProvider(widget.courseId)).value;

  @override
  String editingTitle(Course record) =>
      context.l10n.recordEdit_editingTitle(record.name);

  /// The documents attached and detached in the sitting are filed under the
  /// course.
  @override
  void onSittingStart(
    EditSession<Course> session,
    ProviderContainer container,
  ) {
    holdDocumentLinks(
      session,
      container.read,
      owner: DocumentOwner(DocumentOwnerKind.course, session.stored.id),
      cardId: CourseCardId.documents.name,
    );
  }

  /// Writes the sitting through the course's save service: its changed
  /// values and its held writes, in one transaction and one History entry.
  @override
  Future<void> saveSitting(EditSession<Course> session) async {
    // Read before the write: the page can be gone by the time it is done.
    final service = ref.read(courseEditSaveServiceProvider);
    final result = await service.save(
      // The course the sitting was opened on, whatever the page shows by
      // the time the write is asked for.
      courseId: session.stored.id,
      apply: session.applyTo,
      changedCardIds: session.changedCardIds,
      alsoWrite: session.hasHeldWrites ? session.runHeldWrites : null,
      alsoWriteIsAChange: session.hasHeldChanges,
    );
    justSavedRecord = result?.after ?? session.working;
  }

  @override
  Future<Course?> rereadStored(ProviderContainer container, Course stored) {
    container.invalidate(courseByIdProvider(stored.id));
    return container.read(courseByIdProvider(stored.id).future);
  }

  /// The cards the page leaves out while they are empty.
  @override
  List<AddStripEntry> addStripEntries(Course working) {
    final session = maybeEditController?.session;
    if (session == null) return const [];
    return [
      for (final id in courseOptionalCards)
        if (_isEmptyInSitting(id, working) && !_showsWhileEmpty(id))
          AddStripEntry(
            cardId: id.name,
            label: courseEditCards[id]!.title(context),
            changed: session.changedCardIds.contains(id.name),
          ),
    ];
  }

  /// Whether the optional card [id] has nothing to show in the sitting.
  bool _isEmptyInSitting(CourseCardId id, Course working) =>
      courseEditCards[id]!.isEmpty(working);

  /// Whether [id] is shown though empty: open or brought in from the strip
  /// during the sitting.
  bool _showsWhileEmpty(CourseCardId id) {
    final controller = maybeEditController;
    if (controller == null || !controller.isUnlocked) return false;
    return controller.openCardIds.contains(id.name) ||
        controller.addedCardIds.contains(id.name);
  }

  /// [child] as the card [id], framed for editing in place.
  Widget _framed(CourseCardId id, Widget child) =>
      RecordCardFrame<Course>(card: courseEditCards[id]!, child: child);
}

/// A section's title row: its icon and title, and the card's pencil where
/// the page edits in place ([editing]).
Widget _sectionHeader(
  BuildContext context,
  String title,
  IconData icon, {
  bool editing = false,
}) {
  final colorScheme = Theme.of(context).colorScheme;
  return Row(
    children: [
      Icon(icon, size: 20, color: colorScheme.primary),
      const SizedBox(width: 8),
      Expanded(
        child: Text(
          title,
          style: Theme.of(
            context,
          ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w600),
        ),
      ),
      if (editing) RecordCardPencil(cardTitle: title),
    ],
  );
}

/// [child], a section the page calculates, faded and labelled
/// "Calculated" while unlocked.
Widget _calculated(Widget child) => RecordCardFade<Course>(
  reason: RecordCardFadeReason.calculated,
  child: child,
);
