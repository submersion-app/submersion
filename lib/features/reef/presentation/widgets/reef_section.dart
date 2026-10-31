import 'dart:developer' as developer;

import 'package:flutter/material.dart';

import 'package:submersion/core/constants/enums.dart';
import 'package:submersion/core/providers/provider.dart';
import 'package:submersion/features/dive_sites/domain/entities/dive_site.dart';
import 'package:submersion/features/reef/domain/entities/reef_data_status.dart';
import 'package:submersion/features/reef/domain/entities/reef_health.dart';
import 'package:submersion/features/reef/presentation/providers/reef_providers.dart';
import 'package:submersion/features/reef/presentation/widgets/reef_attribution_sheet.dart';
import 'package:submersion/features/reef/presentation/widgets/reef_habitat_card.dart';
import 'package:submersion/features/reef/presentation/widgets/reef_part_rows.dart';
import 'package:submersion/features/reef/presentation/widgets/water_conditions_card.dart';
import 'package:submersion/features/reef/presentation/widgets/reef_protection_card.dart';
import 'package:submersion/l10n/l10n_extension.dart';

/// Ecosystem information for a dive site: habitat when on a reef, satellite
/// water conditions, and protected status.
///
/// Fetched from online sources when the site is viewed, then cached. Each row
/// follows its own source, so a slow one holds only itself back, and a failed
/// one offers a retry that leaves the others alone. Hidden entirely for sites
/// without coordinates.
class ReefSection extends ConsumerWidget {
  final GeoPoint location;

  /// Freshwater sites skip the NOAA fetch: its grid covers only oceans.
  final WaterType? waterType;

  const ReefSection({super.key, required this.location, this.waterType});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final l10n = context.l10n;
    final habitat = ref.watch(reefHabitatProvider(location));
    // Not watched for freshwater, so nothing is requested or cached.
    final health = waterType == WaterType.fresh
        ? const AsyncValue<ReefPart<ReefHealth>>.data(ReefPart.empty())
        : ref.watch(reefCurrentHealthProvider(location));
    final protection = ref.watch(reefProtectionProvider(location));

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
                    l10n.reef_section_title,
                    style: theme.textTheme.titleMedium,
                  ),
                  const Spacer(),
                  IconButton(
                    icon: const Icon(Icons.info_outline, size: 18),
                    tooltip: l10n.reef_section_sourcesTooltip,
                    onPressed: () => showModalBottomSheet<void>(
                      context: context,
                      builder: (_) => const ReefAttributionSheet(),
                    ),
                  ),
                ],
              ),
            ),
            _partRow(
              habitat,
              checking: ReefCheckingRow(
                icon: Icons.waves,
                title: l10n.reef_habitat_title,
              ),
              row: (part) => part.status == ReefDataStatus.empty
                  ? const SizedBox.shrink()
                  : ReefHabitatCard(
                      part: part,
                      onRetry: () => _retry(
                        context,
                        ref,
                        ReefProviderId.habitat,
                        () => ref.invalidate(reefHabitatProvider(location)),
                      ),
                    ),
            ),
            _partRow(
              health,
              checking: ReefCheckingRow(
                icon: Icons.thermostat,
                title: l10n.water_conditions_title,
              ),
              row: (part) => WaterConditionsCard(
                health: part,
                // Null until habitat resolves, which keeps the coral stress
                // lines: the conservative default.
                habitat: habitat.valueOrNull,
                waterType: waterType,
                onRetry: () => _retry(
                  context,
                  ref,
                  ReefProviderId.health,
                  () => ref.invalidate(reefCurrentHealthProvider(location)),
                ),
              ),
            ),
            _partRow(
              protection,
              checking: ReefCheckingRow(
                icon: Icons.shield_outlined,
                title: l10n.reef_protection_title,
              ),
              row: (part) => ReefProtectionCard(
                part: part,
                onRetry: () => _retry(
                  context,
                  ref,
                  ReefProviderId.protection,
                  () => ref.invalidate(reefProtectionProvider(location)),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  /// Builds one part's row. A retry counts as loading, so the row returns to
  /// [checking] instead of showing the old failure while the fetch runs.
  Widget _partRow<T>(
    AsyncValue<ReefPart<T>> value, {
    required Widget checking,
    required Widget Function(ReefPart<T>) row,
  }) {
    return value.when(
      skipLoadingOnRefresh: false,
      data: row,
      error: (_, _) => row(ReefPart<T>.unavailable()),
      loading: () => checking,
    );
  }

  /// A failure is cached, so invalidating alone would read it straight back.
  /// It has to be forgotten first.
  Future<void> _retry(
    BuildContext context,
    WidgetRef ref,
    ReefProviderId part,
    VoidCallback refetch,
  ) async {
    try {
      await ref.read(reefRepositoryProvider).forgetFailure(part, location);
    } catch (e) {
      developer.log('Reef retry failed: $e', name: 'ReefSection');
    }
    if (context.mounted) refetch();
  }
}
