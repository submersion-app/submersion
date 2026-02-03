import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:submersion/core/constants/pdf_templates.dart';

/// Dialog for selecting PDF export options.
///
/// Allows users to choose:
/// - Template style (Simple, Detailed, Professional, PADI, NAUI)
/// - Page size (A4, Letter)
/// - Whether to include certification cards
class PdfExportDialog extends ConsumerStatefulWidget {
  const PdfExportDialog({super.key});

  /// Show the dialog and return the selected options, or null if cancelled.
  static Future<PdfExportOptions?> show(BuildContext context) {
    return showModalBottomSheet<PdfExportOptions>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => const PdfExportDialog(),
    );
  }

  @override
  ConsumerState<PdfExportDialog> createState() => _PdfExportDialogState();
}

class _PdfExportDialogState extends ConsumerState<PdfExportDialog> {
  PdfTemplate _selectedTemplate = PdfTemplate.detailed;
  PdfPageSize _selectedPageSize = PdfPageSize.a4;
  bool _includeCertCards = false;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return Container(
      decoration: BoxDecoration(
        color: colorScheme.surface,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(16)),
      ),
      child: SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Handle bar
            Center(
              child: Container(
                margin: const EdgeInsets.only(top: 12),
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: colorScheme.onSurfaceVariant.withValues(alpha: 0.4),
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
            // Title
            Padding(
              padding: const EdgeInsets.all(16),
              child: Row(
                children: [
                  Icon(Icons.picture_as_pdf, color: colorScheme.primary),
                  const SizedBox(width: 12),
                  Text('Export PDF Logbook', style: theme.textTheme.titleLarge),
                ],
              ),
            ),
            const Divider(height: 1),
            // Scrollable content
            Flexible(
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Template selection
                    Text(
                      'Template',
                      style: theme.textTheme.titleSmall?.copyWith(
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 8),
                    ...PdfTemplate.values.map(
                      (template) => _buildTemplateOption(template, theme),
                    ),
                    const SizedBox(height: 16),
                    // Page size selection
                    Text(
                      'Page Size',
                      style: theme.textTheme.titleSmall?.copyWith(
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 8),
                    SegmentedButton<PdfPageSize>(
                      segments: PdfPageSize.values
                          .map(
                            (size) => ButtonSegment(
                              value: size,
                              label: Text(size.displayName),
                              tooltip: size.description,
                            ),
                          )
                          .toList(),
                      selected: {_selectedPageSize},
                      onSelectionChanged: (selected) {
                        setState(() => _selectedPageSize = selected.first);
                      },
                    ),
                    const SizedBox(height: 16),
                    // Certification cards option
                    if (_selectedTemplate.supportsCertificationCards) ...[
                      SwitchListTile(
                        title: const Text('Include Certification Cards'),
                        subtitle: const Text(
                          'Add scanned certification card images to the PDF',
                        ),
                        value: _includeCertCards,
                        onChanged: (value) {
                          setState(() => _includeCertCards = value);
                        },
                        contentPadding: EdgeInsets.zero,
                      ),
                    ],
                  ],
                ),
              ),
            ),
            const Divider(height: 1),
            // Action buttons
            Padding(
              padding: const EdgeInsets.all(16),
              child: Row(
                children: [
                  Expanded(
                    child: OutlinedButton(
                      onPressed: () => Navigator.of(context).pop(),
                      child: const Text('Cancel'),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    flex: 2,
                    child: FilledButton.icon(
                      onPressed: _exportPdf,
                      icon: const Icon(Icons.download),
                      label: const Text('Export PDF'),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTemplateOption(PdfTemplate template, ThemeData theme) {
    final isSelected = _selectedTemplate == template;
    final colorScheme = theme.colorScheme;

    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: InkWell(
        onTap: () => setState(() => _selectedTemplate = template),
        borderRadius: BorderRadius.circular(12),
        child: Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            border: Border.all(
              color: isSelected
                  ? colorScheme.primary
                  : colorScheme.outline.withValues(alpha: 0.5),
              width: isSelected ? 2 : 1,
            ),
            borderRadius: BorderRadius.circular(12),
            color: isSelected
                ? colorScheme.primaryContainer.withValues(alpha: 0.3)
                : null,
          ),
          child: Row(
            children: [
              // Template icon
              Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  color: isSelected
                      ? colorScheme.primary.withValues(alpha: 0.1)
                      : colorScheme.surfaceContainerHighest,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Icon(
                  _getTemplateIcon(template),
                  size: 20,
                  color: isSelected
                      ? colorScheme.primary
                      : colorScheme.onSurfaceVariant,
                ),
              ),
              const SizedBox(width: 12),
              // Template info
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      template.displayName,
                      style: theme.textTheme.titleSmall?.copyWith(
                        fontWeight: isSelected
                            ? FontWeight.bold
                            : FontWeight.normal,
                        color: isSelected ? colorScheme.primary : null,
                      ),
                    ),
                    Text(
                      template.description,
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: colorScheme.onSurfaceVariant,
                      ),
                    ),
                  ],
                ),
              ),
              // Selection indicator
              if (isSelected)
                Icon(Icons.check_circle, color: colorScheme.primary),
            ],
          ),
        ),
      ),
    );
  }

  IconData _getTemplateIcon(PdfTemplate template) {
    switch (template) {
      case PdfTemplate.simple:
        return Icons.table_rows;
      case PdfTemplate.detailed:
        return Icons.article;
      case PdfTemplate.professional:
        return Icons.verified;
      case PdfTemplate.padiStyle:
        return Icons.scuba_diving;
      case PdfTemplate.nauiStyle:
        return Icons.waves;
    }
  }

  void _exportPdf() {
    final options = PdfExportOptions(
      template: _selectedTemplate,
      pageSize: _selectedPageSize,
      includeCertificationCards:
          _selectedTemplate.supportsCertificationCards && _includeCertCards,
    );
    Navigator.of(context).pop(options);
  }
}
