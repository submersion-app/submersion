import 'package:flutter/material.dart';

/// The line a section summary shows under its title while the list beside
/// it is filtered, so the totals below are never read as lifetime ones:
/// "Filtered: summarizing 34 of 812 dives", plus a button that clears the
/// list's filter.
///
/// [message] is null while the counts are not known yet; the banner keeps
/// its place and shows no text. Used by the Dive Log (issue #1078) and Trips
/// (issue #4414) summaries.
class FilteredSummaryBanner extends StatelessWidget {
  const FilteredSummaryBanner({
    super.key,
    required this.message,
    required this.clearLabel,
    required this.onClear,
  });

  final String? message;
  final String clearLabel;
  final VoidCallback onClear;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return Container(
      padding: const EdgeInsetsDirectional.fromSTEB(16, 8, 8, 8),
      decoration: BoxDecoration(
        color: colorScheme.surfaceContainerHigh,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        children: [
          ExcludeSemantics(
            child: Icon(
              Icons.filter_list,
              size: 20,
              color: colorScheme.primary,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              message ?? '',
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                color: colorScheme.onSurfaceVariant,
              ),
            ),
          ),
          const SizedBox(width: 8),
          TextButton(onPressed: onClear, child: Text(clearLabel)),
        ],
      ),
    );
  }
}
