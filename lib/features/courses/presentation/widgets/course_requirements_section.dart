import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:submersion/l10n/l10n_extension.dart';
import 'package:submersion/features/courses/presentation/providers/course_requirement_providers.dart';
import 'package:submersion/features/courses/presentation/widgets/add_requirement_sheet.dart';
import 'package:submersion/features/courses/presentation/widgets/requirement_tile.dart';
import 'package:submersion/features/courses/presentation/widgets/template_picker_sheet.dart';

/// The requirement tracker card on the course detail page: overall progress
/// header, one tile per requirement, and empty-state actions.
class CourseRequirementsSection extends ConsumerWidget {
  const CourseRequirementsSection({super.key, required this.courseId});

  final String courseId;

  Future<void> _addRequirement(BuildContext context, WidgetRef ref) async {
    final draft = await showAddRequirementSheet(context);
    if (draft == null) return;
    await ref
        .read(courseRequirementRepositoryProvider)
        .createRequirement(
          courseId: courseId,
          name: draft.name,
          kind: draft.kind,
          targetCount: draft.targetCount,
        );
  }

  Future<void> _addFromTemplate(BuildContext context, WidgetRef ref) async {
    final template = await showTemplatePickerSheet(context);
    if (template == null) return;
    await ref
        .read(courseRequirementRepositoryProvider)
        .applyTemplate(courseId, template);
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final progressAsync = ref.watch(courseProgressProvider(courseId));
    final suggestionsAsync = ref.watch(suggestedDivesProvider(courseId));
    final theme = Theme.of(context);

    // AsyncValue.value keeps prior data during reloads (#429 flicker rule).
    final progress = progressAsync.value;
    if (progress == null) {
      return const SizedBox.shrink();
    }
    final suggestions = suggestionsAsync.value ?? const [];

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
                  child: Text(
                    context.l10n.courses_section_requirements,
                    style: theme.textTheme.titleMedium,
                  ),
                ),
                IconButton(
                  tooltip: context.l10n.courses_action_addFromTemplate,
                  icon: const Icon(Icons.library_add_outlined, size: 20),
                  onPressed: () => _addFromTemplate(context, ref),
                ),
                IconButton(
                  tooltip: context.l10n.courses_action_addRequirement,
                  icon: const Icon(Icons.add, size: 20),
                  onPressed: () => _addRequirement(context, ref),
                ),
              ],
            ),
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
                ),
            ] else ...[
              const SizedBox(height: 8),
              Text(
                context.l10n.courses_requirements_empty,
                style: theme.textTheme.bodySmall,
              ),
              const SizedBox(height: 8),
              Wrap(
                spacing: 8,
                children: [
                  TextButton.icon(
                    icon: const Icon(Icons.library_add_outlined, size: 18),
                    label: Text(context.l10n.courses_action_addFromTemplate),
                    onPressed: () => _addFromTemplate(context, ref),
                  ),
                  TextButton.icon(
                    icon: const Icon(Icons.add, size: 18),
                    label: Text(context.l10n.courses_action_addRequirement),
                    onPressed: () => _addRequirement(context, ref),
                  ),
                ],
              ),
            ],
          ],
        ),
      ),
    );
  }
}
