import 'package:flutter/material.dart';
import 'package:submersion/core/providers/provider.dart';
import 'package:submersion/core/utils/unit_formatter.dart';
import 'package:submersion/features/dive_log/domain/entities/dive.dart';
import 'package:submersion/features/dive_log/presentation/widgets/buoyancy_section.dart';
import 'package:submersion/features/dive_log/presentation/widgets/cylinders_card.dart';
import 'package:submersion/features/settings/presentation/providers/settings_providers.dart';

/// The Cylinders card, the same one in the normal section flow and beside Gas
/// consumption by segment.
class DiveDetailCylindersSection extends ConsumerWidget {
  const DiveDetailCylindersSection({super.key, required this.dive});

  final Dive dive;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final settings = ref.watch(settingsProvider);
    return CylindersCard(
      dive: dive,
      units: UnitFormatter(settings),
      settings: settings,
      display: ref.watch(gasConsumptionDisplayProvider),
    );
  }
}

/// The Buoyancy card, the same one in the normal section flow and beside
/// Weights.
class DiveDetailBuoyancySection extends ConsumerWidget {
  const DiveDetailBuoyancySection({super.key, required this.dive});

  final Dive dive;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return BuoyancySection(
      diveId: dive.id,
      units: UnitFormatter(ref.watch(settingsProvider)),
    );
  }
}
