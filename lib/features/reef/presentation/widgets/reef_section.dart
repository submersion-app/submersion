import 'package:flutter/material.dart';

import 'package:submersion/core/constants/enums.dart';
import 'package:submersion/core/providers/provider.dart';
import 'package:submersion/features/dive_sites/domain/entities/dive_site.dart';
import 'package:submersion/features/reef/domain/entities/reef_data_status.dart';
import 'package:submersion/features/reef/presentation/providers/reef_providers.dart';
import 'package:submersion/features/reef/presentation/widgets/reef_attribution_sheet.dart';
import 'package:submersion/features/reef/presentation/widgets/reef_habitat_card.dart';
import 'package:submersion/features/reef/presentation/widgets/water_conditions_card.dart';
import 'package:submersion/features/reef/presentation/widgets/reef_protection_card.dart';
import 'package:submersion/l10n/l10n_extension.dart';

/// Ecosystem information for a dive site: habitat when on a reef, satellite
/// water conditions, and protected status.
///
/// Fetched from online sources when the site is viewed, then cached. Hidden
/// entirely for sites without coordinates.
class ReefSection extends ConsumerWidget {
  final GeoPoint location;

  /// Freshwater sites skip the NOAA fetch: its grid covers only oceans.
  final WaterType? waterType;

  const ReefSection({super.key, required this.location, this.waterType});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final snapshotAsync = ref.watch(
      reefSnapshotProvider(
        ReefSnapshotRequest(
          location: location,
          fetchHealth: waterType != WaterType.fresh,
        ),
      ),
    );

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
                  if (snapshot.habitat.status != ReefDataStatus.empty)
                    ReefHabitatCard(part: snapshot.habitat),
                  WaterConditionsCard(
                    health: snapshot.health,
                    habitat: snapshot.habitat,
                    waterType: waterType,
                  ),
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
