import 'package:flutter/material.dart';

import 'package:submersion/l10n/l10n_extension.dart';

/// The frame of a report's options sheet: handle, title, scrolling options
/// and the Cancel and Continue buttons. A null [onContinue] disables Continue
/// until the options are complete.
class ReportSheetScaffold extends StatelessWidget {
  const ReportSheetScaffold({
    super.key,
    required this.title,
    required this.children,
    required this.onContinue,
  });

  /// Finds the Continue button in tests.
  @visibleForTesting
  static const continueKey = ValueKey('reportSheet.continue');

  final String title;
  final List<Widget> children;
  final VoidCallback? onContinue;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    // Material rather than a plain Container, so the list tiles inside have
    // a Material ancestor for their ink.
    return Material(
      color: colorScheme.surface,
      borderRadius: const BorderRadius.vertical(top: Radius.circular(16)),
      clipBehavior: Clip.antiAlias,
      child: SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            ExcludeSemantics(
              child: Center(
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
            ),
            Padding(
              padding: const EdgeInsets.all(16),
              child: Row(
                children: [
                  Icon(Icons.picture_as_pdf, color: colorScheme.primary),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(title, style: theme.textTheme.titleLarge),
                  ),
                ],
              ),
            ),
            const Divider(height: 1),
            Flexible(
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: children,
                ),
              ),
            ),
            const Divider(height: 1),
            Padding(
              padding: const EdgeInsets.all(16),
              child: Row(
                children: [
                  Expanded(
                    child: OutlinedButton(
                      onPressed: () => Navigator.of(context).pop(),
                      child: Text(context.l10n.transfer_pdfExport_cancelButton),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    flex: 2,
                    child: FilledButton(
                      key: continueKey,
                      onPressed: onContinue,
                      child: Text(context.l10n.equipmentReport_sheet_continue),
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
}

/// A labelled dropdown inside a report's options sheet.
class ReportSheetDropdown<T> extends StatelessWidget {
  const ReportSheetDropdown({
    super.key,
    required this.label,
    required this.value,
    required this.options,
    required this.onChanged,
  });

  final String label;
  final T? value;
  final List<(T, String)> options;
  final ValueChanged<T?> onChanged;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.only(bottom: 12),
    child: DropdownButtonFormField<T>(
      initialValue: value,
      isExpanded: true,
      decoration: InputDecoration(
        labelText: label,
        border: const OutlineInputBorder(),
        isDense: true,
      ),
      items: [
        for (final (option, text) in options)
          DropdownMenuItem(
            value: option,
            child: Text(text, overflow: TextOverflow.ellipsis),
          ),
      ],
      onChanged: onChanged,
    ),
  );
}
