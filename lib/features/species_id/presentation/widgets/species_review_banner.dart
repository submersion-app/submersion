import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import 'package:submersion/core/providers/provider.dart';
import 'package:submersion/features/species_id/domain/entities/species_review.dart';
import 'package:submersion/features/species_id/presentation/providers/species_review_providers.dart';
import 'package:submersion/l10n/l10n_extension.dart';

/// "N species to review", at the top of the Species page (issue #4727),
/// on every device the app's tags reach. Hidden when there is nothing.
class SpeciesReviewBanner extends ConsumerWidget {
  const SpeciesReviewBanner({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final count =
        ref.watch(speciesReviewCountProvider(const LogReviewScope())).value ??
        0;
    if (count == 0) return const SizedBox.shrink();
    final scheme = Theme.of(context).colorScheme;
    return Material(
      color: scheme.secondaryContainer,
      child: ListTile(
        key: const ValueKey('species_review_banner'),
        leading: Icon(
          Icons.fact_check_outlined,
          color: scheme.onSecondaryContainer,
        ),
        title: Text(
          context.l10n.speciesReview_count(count),
          style: TextStyle(color: scheme.onSecondaryContainer),
        ),
        trailing: Icon(Icons.chevron_right, color: scheme.onSecondaryContainer),
        onTap: () => context.push('/species/review'),
      ),
    );
  }
}
