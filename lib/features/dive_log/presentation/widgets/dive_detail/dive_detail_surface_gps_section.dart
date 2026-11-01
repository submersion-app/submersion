import 'package:flutter/material.dart';
import 'package:submersion/core/providers/provider.dart';
import 'package:submersion/features/dive_log/domain/entities/dive.dart';
import 'package:submersion/features/dive_log/domain/services/field_attribution_service.dart';
import 'package:submersion/features/dive_log/domain/services/source_name_resolver.dart';
import 'package:submersion/features/dive_log/presentation/helpers/source_name_labels.dart';
import 'package:submersion/features/dive_log/presentation/providers/active_source_provider.dart';
import 'package:submersion/features/dive_log/presentation/widgets/surface_gps_section.dart';
import 'package:submersion/features/settings/presentation/providers/settings_providers.dart';

/// The Surface GPS card with its data-source attribution, the same one in the
/// normal section flow and beside Tide.
class DiveDetailSurfaceGpsSection extends ConsumerWidget {
  const DiveDetailSurfaceGpsSection({super.key, required this.dive});

  final Dive dive;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final showBadgesSetting = ref.watch(
      settingsProvider.select((s) => s.showDataSourceBadges),
    );
    final viewedSourceId = ref.watch(activeDiveSourceProvider(dive.id));
    final dataSources = watchDiveDataSources(ref, dive.id);
    final attribution = FieldAttributionService.computeAttribution(
      dataSources,
      viewedSourceId: viewedSourceId,
      nameOf: (s) => resolveSourceName(s, sourceNameLabelsFor(context)),
    );
    final showBadges = showBadgesSetting && attribution.isNotEmpty;
    return SurfaceGpsSection(
      dive: dive,
      sourceName: showBadges ? attribution['gps'] : null,
    );
  }
}
