import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import 'package:submersion/features/change_log/presentation/widgets/change_log_history_menu_item.dart';
import 'package:submersion/features/connections/domain/entities/connection_kind.dart';
import 'package:submersion/features/connections/domain/entities/node_ref.dart';
import 'package:submersion/features/connections/presentation/widgets/open_in_connections.dart';
import 'package:submersion/core/services/pdf_templates/pdf_localization.dart';
import 'package:submersion/l10n/l10n_extension.dart';
import 'package:submersion/core/services/export/export_service.dart';
import 'package:submersion/core/services/pdf_templates/pdf_date_formatter.dart';
import 'package:submersion/core/utils/unit_formatter.dart';
import 'package:submersion/shared/widgets/master_detail/detail_scroll_retainer.dart';
import 'package:submersion/shared/widgets/master_detail/responsive_breakpoints.dart';
import 'package:submersion/features/buddies/presentation/providers/buddy_providers.dart';
import 'package:submersion/features/certifications/domain/entities/certification.dart';
import 'package:submersion/features/certifications/presentation/certification_title_l10n.dart';
import 'package:submersion/features/courses/data/services/course_edit_save_service.dart';
import 'package:submersion/features/courses/domain/entities/course.dart';
import 'package:submersion/features/courses/presentation/course_status_colors.dart';
import 'package:submersion/features/courses/presentation/editing/course_card_ids.dart';
import 'package:submersion/features/courses/presentation/editing/course_edit_cards.dart';
import 'package:submersion/features/courses/presentation/editing/course_requirements_sitting.dart';
import 'package:submersion/features/courses/presentation/providers/course_providers.dart';
import 'package:submersion/features/courses/presentation/widgets/course_certification_thumbnail.dart';
import 'package:submersion/features/courses/presentation/widgets/course_requirements_section.dart';
import 'package:submersion/features/dive_log/domain/entities/dive.dart';
import 'package:submersion/features/settings/presentation/providers/settings_providers.dart';
import 'package:submersion/features/certification_agencies/presentation/certification_entry_display.dart';
import 'package:submersion/features/certification_agencies/presentation/providers/certification_catalog_context.dart';
import 'package:submersion/features/certification_agencies/presentation/providers/certification_catalog_providers.dart';
import 'package:submersion/features/documents/presentation/editing/record_document_links_sitting.dart';
import 'package:submersion/features/documents/presentation/widgets/documents_section.dart';
import 'package:submersion/features/documents/domain/entities/document.dart';
import 'package:submersion/shared/widgets/detail_row/detail_row_group.dart';
import 'package:submersion/shared/widgets/detail_row/detail_row.dart';
import 'package:submersion/shared/widgets/markdown_notes/markdown_notes_view.dart';
import 'package:submersion/shared/widgets/record_editing/add_strip.dart';
import 'package:submersion/shared/widgets/record_editing/edit_card.dart';
import 'package:submersion/shared/widgets/record_editing/edit_session.dart';
import 'package:submersion/shared/widgets/record_editing/record_card_fade.dart';
import 'package:submersion/shared/widgets/record_editing/record_card_frame.dart';
import 'package:submersion/shared/widgets/record_editing/record_card_pencil.dart';
import 'package:submersion/shared/widgets/record_editing/record_edit_host.dart';
import 'package:submersion/shared/widgets/record_editing/record_open_unlocked.dart';
import 'package:submersion/shared/widgets/record_editing/record_pane_row.dart';
import 'package:submersion/shared/widgets/record_editing/unlock_record_editing_flag.dart';

part 'course_detail_page_editing.dart';
part 'course_detail_page_sections.dart';

/// A course's page. Behind phase 3's switch ([unlockEditing]) it opens
/// locked and edits in place (issue #4527): its cards are held in one
/// sitting and written by one Save.
class CourseDetailPage extends ConsumerStatefulWidget {
  final String courseId;
  final bool embedded;
  final VoidCallback? onDeleted;

  /// Whether the page edits in place: phase 3's switch, a parameter so a
  /// test can turn it on.
  final bool unlockEditing;

  /// Opens unlocked, as the old edit address asks (`?mode=edit`).
  final bool openUnlocked;

  /// Told when a sitting the page opened unlocked ends: the list pane's
  /// edit returns to the course in view.
  final VoidCallback? onSittingEnded;

  const CourseDetailPage({
    super.key,
    required this.courseId,
    this.embedded = false,
    this.onDeleted,
    this.unlockEditing = kUnlockRecordEditing,
    this.openUnlocked = false,
    this.onSittingEnded,
  });

  @override
  ConsumerState<CourseDetailPage> createState() => _CourseDetailPageState();
}

class _CourseDetailPageState extends ConsumerState<CourseDetailPage>
    with
        RecordEditHost<CourseDetailPage, Course>,
        RecordOpenUnlocked<CourseDetailPage, Course>,
        _CourseDetailPageEditing {
  @override
  void dispose() {
    disposeEditing();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    ref.watch(certificationCatalogSyncProvider);
    final courseAsync = ref.watch(courseByIdProvider(widget.courseId));
    if (hostsEditing) followStored(courseByIdProvider(widget.courseId));

    return courseAsync.when(
      data: (course) {
        if (course == null) return _buildNotFound(context);
        if (!hostsEditing) {
          return _CourseDetailContent(
            course: course,
            stored: course,
            embedded: widget.embedded,
            onDeleted: widget.onDeleted,
          );
        }
        openUnlockedOnce(course);
        return _CourseDetailContent(
          course: shownRecord(course),
          stored: course,
          embedded: widget.embedded,
          onDeleted: widget.onDeleted,
          host: this,
        );
      },
      loading: () => _buildLoading(context),
      error: (error, stack) => _buildError(context, error),
    );
  }

  Widget _buildLoading(BuildContext context) {
    if (widget.embedded) {
      return const Center(child: CircularProgressIndicator());
    }
    return Scaffold(
      appBar: AppBar(title: Text(context.l10n.courses_title_singular)),
      body: const Center(child: CircularProgressIndicator()),
    );
  }

  Widget _buildNotFound(BuildContext context) {
    if (widget.embedded) {
      return Center(child: Text(context.l10n.courses_detail_notFound));
    }
    return Scaffold(
      appBar: AppBar(title: Text(context.l10n.courses_title_singular)),
      body: Center(child: Text(context.l10n.courses_detail_notFound)),
    );
  }

  Widget _buildError(BuildContext context, Object error) {
    final colorScheme = Theme.of(context).colorScheme;
    final content = Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.error_outline, size: 48, color: colorScheme.error),
          const SizedBox(height: 16),
          Text('${context.l10n.common_label_error}: $error'),
        ],
      ),
    );

    if (widget.embedded) return content;

    return Scaffold(
      appBar: AppBar(title: Text(context.l10n.courses_title_singular)),
      body: content,
    );
  }
}

class _CourseDetailContent extends ConsumerWidget {
  /// The course the cards show: the sitting's while unlocked.
  final Course course;

  /// The course as stored.
  final Course stored;
  final bool embedded;
  final VoidCallback? onDeleted;

  /// The page, where it edits in place.
  final _CourseDetailPageState? host;

  const _CourseDetailContent({
    required this.course,
    required this.stored,
    this.embedded = false,
    this.onDeleted,
    this.host,
  });

  bool get _editing => host != null;

  /// [child] as the card [id] where the page edits in place.
  Widget _framed(CourseCardId id, Widget child, {double topGap = 0}) =>
      host?._framed(id, child, topGap: topGap) ?? child;

  /// Whether the empty card [id] is shown in the sitting.
  bool _shows(CourseCardId id) => host?._showsWhileEmpty(id) ?? false;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final formatter = ref.watch(unitFormatterProvider);
    final divesAsync = ref.watch(courseDivesProvider(course.id));
    final trainingDives = _buildTrainingDivesCard(
      context,
      divesAsync,
      formatter,
    );

    final body = SingleChildScrollView(
      controller: DetailScrollController.maybeOf(context),
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _framed(CourseCardId.status, _buildStatusCard(context)),
          const SizedBox(height: 16),

          _framed(CourseCardId.details, _buildDetailsCard(context, formatter)),
          const SizedBox(height: 16),

          if (_showsInstructor()) ...[
            _framed(
              CourseCardId.instructor,
              _buildInstructorCard(context, ref),
            ),
            const SizedBox(height: 16),
          ],

          // Earned certifications, one row each (#2515)
          _buildCertificationSection(context, ref),

          // Requirement tracker. Carries its own top gap.
          if (_editing)
            _framed(
              CourseCardId.requirements,
              CourseRequirementsSection(
                courseId: course.id,
                readOnly: true,
                shown: this.host?.maybeEditController?.session,
              ),
              topGap: 16,
            )
          else
            CourseRequirementsSection(courseId: course.id),

          // Training dives: set from the dive's side.
          if (_editing) _calculated(trainingDives) else trainingDives,
          const SizedBox(height: 16),

          if (course.notes.isNotEmpty || _shows(CourseCardId.notes)) ...[
            _framed(CourseCardId.notes, _buildNotesCard(context)),
            const SizedBox(height: 16),
          ],
          _framed(
            CourseCardId.documents,
            DocumentsSection<Course>(
              owner: DocumentOwner(DocumentOwnerKind.course, course.id),
            ),
          ),
          const SizedBox(height: 16),

          // Where the page edits in place, Mark completed is on the Status
          // card's editor.
          if (!course.isCompleted && !_editing) ...[
            SizedBox(
              width: double.infinity,
              child: FilledButton.icon(
                onPressed: () => _markCompleted(context, ref),
                icon: const Icon(Icons.check),
                label: Text(context.l10n.courses_action_markCompleted),
              ),
            ),
            const SizedBox(height: 16),
          ],
        ],
      ),
    );

    final host = this.host;
    if (embedded) {
      final header = _buildEmbeddedHeader(context, ref);
      if (host != null) {
        return host.editPane(
          header: RecordPaneRow(
            locked: header,
            unlocked: host.isSittingOpen
                ? host.editingPaneRow(
                    stored,
                    menu: _buildMoreMenu(context, ref),
                  )
                : null,
          ),
          shown: course,
          content: body,
        );
      }
      return Column(
        children: [
          header,
          Expanded(child: body),
        ],
      );
    }

    final bar = AppBar(
      title: Text(course.name),
      actions: [
        if (host != null) host.lockButton(course),
        IconButton(
          icon: const Icon(Icons.edit),
          tooltip: context.l10n.courses_action_edit,
          // Where the page edits in place, Edit unlocks it as the lock does.
          onPressed: host != null
              ? () => host.editController.unlock(course)
              : () => context.push('/courses/${course.id}/edit'),
        ),
        _buildMoreMenu(context, ref),
      ],
    );
    if (host != null) {
      return host.editScaffold(
        record: stored,
        shown: course,
        lockedBar: bar,
        unlockedActions: [_buildMoreMenu(context, ref)],
        content: body,
      );
    }
    return Scaffold(appBar: bar, body: body);
  }

  Widget _buildEmbeddedHeader(BuildContext context, WidgetRef ref) {
    final colorScheme = Theme.of(context).colorScheme;
    final host = this.host;
    return Container(
      padding: const EdgeInsetsDirectional.fromSTEB(16, 16, 8, 8),
      decoration: BoxDecoration(
        border: Border(bottom: BorderSide(color: colorScheme.outlineVariant)),
      ),
      child: Row(
        children: [
          Expanded(
            child: Text(
              course.name,
              style: Theme.of(context).textTheme.titleLarge,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ),
          if (host != null) host.lockButton(course, compact: true),
          IconButton(
            icon: const Icon(Icons.edit),
            tooltip: context.l10n.courses_action_edit,
            onPressed: host != null
                ? () => host.editController.unlock(course)
                : () {
                    if (ResponsiveBreakpoints.isMasterDetail(context)) {
                      final state = GoRouterState.of(context);
                      final currentPath = state.uri.path;
                      // Use 'selected' param (not 'id') per
                      // MasterDetailScaffold convention
                      context.go(
                        '$currentPath?selected=${course.id}&mode=edit',
                      );
                    } else {
                      context.push('/courses/${course.id}/edit');
                    }
                  },
          ),
          _buildMoreMenu(context, ref),
        ],
      ),
    );
  }

  /// The overflow menu shared by the standalone and embedded headers.
  Widget _buildMoreMenu(BuildContext context, WidgetRef ref) {
    return PopupMenuButton<String>(
      tooltip: context.l10n.courses_action_moreOptions,
      onSelected: (value) {
        if (value == kOpenInConnectionsAction) {
          openInConnections(context, NodeRef(ConnectionKind.course, course.id));
        } else if (value == 'delete') {
          _confirmDelete(context, ref);
        } else if (value == 'export') {
          _exportTrainingLog(context, ref);
        }
      },
      itemBuilder: (context) => [
        changeLogHistoryMenuItem(
          context,
          rootTable: 'courses',
          rootId: course.id,
        ),
        openInConnectionsMenuItem(context),
        PopupMenuItem(
          value: 'export',
          child: Row(
            children: [
              const Icon(Icons.picture_as_pdf_outlined),
              const SizedBox(width: 8),
              Expanded(
                child: Text(context.l10n.courses_action_exportTrainingLog),
              ),
            ],
          ),
        ),
        PopupMenuItem(
          value: 'delete',
          child: Row(
            children: [
              const Icon(Icons.delete_outline, color: Colors.red),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  context.l10n.common_action_delete,
                  style: const TextStyle(color: Colors.red),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Future<void> _markCompleted(BuildContext context, WidgetRef ref) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(context.l10n.courses_dialog_markCompletedTitle),
        content: Text(context.l10n.courses_dialog_markCompletedMessage),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: Text(context.l10n.common_action_cancel),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: Text(context.l10n.courses_dialog_complete),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      final updated = course.copyWith(completionDate: DateTime.now());
      await ref.read(courseListNotifierProvider.notifier).updateCourse(updated);
      ref.invalidate(courseByIdProvider(course.id));
    }
  }

  Future<void> _confirmDelete(BuildContext context, WidgetRef ref) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(context.l10n.courses_dialog_deleteTitle),
        content: Text(context.l10n.courses_dialog_deleteMessage(course.name)),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: Text(context.l10n.common_action_cancel),
          ),
          FilledButton(
            style: FilledButton.styleFrom(
              backgroundColor: Theme.of(context).colorScheme.error,
            ),
            onPressed: () => Navigator.pop(context, true),
            child: Text(context.l10n.common_action_delete),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      await ref
          .read(courseListNotifierProvider.notifier)
          .deleteCourse(course.id);
      if (onDeleted != null) {
        onDeleted!();
      } else if (context.mounted) {
        context.pop();
      }
    }
  }

  Future<void> _exportTrainingLog(BuildContext context, WidgetRef ref) async {
    // Printed in the app language (#2252); read before any await.
    final localization = PdfLocalization.forLanguageCode(
      Localizations.localeOf(context).languageCode,
    );

    // Show loading indicator
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => const Center(child: CircularProgressIndicator()),
    );

    try {
      // Load training dives for this course
      final dives = await ref.read(courseDivesProvider(course.id).future);

      // Export to PDF
      final exportService = ExportService();
      final settings = ref.read(settingsProvider);
      await exportService.exportCourseTrainingLogToPdf(
        course,
        dives,
        dates: PdfDateFormatter(
          dateFormat: settings.dateFormat,
          timeFormat: settings.timeFormat,
        ),
        units: UnitFormatter(settings),
        localization: localization,
        catalog: await ref.read(allCustomCertificationsCatalogProvider.future),
      );

      // Dismiss loading
      if (context.mounted) {
        Navigator.of(context, rootNavigator: true).pop();
      }
    } catch (e) {
      // Dismiss loading
      if (context.mounted) {
        Navigator.of(context, rootNavigator: true).pop();

        // Show error
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              context.l10n.courses_message_exportFailed(e.toString()),
            ),
            backgroundColor: Theme.of(context).colorScheme.error,
          ),
        );
      }
    }
  }
}
