import 'package:flutter/material.dart';

import 'package:submersion/l10n/l10n_extension.dart';
import 'package:submersion/shared/widgets/forms/form_style.dart';

/// A collapsible form group: one tonal card whose first row is a permanent
/// header (icon + title + trailing state + chevron).
///
/// One anatomy, four states (see the 2026-07-17 design-freeze mockup):
/// - expanded: header (up-chevron) + hairline divider + [children]
/// - collapsed with data: header only, muted [summary] before the chevron
/// - collapsed and empty: header only, fainter [emptyInvitation]
/// - collapsed with errors: header only, error badge + error-tinted edge
///
/// Expansion is owned by the page; pass [onToggle] null for sections that
/// are never collapsible (their header shows no chevron and is not
/// tappable). The whole header row is the toggle tap target.
///
/// NOTE: when collapsed, [children] are not mounted at all — fields inside
/// a collapsed section are invisible to Form.validate().
class FormSection extends StatelessWidget {
  const FormSection({
    super.key,
    required this.label,
    required this.expanded,
    required this.onToggle,
    required this.children,
    this.icon,
    this.summary,
    this.emptyInvitation,
    this.isEmpty = false,
    this.errorCount = 0,
  });

  final String label;
  final bool expanded;
  final VoidCallback? onToggle;
  final List<Widget> children;
  final IconData? icon;
  final String? summary;
  final String? emptyInvitation;
  final bool isEmpty;
  final int errorCount;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final hasCollapsedError = errorCount > 0 && !expanded;
    return Material(
      color: FormStyle.groupColor(context),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(FormStyle.groupRadius),
        side: BorderSide(color: FormStyle.cardBorderColor(context)),
      ),
      clipBehavior: Clip.antiAlias,
      child: Container(
        foregroundDecoration: hasCollapsedError
            ? BoxDecoration(
                border: Border(
                  left: BorderSide(color: theme.colorScheme.error, width: 3),
                ),
              )
            : null,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            _buildHeader(context),
            AnimatedSize(
              duration: const Duration(milliseconds: 200),
              curve: Curves.easeInOut,
              alignment: Alignment.topCenter,
              child: expanded
                  ? _buildBody(context)
                  : const SizedBox(width: double.infinity),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildHeader(BuildContext context) {
    final theme = Theme.of(context);
    final header = Padding(
      padding: FormStyle.headerPadding,
      child: Row(
        children: [
          if (icon != null) ...[
            Icon(icon, size: 18, color: theme.colorScheme.primary),
            const SizedBox(width: 10),
          ],
          Text(label, style: FormStyle.sectionTitleStyle(context)),
          const SizedBox(width: 12),
          Expanded(
            child: Align(
              alignment: Alignment.centerRight,
              child: _buildTrailing(context),
            ),
          ),
          if (onToggle != null) ...[
            const SizedBox(width: 6),
            Icon(
              expanded ? Icons.keyboard_arrow_up : Icons.keyboard_arrow_down,
              size: 20,
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ],
        ],
      ),
    );
    if (onToggle == null) return header;
    return Semantics(
      container: true,
      button: true,
      label: label,
      child: InkWell(onTap: onToggle, child: header),
    );
  }

  Widget _buildTrailing(BuildContext context) {
    final theme = Theme.of(context);
    if (expanded) return const SizedBox.shrink();
    if (errorCount > 0) {
      return Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            Icons.warning_amber_rounded,
            size: 16,
            color: theme.colorScheme.error,
          ),
          const SizedBox(width: 4),
          Text(
            context.l10n.forms_section_issues(errorCount),
            style: theme.textTheme.labelMedium!.copyWith(
              color: theme.colorScheme.error,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      );
    }
    final text = isEmpty ? (emptyInvitation ?? '') : (summary ?? '');
    if (text.isEmpty) return const SizedBox.shrink();
    return Text(
      text,
      style: theme.textTheme.bodySmall!.copyWith(
        color: isEmpty
            ? FormStyle.invitationColor(context)
            : theme.colorScheme.onSurfaceVariant,
      ),
      maxLines: 1,
      overflow: TextOverflow.ellipsis,
      textAlign: TextAlign.right,
    );
  }

  Widget _buildBody(BuildContext context) {
    final divider = Divider(
      height: 1,
      thickness: 1,
      color: FormStyle.dividerColor(context),
    );
    final rows = <Widget>[divider];
    for (var i = 0; i < children.length; i++) {
      rows.add(children[i]);
      if (i < children.length - 1) rows.add(divider);
    }
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: rows,
    );
  }
}
