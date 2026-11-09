import 'package:flutter/material.dart';

import 'package:submersion/l10n/l10n_extension.dart';
import 'package:submersion/shared/widgets/info_sheet/info_content.dart';
import 'package:submersion/shared/widgets/master_detail/responsive_breakpoints.dart';

/// Opens [content] as a bottom sheet below the desktop breakpoint and as a
/// narrow dialog at or above it.
Future<void> showInfoSheet(BuildContext context, InfoContent content) {
  final width = MediaQuery.sizeOf(context).width;
  if (width < ResponsiveBreakpoints.desktop) {
    return showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      showDragHandle: true,
      builder: (sheetContext) {
        final maxHeight = MediaQuery.sizeOf(sheetContext).height * 0.85;
        return ConstrainedBox(
          constraints: BoxConstraints(maxHeight: maxHeight),
          child: SingleChildScrollView(
            padding: const EdgeInsets.fromLTRB(24, 0, 24, 24),
            child: InfoSheetBody(content: content),
          ),
        );
      },
    );
  }
  return showDialog<void>(
    context: context,
    builder: (dialogContext) => Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 480),
        child: AlertDialog(
          scrollable: true,
          content: InfoSheetBody(content: content),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(dialogContext).pop(),
              child: Text(dialogContext.l10n.info_sheet_close),
            ),
          ],
        ),
      ),
    ),
  );
}

/// The text of an info sheet: title, summary, terms, Background, How to use.
///
/// Draws no scroll view of its own, so the sheet and the dialog each wrap it
/// in the scrolling their container needs.
class InfoSheetBody extends StatelessWidget {
  const InfoSheetBody({super.key, required this.content});

  final InfoContent content;

  /// Key on the block of term rows, present only when there are terms.
  static const termsKey = ValueKey('info-sheet-terms');

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final muted = theme.colorScheme.onSurfaceVariant;
    final body = theme.textTheme.bodyMedium;
    final children = <Widget>[
      Text(content.title, style: theme.textTheme.titleLarge),
    ];

    void gap(double height) => children.add(SizedBox(height: height));

    final summary = content.summary;
    if (summary != null && summary.isNotEmpty) {
      gap(8);
      children.add(Text(summary, style: body));
    }

    if (content.terms.isNotEmpty) {
      children.add(
        Column(
          key: termsKey,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            for (final entry in content.terms) ...[
              const SizedBox(height: 12),
              Text.rich(
                TextSpan(
                  children: [
                    TextSpan(
                      text: entry.term,
                      style: body?.copyWith(fontWeight: FontWeight.w600),
                    ),
                    const TextSpan(text: '\n'),
                    TextSpan(
                      text: entry.body,
                      style: body?.copyWith(color: muted),
                    ),
                  ],
                ),
              ),
            ],
          ],
        ),
      );
    }

    void section(String label, String? text) {
      if (text == null || text.isEmpty) return;
      gap(20);
      children.add(
        Text(
          label.toUpperCase(),
          style: theme.textTheme.labelSmall?.copyWith(
            color: muted,
            letterSpacing: 0.8,
          ),
        ),
      );
      gap(6);
      children.add(Text(text, style: body));
    }

    section(context.l10n.info_sheet_background, content.background);
    section(context.l10n.info_sheet_howToUse, content.howToUse);

    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: children,
    );
  }
}
