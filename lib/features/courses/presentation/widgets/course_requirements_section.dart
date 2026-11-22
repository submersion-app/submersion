import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:submersion/features/courses/domain/entities/course.dart';
import 'package:submersion/features/courses/domain/entities/course_progress.dart';
import 'package:submersion/features/courses/presentation/editing/course_requirements_sitting.dart';
import 'package:submersion/features/courses/presentation/providers/course_requirement_providers.dart';
import 'package:submersion/features/courses/presentation/widgets/requirement_tile.dart';
import 'package:submersion/l10n/l10n_extension.dart';
import 'package:submersion/shared/widgets/record_editing/edit_session.dart';
import 'package:submersion/shared/widgets/record_editing/record_card_pencil.dart';
import 'package:submersion/shared/widgets/record_editing/sitting_load_failed.dart';

/// The requirement tracker card on the course detail page: overall progress
/// header, one tile per requirement, and empty-state actions.
///
/// It offers nothing outside the open Requirements card (issue #4527, phase
/// 3); in the page's sitting ([editing]) everything it adds, ticks, credits
/// and removes is held until Save.
class CourseRequirementsSection extends ConsumerWidget {
  const CourseRequirementsSection({
    super.key,
    required this.courseId,
    this.editing,
    this.shown,
  });

  final String courseId;

  /// The sitting its changes are held in: it is the Requirements card's
  /// editor, drawn inside the open card.
  final EditSession<Course>? editing;

  /// The sitting whose requirements a closed card shows.
  final EditSession<Course>? shown;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final sitting = editing ?? shown;
    if (sitting == null) return _build(context, ref);
    // What the sitting holds is drawn as it changes, and only then: not on
    // every keystroke in another card.
    return ListenableBuilder(
      listenable: courseRequirementsList.changes(sitting),
      builder: (context, _) => _build(context, ref),
    );
  }

  Widget _build(BuildContext context, WidgetRef ref) {
    final progressAsync = ref.watch(courseProgressProvider(courseId));
    final suggestionsAsync = ref.watch(suggestedDivesProvider(courseId));
    final theme = Theme.of(context);

    // AsyncValue.value keeps prior data during reloads (#429 flicker rule).
    final stored = progressAsync.value;
    if (stored == null) {
      return const SizedBox.shrink();
    }
    final editing = this.editing;
    final sitting = editing ?? shown;
    final held = sitting == null
        ? null
        : courseRequirementsList.current(sitting);
    final progress = held == null
        ? stored
        : CourseProgress(courseId: courseId, requirements: held);
    final storedSuggestions = suggestionsAsync.value ?? const [];
    final suggestions = held == null
        ? storedSuggestions
        : suggestionsInSitting(storedSuggestions, held);
    final actions = editing == null ? null : HeldRequirementActions(editing);

    final addButtons = actions == null
        ? null
        : Wrap(
            spacing: 8,
            children: [
              TextButton.icon(
                icon: const Icon(Icons.library_add_outlined, size: 18),
                label: Text(context.l10n.courses_action_addFromTemplate),
                onPressed: () => actions.applyTemplate(context),
              ),
              TextButton.icon(
                icon: const Icon(Icons.add, size: 18),
                label: Text(context.l10n.courses_action_addRequirement),
                onPressed: () => actions.add(context),
              ),
            ],
          );

    final rows = <Widget>[
      if (progress.totalCount > 0) ...[
        const SizedBox(height: 8),
        Text(
          context.l10n.courses_requirements_progress(
            progress.satisfiedCount,
            progress.totalCount,
          ),
          style: theme.textTheme.bodySmall,
        ),
        const SizedBox(height: 4),
        LinearProgressIndicator(
          value: progress.satisfiedCount / progress.totalCount,
        ),
        const SizedBox(height: 8),
        for (final requirementProgress in progress.requirements)
          RequirementTile(
            progress: requirementProgress,
            suggestions: suggestions,
            actions: actions,
          ),
      ] else ...[
        const SizedBox(height: 8),
        Text(
          context.l10n.courses_requirements_empty,
          style: theme.textTheme.bodySmall,
        ),
      ],
    ];

    // The open card draws its own frame and title. A read of the rows that
    // failed says so; an action reads them again.
    if (editing != null) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (courseRequirementsList.failed(editing))
            SittingLoadFailed(
              onRetry: () => courseRequirementsList.load(editing),
            ),
          ?addButtons,
          ...rows,
        ],
      );
    }

    final title = context.l10n.courses_section_requirements;
    return Card(
      margin: const EdgeInsets.only(top: 16),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(
                  Icons.checklist,
                  size: 20,
                  color: theme.colorScheme.primary,
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(title, style: theme.textTheme.titleMedium),
                ),
                RecordCardPencil(cardTitle: title),
              ],
            ),
            ...rows,
          ],
        ),
      ),
    );
  }
}
