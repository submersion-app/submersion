import 'package:flutter/material.dart';

import 'package:submersion/core/utils/share_anchor.dart';
import 'package:submersion/l10n/l10n_extension.dart';

/// The three formats [BlenderInvoiceExportSheet] offers.
enum BlenderInvoiceExportFormat { pdf, image, excel }

/// Bottom sheet offering the three export formats for the running bill.
///
/// Pops immediately with the diver's choice rather than performing the
/// export itself. Running the export - and, in particular, opening the OS
/// share sheet - while this sheet is still mounted and mid-transition made
/// the native share chooser fail to list any targets ("not all sharing
/// methods could be displayed", issue #44). The caller starts the export
/// only after this sheet has fully closed, the same pattern already used by
/// the dive profile export sheet on the dive detail page.
///
/// A sheet rather than a bare popup menu because it needs enough vertical
/// room for a title and three tappable rows on the narrowest supported phone
/// (issue #1335 analysis).
class BlenderInvoiceExportSheet extends StatelessWidget {
  const BlenderInvoiceExportSheet({super.key});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              context.l10n.gasCalculators_blender_export,
              style: theme.textTheme.titleLarge?.copyWith(
                fontWeight: FontWeight.bold,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 20),
            _ExportOptionTile(
              key: const Key('blender-export-pdf'),
              icon: Icons.picture_as_pdf_outlined,
              title: context.l10n.gasCalculators_blender_exportPdf,
              format: BlenderInvoiceExportFormat.pdf,
            ),
            const SizedBox(height: 12),
            _ExportOptionTile(
              key: const Key('blender-export-image'),
              icon: Icons.image_outlined,
              title: context.l10n.gasCalculators_blender_exportImage,
              format: BlenderInvoiceExportFormat.image,
            ),
            const SizedBox(height: 12),
            _ExportOptionTile(
              key: const Key('blender-export-excel'),
              icon: Icons.table_chart_outlined,
              title: context.l10n.gasCalculators_blender_exportExcel,
              format: BlenderInvoiceExportFormat.excel,
            ),
          ],
        ),
      ),
    );
  }
}

class _ExportOptionTile extends StatelessWidget {
  const _ExportOptionTile({
    super.key,
    required this.icon,
    required this.title,
    required this.format,
  });

  final IconData icon;
  final String title;
  final BlenderInvoiceExportFormat format;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Card(
      margin: EdgeInsets.zero,
      child: InkWell(
        onTap: () =>
            Navigator.of(context).pop((format, shareAnchorFrom(context))),
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            children: [
              Icon(icon, color: theme.colorScheme.primary, size: 24),
              const SizedBox(width: 16),
              Expanded(child: Text(title, style: theme.textTheme.titleMedium)),
              Icon(
                Icons.chevron_right,
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
