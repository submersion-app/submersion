import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import 'package:submersion/l10n/l10n_extension.dart';
import 'package:submersion/shared/widgets/master_detail/master_detail_scaffold.dart';
import 'package:submersion/shared/widgets/master_detail/responsive_breakpoints.dart';
import 'package:submersion/features/courses/presentation/widgets/course_list_content.dart';
import 'package:submersion/features/courses/presentation/widgets/course_summary_widget.dart';
import 'package:submersion/features/courses/presentation/pages/course_detail_page.dart';
import 'package:submersion/features/courses/presentation/pages/course_edit_page.dart';

class CourseListPage extends ConsumerWidget {
  const CourseListPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final fab = FloatingActionButton.extended(
      onPressed: () {
        if (ResponsiveBreakpoints.isMasterDetail(context)) {
          final state = GoRouterState.of(context);
          final currentPath = state.uri.path;
          context.go('$currentPath?mode=new');
        } else {
          context.push('/courses/new');
        }
      },
      tooltip: context.l10n.courses_action_add,
      icon: const Icon(Icons.add),
      label: Text(context.l10n.courses_action_add),
    );

    // Desktop: Use master-detail layout
    if (ResponsiveBreakpoints.isMasterDetail(context)) {
      return MasterDetailScaffold(
        sectionId: 'courses',
        masterBuilder: (context, onItemSelected, selectedId) =>
            CourseListContent(
              onItemSelected: onItemSelected,
              selectedId: selectedId,
              showAppBar: false,
            ),
        detailBuilder: (context, courseId) => CourseDetailPage(
          courseId: courseId,
          embedded: true,
          onDeleted: () {
            final state = GoRouterState.of(context);
            context.go(state.uri.path);
          },
        ),
        summaryBuilder: (context) => const CourseSummaryWidget(),
        editBuilder: (context, courseId, onSaved, onCancel) => CourseEditPage(
          courseId: courseId,
          embedded: true,
          onSaved: () => onSaved(courseId),
          onCancel: onCancel,
        ),
        createBuilder: (context, onSaved, onCancel) => CourseEditPage(
          embedded: true,
          onSavedWithId: onSaved,
          onCancel: onCancel,
        ),
        floatingActionButton: fab,
      );
    }

    // Mobile: Use list content with full scaffold
    return FocusTraversalGroup(
      child: CourseListContent(showAppBar: true, floatingActionButton: fab),
    );
  }
}
