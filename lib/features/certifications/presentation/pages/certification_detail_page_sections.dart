part of 'certification_detail_page.dart';

/// The certification page's menu and its training course section.
extension _CertificationDetailSections on _CertificationDetailContent {
  /// The page's menu: History and Delete.
  /// Nothing acts on a certification not yet created (plan 11, call 3).
  Widget _menu(BuildContext context, WidgetRef ref, {bool compact = false}) =>
      _creating
      ? const SizedBox.shrink()
      : PopupMenuButton<String>(
          icon: compact ? const Icon(Icons.more_vert, size: 20) : null,
          tooltip: context.l10n.certifications_detail_tooltip_moreOptions,
          onSelected: (value) {
            if (value == 'delete') _requestDelete(context, ref);
          },
          itemBuilder: (context) => [
            changeLogHistoryMenuItem(
              context,
              rootTable: 'certifications',
              rootId: certification.id,
            ),
            // Delete is a whole-record operation, under the lock.
            ...recordOperationMenuCaption<String>(context, host.editController),
            PopupMenuItem(
              value: 'delete',
              enabled: recordOperationsAvailable(host.editController),
              child: Row(
                children: [
                  Icon(
                    Icons.delete,
                    color: Colors.red,
                    size: compact ? 20 : null,
                  ),
                  const SizedBox(width: 8),
                  Text(
                    context.l10n.certifications_detail_action_delete,
                    style: const TextStyle(color: Colors.red),
                  ),
                ],
              ),
            ),
          ],
        );

  Widget _buildCourseSection(BuildContext context, WidgetRef ref) {
    final courseAsync = ref.watch(
      courseForCertificationProvider(certification.id),
    );

    return courseAsync.when(
      data: (course) {
        if (course == null) {
          return const SizedBox.shrink();
        }

        final colorScheme = Theme.of(context).colorScheme;

        return Column(
          children: [
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: DetailRowGroup(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        context
                            .l10n
                            .certifications_detail_sectionTitle_trainingCourse,
                        style: Theme.of(context).textTheme.titleMedium
                            ?.copyWith(fontWeight: FontWeight.bold),
                      ),
                      const SizedBox(height: 12),
                      ListTile(
                        contentPadding: EdgeInsets.zero,
                        leading: Container(
                          width: 40,
                          height: 40,
                          decoration: BoxDecoration(
                            color: course.isCompleted
                                ? Colors.green.withValues(alpha: 0.15)
                                : colorScheme.primaryContainer,
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Icon(
                            course.isCompleted
                                ? Icons.check_circle_outline
                                : Icons.school_outlined,
                            color: course.isCompleted
                                ? Colors.green
                                : colorScheme.onPrimaryContainer,
                            size: 20,
                          ),
                        ),
                        title: Text(
                          course.name,
                          style: Theme.of(context).textTheme.bodyLarge,
                        ),
                        subtitle: Text(
                          '${context.certificationCatalog.agency(course.agency).localizedName(context.l10n)} - ${course.isCompleted ? context.l10n.certifications_detail_courseCompleted : context.l10n.certifications_detail_courseInProgress}',
                          style: Theme.of(context).textTheme.bodySmall
                              ?.copyWith(color: colorScheme.onSurfaceVariant),
                        ),
                        trailing: const Icon(Icons.chevron_right),
                        onTap: () {
                          if (embedded) {
                            context.go('/courses?selected=${course.id}');
                          } else {
                            context.push('/courses/${course.id}');
                          }
                        },
                      ),
                      if (course.instructorDisplay.isNotEmpty) ...[
                        const Divider(),
                        IconDetailRow(
                          icon: Icons.person,
                          label: 'Instructor',
                          value: course.instructorDisplay,
                        ),
                      ],
                    ],
                  ),
                ),
              ),
            ),
            const SizedBox(height: 16),
          ],
        );
      },
      loading: () => const SizedBox.shrink(),
      error: (error, stack) => const SizedBox.shrink(),
    );
  }
}
