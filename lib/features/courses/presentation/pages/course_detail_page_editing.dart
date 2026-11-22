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
    // Read now, so the Requirements card shows the sitting's rows once they
    // change.
    courseRequirementsList.load(session);
    courseCertificationsList.load(session);
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

  /// Whether the optional card [id] has nothing to show in the sitting. The
  /// earned certifications are the sitting's list, not the course's values.
  bool _isEmptyInSitting(CourseCardId id, Course working) {
    if (id == CourseCardId.earnedCertifications) {
      final certifications = _certificationsInSitting(
        ref.read(certificationsForCourseProvider(hostRecordId)).value,
      );
      return certifications != null && certifications.isEmpty;
    }
    return courseEditCards[id]!.isEmpty(working);
  }

  /// The certifications the course earned as the sitting has them: its own
  /// list once read, else [stored]; none known while neither has been read.
  List<Certification>? _certificationsInSitting(List<Certification>? stored) {
    final session = maybeEditController?.session;
    final held = session == null
        ? null
        : courseCertificationsList.current(session);
    return held ?? stored;
  }

  /// Whether [id] is shown though empty: open or brought in from the strip
  /// during the sitting.
  bool _showsWhileEmpty(CourseCardId id) {
    final controller = maybeEditController;
    if (controller == null || !controller.isUnlocked) return false;
    return controller.openCardIds.contains(id.name) ||
        controller.addedCardIds.contains(id.name);
  }

  /// [child] as the card [id], framed for editing in place; [topGap] is the
  /// gap a card that places its own puts above itself.
  Widget _framed(CourseCardId id, Widget child, {double topGap = 0}) =>
      RecordCardFrame<Course>(
        card: courseEditCards[id]!,
        topGap: topGap,
        child: child,
      );
}

/// A section's title row: its icon and title, and for a card the diver
/// edits ([editing]) its pencil. A calculated card has none.
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
