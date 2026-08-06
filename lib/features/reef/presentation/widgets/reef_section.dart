import 'package:flutter/material.dart';

import 'package:submersion/core/providers/provider.dart';
import 'package:submersion/features/dive_sites/domain/entities/dive_site.dart';
import 'package:submersion/features/reef/presentation/providers/reef_providers.dart';
import 'package:submersion/features/reef/presentation/widgets/reef_attribution_sheet.dart';
import 'package:submersion/features/reef/presentation/widgets/reef_habitat_card.dart';
import 'package:submersion/features/reef/presentation/widgets/reef_health_card.dart';
import 'package:submersion/features/reef/presentation/widgets/reef_protection_card.dart';
import 'package:submersion/l10n/l10n_extension.dart';

/// Reef information for a dive site: habitat, health, and protected status.
///
/// Fetched from four online sources when the site is viewed, then cached.
/// Hidden entirely for sites without coordinates.
class ReefSection extends ConsumerWidget {
  final GeoPoint location;

  const ReefSection({super.key, required this.location});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final snapshotAsync = ref.watch(reefSnapshotProvider(location));

    return Card(
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 8),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 8, 8, 0),
              child: Row(
                children: [
                  Icon(
                    Icons.water_outlined,
                    size: 20,
                    color: theme.colorScheme.primary,
                  ),
                  const SizedBox(width: 8),
                  Text(
                    context.l10n.reef_section_title,
                    style: theme.textTheme.titleMedium,
                  ),
                  const Spacer(),
                  IconButton(
                    icon: const Icon(Icons.info_outline, size: 18),
                    tooltip: context.l10n.reef_section_sourcesTooltip,
                    onPressed: () => showModalBottomSheet<void>(
                      context: context,
                      builder: (_) => const ReefAttributionSheet(),
                    ),
                  ),
                ],
              ),
            ),
            snapshotAsync.when(
              data: (snapshot) => Column(
                children: [
                  ReefHabitatCard(part: snapshot.habitat),
                  ReefHealthCard(part: snapshot.health),
                  ReefProtectionCard(part: snapshot.protection),
                ],
              ),
              loading: () => const Padding(
                padding: EdgeInsets.all(24),
                child: Center(child: CircularProgressIndicator()),
              ),
              error: (_, _) => Padding(
                padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
                child: Text(context.l10n.reef_section_loadError),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
