import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import 'package:submersion/core/providers/provider.dart';
import 'package:submersion/core/utils/unit_formatter.dart';
import 'package:submersion/features/certification_agencies/presentation/certification_entry_display.dart';
import 'package:submersion/features/certification_agencies/presentation/providers/certification_catalog_context.dart';
import 'package:submersion/features/certification_agencies/presentation/providers/certification_catalog_providers.dart';
import 'package:submersion/features/certifications/domain/entities/certification.dart';
import 'package:submersion/features/certifications/presentation/certification_title_l10n.dart';
import 'package:submersion/features/certifications/presentation/providers/certification_providers.dart';
import 'package:submersion/features/courses/presentation/providers/course_providers.dart';
import 'package:submersion/features/settings/presentation/providers/settings_providers.dart';
import 'package:submersion/l10n/l10n_extension.dart';

/// The certifications a course earned, as removable chips (#2515). Tapping the
/// field opens a checklist sheet that reports every toggle through
/// [onChanged], so several certifications can be ticked in one visit.
class CertificationMultiSelectField extends ConsumerWidget {
  const CertificationMultiSelectField({
    super.key,
    required this.courseId,
    required this.selectedCertificationIds,
    required this.onChanged,
  });

  /// The course being edited, or null for a new one. A certification linked
  /// to any other course says so in the sheet.
  final String? courseId;
  final List<String> selectedCertificationIds;
  final ValueChanged<List<String>> onChanged;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    ref.watch(certificationCatalogSyncProvider);
    final certs =
        ref.watch(certificationListNotifierProvider).value ??
        const <Certification>[];
    final byId = {for (final c in certs) c.id: c};
    final theme = Theme.of(context);

    return InkWell(
      onTap: () => showModalBottomSheet<void>(
        context: context,
        isScrollControlled: true,
        showDragHandle: true,
        builder: (_) => CertificationMultiPickerSheet(
          courseId: courseId,
          selectedCertificationIds: selectedCertificationIds,
          onChanged: onChanged,
        ),
      ),
      child: InputDecorator(
        decoration: const InputDecoration(
          suffixIcon: Icon(Icons.arrow_drop_down),
        ),
        child: selectedCertificationIds.isEmpty
            ? Text(
                context.l10n.certifications_picker_hint,
                style: theme.textTheme.bodyMedium?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                ),
              )
            : Wrap(
                spacing: 6,
                runSpacing: 4,
                children: [
                  for (final id in selectedCertificationIds)
                    if (byId[id] case final cert?)
                      InputChip(
                        avatar: const Icon(Icons.card_membership, size: 16),
                        label: Text(
                          certificationTitleL10n(
                            cert,
                            context.l10n,
                            catalog: context.certificationCatalog,
                          ),
                        ),
                        materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                        visualDensity: VisualDensity.compact,
                        onDeleted: () => onChanged([
                          for (final other in selectedCertificationIds)
                            if (other != id) other,
                        ]),
                      ),
                ],
              ),
      ),
    );
  }
}

/// The checklist of certifications, most recently issued first. A
/// certification linked to another course shows that course's name; ticking
/// it moves the certification to this course on save.
class CertificationMultiPickerSheet extends ConsumerStatefulWidget {
  const CertificationMultiPickerSheet({
    super.key,
    required this.courseId,
    required this.selectedCertificationIds,
    required this.onChanged,
  });

  final String? courseId;
  final List<String> selectedCertificationIds;
  final ValueChanged<List<String>> onChanged;

  @override
  ConsumerState<CertificationMultiPickerSheet> createState() =>
      _CertificationMultiPickerSheetState();
}

class _CertificationMultiPickerSheetState
    extends ConsumerState<CertificationMultiPickerSheet> {
  late List<String> _working = [...widget.selectedCertificationIds];

  void _toggle(String id) {
    final selected = !_working.contains(id);
    final next = [
      for (final c in _working)
        if (c != id) c,
      if (selected) id,
    ];
    setState(() => _working = next);
    widget.onChanged(next);
  }

  void _createCertification() {
    Navigator.of(context).pop();
    context.push('/certifications/new');
  }

  @override
  Widget build(BuildContext context) {
    ref.watch(certificationCatalogSyncProvider);
    final certsAsync = ref.watch(certificationListNotifierProvider);
    final courseNames = {
      for (final c in ref.watch(allCoursesProvider).value ?? const [])
        c.id: c.name,
    };
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return SafeArea(
      child: ConstrainedBox(
        constraints: BoxConstraints(
          maxHeight: MediaQuery.sizeOf(context).height * 0.7,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 0, 12, 4),
              child: Row(
                children: [
                  Expanded(
                    child: Text(
                      context.l10n.certifications_picker_selectTitle,
                      style: theme.textTheme.titleMedium,
                    ),
                  ),
                  IconButton(
                    onPressed: _createCertification,
                    icon: const Icon(Icons.add),
                    tooltip: context.l10n.certifications_picker_newCert,
                  ),
                  TextButton(
                    onPressed: () => Navigator.of(context).pop(),
                    child: Text(context.l10n.common_action_done),
                  ),
                ],
              ),
            ),
            const Divider(height: 1),
            Flexible(
              child: certsAsync.when(
                data: (certs) {
                  if (certs.isEmpty) {
                    return Padding(
                      padding: const EdgeInsets.all(24),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            Icons.card_membership_outlined,
                            size: 48,
                            color: colorScheme.onSurfaceVariant,
                          ),
                          const SizedBox(height: 16),
                          Text(
                            context.l10n.certifications_picker_empty_title,
                            style: theme.textTheme.titleMedium,
                          ),
                          const SizedBox(height: 8),
                          TextButton.icon(
                            onPressed: _createCertification,
                            icon: const Icon(Icons.add),
                            label: Text(
                              context
                                  .l10n
                                  .certifications_picker_empty_addButton,
                            ),
                          ),
                        ],
                      ),
                    );
                  }
                  // Most recently issued first.
                  final sorted = [...certs]
                    ..sort(
                      (a, b) => (b.issueDate ?? b.createdAt).compareTo(
                        a.issueDate ?? a.createdAt,
                      ),
                    );
                  return ListView(
                    shrinkWrap: true,
                    children: [
                      for (final c in sorted)
                        _row(
                          context,
                          c,
                          linkedTo:
                              c.courseId != null &&
                                  c.courseId != widget.courseId
                              ? courseNames[c.courseId]
                              : null,
                        ),
                    ],
                  );
                },
                loading: () => const Padding(
                  padding: EdgeInsets.all(24),
                  child: Center(child: CircularProgressIndicator()),
                ),
                error: (error, _) => Padding(
                  padding: const EdgeInsets.all(24),
                  child: Text(
                    context.l10n.certifications_picker_error(error.toString()),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _row(BuildContext context, Certification cert, {String? linkedTo}) {
    final l10n = context.l10n;
    final catalog = context.certificationCatalog;
    final colorScheme = Theme.of(context).colorScheme;
    final selected = _working.contains(cert.id);
    final units = UnitFormatter(ref.watch(settingsProvider));
    final title = certificationTitleL10n(cert, l10n, catalog: catalog);
    final credentials = certificationCredentialsLineL10n(
      cert,
      l10n,
      catalog: catalog,
    );
    final dated = cert.issueDate != null
        ? '$credentials - ${units.formatDate(cert.issueDate)}'
        : credentials;
    final linked = linkedTo != null
        ? l10n.courses_picker_linkedTo(linkedTo)
        : null;

    // Only non-null when a custom name owns the title, so the level is spoken
    // exactly once either way.
    final level = certificationSubtitleL10n(cert, l10n, catalog: catalog);
    // A multi-credential card also names its other recognitions, matching
    // what the visible subtitle shows.
    final alsoRecognized = additionalCredentialsLineL10n(
      cert,
      l10n,
      catalog: catalog,
    );
    // Keep the agency: this label replaces the tile's own semantics,
    // including the subtitle that shows the agency visually.
    final name =
        '${catalog.agency(cert.agency).localizedName(l10n)} $title'
        '${level != null ? ', $level' : ''}'
        '${alsoRecognized != null ? ', $alsoRecognized' : ''}';
    final label =
        '$name'
        '${cert.issueDate != null ? ', issued ${units.formatDate(cert.issueDate)}' : ''}'
        '${selected ? ', selected' : ''}'
        '${cert.isExpired ? ', expired' : ''}'
        '${linked != null ? ', $linked' : ''}';

    return Semantics(
      label: label,
      // Without excludeSemantics the label merges with the tile's own text
      // rather than standing in for it, so a screen reader hears it twice.
      // Excluding the subtree drops the tile's tap action with its text, so
      // restate it here or the row stops being activatable.
      excludeSemantics: true,
      button: true,
      onTap: () => _toggle(cert.id),
      child: CheckboxListTile(
        value: selected,
        onChanged: (_) => _toggle(cert.id),
        title: Text(title),
        subtitle: Text(linked != null ? '$dated\n$linked' : dated),
        secondary: cert.isExpired
            ? Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                decoration: BoxDecoration(
                  color: colorScheme.errorContainer,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Text(
                  l10n.certifications_picker_expired,
                  style: Theme.of(context).textTheme.labelSmall?.copyWith(
                    color: colorScheme.onErrorContainer,
                  ),
                ),
              )
            : null,
      ),
    );
  }
}
