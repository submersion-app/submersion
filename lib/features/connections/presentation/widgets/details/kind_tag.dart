import 'package:flutter/material.dart';
import 'package:submersion/features/connections/domain/entities/connection_kind.dart';
import 'package:submersion/features/connections/presentation/canvas/connection_kind_colors.dart';
import 'package:submersion/features/connections/presentation/widgets/connections_legend.dart';
import 'package:submersion/l10n/l10n_extension.dart';

/// The kind's canvas colour as a small dot, so a row reads as the node it
/// stands for.
class KindDot extends StatelessWidget {
  const KindDot({super.key, required this.kind, this.size = 10});

  final ConnectionKind kind;
  final double size;

  @override
  Widget build(BuildContext context) => Container(
    width: size,
    height: size,
    decoration: BoxDecoration(
      color: ConnectionKindColors.of(context).colorFor(kind),
      shape: BoxShape.circle,
    ),
  );
}

/// A dot and the singular kind name ("Site").
class KindTag extends StatelessWidget {
  const KindTag({super.key, required this.kind});

  final ConnectionKind kind;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        KindDot(kind: kind, size: 8),
        const SizedBox(width: 6),
        Text(
          kindNameOne(context.l10n, kind),
          style: theme.textTheme.labelMedium?.copyWith(
            color: theme.colorScheme.onSurfaceVariant,
          ),
        ),
      ],
    );
  }
}

/// A named entity with its kind beneath: one end of a selected line.
class KindedName extends StatelessWidget {
  const KindedName({super.key, required this.kind, required this.label});

  final ConnectionKind kind;
  final String label;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Row(
      children: [
        KindDot(kind: kind, size: 12),
        const SizedBox(width: 10),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(label, style: theme.textTheme.titleMedium),
              Text(
                kindNameOne(context.l10n, kind),
                style: theme.textTheme.bodySmall?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}
