import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import 'package:submersion/core/providers/provider.dart';
import 'package:submersion/features/trips/presentation/providers/side_trip_providers.dart';
import 'package:submersion/l10n/l10n_extension.dart';

/// "Part of" and the larger trip's name, for a side trip, opening the
/// larger trip on tap (issue #3658). Draws nothing for a trip of its own.
class PartOfTripLink extends ConsumerWidget {
  const PartOfTripLink({
    super.key,
    required this.tripId,
    this.padding = EdgeInsets.zero,
  });

  final String tripId;

  /// Around the link when it shows; nothing when it does not.
  final EdgeInsetsGeometry padding;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final parent = ref.watch(parentTripProvider(tripId)).value;
    if (parent == null) return const SizedBox.shrink();
    final color = Theme.of(context).colorScheme.primary;
    final label = context.l10n.trips_partOf(parent.name);
    final link = Semantics(
      button: true,
      label: label,
      excludeSemantics: true,
      child: InkWell(
        onTap: () => context.push('/trips/${parent.id}'),
        borderRadius: BorderRadius.circular(8),
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 4),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.account_tree_outlined, size: 16, color: color),
              const SizedBox(width: 6),
              Flexible(
                child: Text(
                  label,
                  style: Theme.of(
                    context,
                  ).textTheme.bodyMedium?.copyWith(color: color),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
        ),
      ),
    );
    return Padding(
      padding: padding,
      child: Align(alignment: AlignmentDirectional.centerStart, child: link),
    );
  }
}
