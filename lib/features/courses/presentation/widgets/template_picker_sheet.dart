import 'package:flutter/material.dart';

import 'package:submersion/l10n/l10n_extension.dart';
import 'package:submersion/core/constants/course_templates.dart';

/// Bottom sheet listing starter templates with a preview of the rows each
/// adds. Returns the selected template, or null on cancel.
Future<CourseTemplate?> showTemplatePickerSheet(BuildContext context) {
  return showModalBottomSheet<CourseTemplate>(
    context: context,
    isScrollControlled: true,
    builder: (context) => const _TemplatePickerSheet(),
  );
}

class _TemplatePickerSheet extends StatelessWidget {
  const _TemplatePickerSheet();

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    return SafeArea(
      child: ListView(
        shrinkWrap: true,
        padding: const EdgeInsets.symmetric(vertical: 8),
        children: [
          Padding(
            padding: const EdgeInsets.all(16),
            child: Text(
              l10n.courses_action_addFromTemplate,
              style: Theme.of(context).textTheme.titleMedium,
            ),
          ),
          for (final template in CourseTemplateCatalog.templates)
            ListTile(
              title: Text(template.name),
              subtitle: Text(
                template.requirements.map((r) => r.name).join(' · '),
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
              trailing: Text(
                l10n.courses_template_addsCount(template.requirements.length),
                style: Theme.of(context).textTheme.labelSmall,
              ),
              onTap: () => Navigator.of(context).pop(template),
            ),
        ],
      ),
    );
  }
}
