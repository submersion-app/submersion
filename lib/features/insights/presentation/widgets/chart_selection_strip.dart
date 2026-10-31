import 'package:flutter/material.dart';

import 'package:submersion/l10n/l10n_extension.dart';

/// What a marked bar or slice stands for, under its chart (issue #3805): its
/// number, and with [onOpen] a way into the dives behind it.
class ChartSelectionStrip extends StatefulWidget {
  const ChartSelectionStrip({
    super.key,
    required this.label,
    required this.countText,
    this.onOpen,
  });

  final String label;
  final String countText;

  /// Null leaves only the number, as for a bar with no dives.
  final Future<void> Function()? onOpen;

  @override
  State<ChartSelectionStrip> createState() => _ChartSelectionStripState();
}

class _ChartSelectionStripState extends State<ChartSelectionStrip> {
  bool _opening = false;

  Future<void> _open() async {
    if (_opening) return;
    setState(() => _opening = true);
    try {
      await widget.onOpen!();
    } finally {
      if (mounted) setState(() => _opening = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final text = theme.textTheme.bodySmall?.copyWith(
      color: theme.colorScheme.onSecondaryContainer,
    );
    final canOpen = widget.onOpen != null;
    return Padding(
      padding: const EdgeInsets.only(top: 8),
      child: Material(
        color: theme.colorScheme.secondaryContainer,
        borderRadius: BorderRadius.circular(8),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: canOpen ? _open : null,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            child: Row(
              children: [
                Expanded(
                  child: Text(
                    '${widget.label} · ${widget.countText}',
                    style: text,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                if (canOpen) ...[
                  const SizedBox(width: 8),
                  Text(
                    context.l10n.insights_chart_viewDives,
                    style: text?.copyWith(fontWeight: FontWeight.w600),
                  ),
                  const SizedBox(width: 2),
                  SizedBox.square(
                    dimension: 18,
                    child: _opening
                        ? const Padding(
                            padding: EdgeInsets.all(2),
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : Icon(
                            Icons.chevron_right,
                            size: 18,
                            color: text?.color,
                          ),
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }
}
