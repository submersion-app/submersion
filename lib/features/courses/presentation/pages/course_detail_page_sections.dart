part of 'course_detail_page.dart';

/// The course page's read sections, each a card that the editing host
/// frames (issue #4527, phase 3).
extension _CourseDetailSections on _CourseDetailContent {
  Widget _buildStatusCard(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final statusAccent = courseStatusAccent(
      colorScheme,
      completed: course.isCompleted,
    );
    final statusLabel = course.isCompleted
        ? context.l10n.courses_status_completed
        : context.l10n.courses_status_inProgress;
    final durationLabel = course.durationDays != null
        ? context.l10n.courses_status_durationDays(course.durationDays!)
        : context.l10n.courses_status_daysSinceStart(course.daysSinceStart);

    return Semantics(
      label: context.l10n.courses_status_semanticLabel(
        statusLabel,
        durationLabel,
      ),
      child: Card(
        color: courseStatusSurface(colorScheme, completed: course.isCompleted),
        // The card colour above is already blended onto the theme surface;
        // letting the elevation tint composite on top would undo that.
        surfaceTintColor: Colors.transparent,
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            children: [
              Icon(
                course.isCompleted ? Icons.check_circle : Icons.pending,
                size: 40,
                color: statusAccent,
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      statusLabel,
                      style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.w600,
                        color: statusAccent,
                      ),
                    ),
                    Text(
                      durationLabel,
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: colorScheme.onSurfaceVariant,
                      ),
                    ),
                  ],
                ),
              ),
              RecordCardPencil(
                cardTitle: CourseCardId.status.localizedDisplayName(
                  context.l10n,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildDetailsCard(BuildContext context, UnitFormatter formatter) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: DetailRowGroup(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _sectionHeader(
                context,
                context.l10n.courses_section_details,
                Icons.school,
                editing: true,
              ),
              const SizedBox(height: 12),
              _buildDetailRow(
                context,
                context.l10n.courses_label_agency,
                context.certificationCatalog
                    .agency(course.agency)
                    .localizedName(context.l10n),
                Icons.business,
              ),
              _buildDetailRow(
                context,
                context.l10n.courses_label_startDate,
                formatter.formatDate(course.startDate),
                Icons.calendar_today,
              ),
              if (course.completionDate != null)
                _buildDetailRow(
                  context,
                  context.l10n.courses_label_completed,
                  formatter.formatDate(course.completionDate!),
                  Icons.check_circle,
                ),
              if (course.location != null)
                _buildDetailRow(
                  context,
                  context.l10n.courses_label_location,
                  course.location!,
                  Icons.place,
                ),
            ],
          ),
        ),
      ),
    );
  }

  /// Whether the Instructor card is on the page: any of its values shows
  /// it (issue #4527).
  bool _showsInstructor() =>
      course.instructorName != null ||
      course.instructorNumber != null ||
      course.instructorId != null ||
      _shows(CourseCardId.instructor);

  Widget _buildInstructorCard(BuildContext context, WidgetRef ref) {
    final instructorId = course.instructorId;
    // With no name written, the buddy picked names the instructor.
    final name =
        course.instructorName ??
        (instructorId != null
            ? ref.watch(buddyByIdProvider(instructorId)).value?.name
            : null);
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: DetailRowGroup(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _sectionHeader(
                context,
                context.l10n.courses_section_instructor,
                Icons.person,
                editing: true,
              ),
              const SizedBox(height: 12),
              if (name != null)
                _buildDetailRow(
                  context,
                  context.l10n.courses_label_name,
                  name,
                  Icons.badge,
                ),
              if (course.instructorNumber != null)
                _buildDetailRow(
                  context,
                  context.l10n.courses_label_instructorNumber,
                  course.instructorNumber!,
                  Icons.numbers,
                  copyable: true,
                ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildTrainingDivesCard(
    BuildContext context,
    AsyncValue<List<Dive>> divesAsync,
    UnitFormatter formatter,
  ) {
    final colorScheme = Theme.of(context).colorScheme;
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _sectionHeader(
              context,
              context.l10n.courses_section_trainingDives,
              Icons.scuba_diving,
            ),
            const SizedBox(height: 12),
            divesAsync.when(
              data: (dives) {
                if (dives.isEmpty) {
                  return Text(
                    context.l10n.courses_detail_noTrainingDives,
                    style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                      color: colorScheme.onSurfaceVariant,
                      fontStyle: FontStyle.italic,
                    ),
                  );
                }
                return Column(
                  children: dives.map((dive) {
                    return ListTile(
                      leading: CircleAvatar(
                        backgroundColor: colorScheme.primary.withValues(
                          alpha: 0.15,
                        ),
                        child: Text(
                          '${dive.diveNumber ?? '-'}',
                          style: TextStyle(color: colorScheme.primary),
                        ),
                      ),
                      title: Text(
                        dive.site?.name ??
                            context.l10n.diveLog_listPage_unknownSite,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      subtitle: Text(formatter.formatDate(dive.dateTime)),
                      trailing: Icon(
                        Icons.chevron_right,
                        color: colorScheme.onSurfaceVariant,
                      ),
                      onTap: () => context.push('/dives/${dive.id}'),
                    );
                  }).toList(),
                );
              },
              loading: () => const Center(
                child: CircularProgressIndicator(strokeWidth: 2),
              ),
              error: (error, stack) => Text(
                context.l10n.courses_error_loadingDives,
                style: TextStyle(color: colorScheme.error),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildNotesCard(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _sectionHeader(
              context,
              context.l10n.courses_section_notes,
              Icons.notes,
              editing: true,
            ),
            const SizedBox(height: 12),
            MarkdownNotesView(course.notes),
          ],
        ),
      ),
    );
  }

  Widget _buildDetailRow(
    BuildContext context,
    String label,
    String value,
    IconData icon, {
    bool copyable = false,
  }) {
    final colorScheme = Theme.of(context).colorScheme;
    final row = DetailRow.text(
      icon: icon,
      iconSize: 16,
      iconGap: 8,
      iconColor: colorScheme.onSurfaceVariant,
      label: label,
      value: value,
      valueStyle: Theme.of(context).textTheme.bodyMedium,
      padding: const EdgeInsets.symmetric(vertical: 4),
      copyable: copyable,
    );
    // A copyable row reads as one node by itself, beside its copy button.
    if (copyable && DetailRow.canCopy(value)) return row;

    return Semantics(label: '$label: $value', child: row);
  }

  Widget _buildCertificationSection(BuildContext context, WidgetRef ref) {
    final session = host.maybeEditController?.session;
    if (session == null) return _certificationCard(context, ref);
    // What the sitting holds is drawn as it changes, and only then: not on
    // every keystroke in another card.
    return ListenableBuilder(
      listenable: courseCertificationsList.changes(session),
      builder: (context, _) => _certificationCard(context, ref),
    );
  }

  Widget _certificationCard(BuildContext context, WidgetRef ref) {
    final certsAsync = ref.watch(certificationsForCourseProvider(course.id));
    // The retained value, so a reload after a link change keeps the rows on
    // screen; nothing on the very first load, since an empty course shows no
    // section at all. In a sitting, the sitting's list once it is read.
    final certs = host._certificationsInSitting(certsAsync.value);
    final failed = certs == null && certsAsync.hasError;
    final showsEmpty = _shows(CourseCardId.earnedCertifications);
    if (!failed && (certs == null || certs.isEmpty) && !showsEmpty) {
      return const SizedBox.shrink();
    }
    final colorScheme = Theme.of(context).colorScheme;

    return Column(
      children: [
        _framed(
          CourseCardId.earnedCertifications,
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _sectionHeader(
                    context,
                    context.l10n.courses_section_earnedCertifications,
                    Icons.card_membership,
                    editing: true,
                  ),
                  const SizedBox(height: 12),
                  if (failed)
                    Text(
                      context.l10n.courses_error_loadingCertification,
                      style: TextStyle(color: colorScheme.error),
                    )
                  else
                    for (final cert in certs ?? const <Certification>[])
                      _buildCertificationRow(context, cert, colorScheme),
                ],
              ),
            ),
          ),
        ),
        const SizedBox(height: 16),
      ],
    );
  }

  Widget _buildCertificationRow(
    BuildContext context,
    Certification cert,
    ColorScheme colorScheme,
  ) {
    final agency = context.certificationCatalog
        .agency(cert.agency)
        .localizedName(context.l10n);
    final card = cert.cardNumber;
    return ListTile(
      // Keyed so a row is never reused for another certification: the card
      // photo keeps its last frame while new bytes decode.
      key: ValueKey(cert.id),
      contentPadding: EdgeInsets.zero,
      leading: CourseCertificationThumbnail(
        certification: cert,
        agencyName: agency,
      ),
      // Not cert.name: a certification with no custom title stores an empty
      // name and is titled by its level (#3436).
      title: Text(
        certificationTitleL10n(
          cert,
          context.l10n,
          catalog: context.certificationCatalog,
        ),
      ),
      subtitle: Text(
        card != null && card.isNotEmpty ? '$agency - $card' : agency,
      ),
      trailing: Icon(Icons.chevron_right, color: colorScheme.onSurfaceVariant),
      onTap: () => context.push('/certifications/${cert.id}'),
    );
  }
}
