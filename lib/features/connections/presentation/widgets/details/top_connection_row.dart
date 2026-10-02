import 'package:flutter/material.dart';
import 'package:submersion/features/connections/domain/entities/connection_kind.dart';
import 'package:submersion/features/connections/presentation/canvas/connection_kind_colors.dart';
import 'package:submersion/features/connections/presentation/widgets/connections_legend.dart';
import 'package:submersion/features/connections/presentation/widgets/kind_dot.dart';
import 'package:submersion/l10n/l10n_extension.dart';

/// One of a node's strongest connections: who or what, its kind, the dives
/// shared, and a bar scaled to the strongest connection in the list.
class TopConnectionRow extends StatelessWidget {
  const TopConnectionRow({
    super.key,
    required this.kind,
    required this.label,
    required this.weight,
    required this.fraction,
    required this.onTap,
  });

  final ConnectionKind kind;
  final String label;
  final int weight;

  /// [weight] relative to the strongest connection, 0 to 1.
  final double fraction;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final theme = Theme.of(context);
    final kindName = kindNameOne(l10n, kind);
    final color = ConnectionKindColors.of(context).colorFor(kind);
    // One spoken button. Excluding the children drops the InkWell's own tap
    // action, so the node carries [onTap] itself.
    return Semantics(
      button: true,
      excludeSemantics: true,
      label: '$label, $kindName, ${l10n.connections_selection_dives(weight)}',
      onTap: onTap,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(8),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 8),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  KindDot(color: color),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          label,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: theme.textTheme.bodyMedium,
                        ),
                        Text(
                          kindName,
                          style: theme.textTheme.bodySmall?.copyWith(
                            color: theme.colorScheme.onSurfaceVariant,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 8),
                  Text(
                    '$weight',
                    style: theme.textTheme.titleSmall?.copyWith(
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 6),
              Padding(
                padding: const EdgeInsetsDirectional.only(start: 20),
                child: LinearProgressIndicator(
                  value: fraction,
                  minHeight: 4,
                  borderRadius: BorderRadius.circular(2),
                  color: color,
                  backgroundColor: theme.colorScheme.surfaceContainerHighest,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
