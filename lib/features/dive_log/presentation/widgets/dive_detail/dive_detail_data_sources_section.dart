import 'package:flutter/material.dart';
import 'package:submersion/core/providers/provider.dart';
import 'package:submersion/core/utils/unit_formatter.dart';
import 'package:submersion/features/dive_3d/presentation/pages/dive_3d_page.dart';
import 'package:submersion/features/dive_log/domain/entities/dive.dart';
import 'package:submersion/features/dive_log/presentation/providers/active_source_provider.dart';
import 'package:submersion/features/dive_log/presentation/providers/dive_providers.dart';
import 'package:submersion/features/dive_log/presentation/widgets/data_sources_section.dart';
import 'package:submersion/features/dive_log/presentation/widgets/dive_detail/dive_detail_actions.dart';
import 'package:submersion/features/settings/presentation/providers/settings_providers.dart';

/// The Data sources section.
class DiveDetailDataSourcesSection extends ConsumerWidget {
  const DiveDetailDataSourcesSection({
    super.key,
    required this.dive,
    required this.actions,
  });

  final Dive dive;
  final DiveDetailActions actions;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final units = UnitFormatter(ref.watch(settingsProvider));
    final viewedSourceId = ref.watch(activeDiveSourceProvider(dive.id));
    final dataSources =
        ref.watch(diveDataSourcesProvider(dive.id)).valueOrNull ?? [];
    // 2+ segments means a Combine stitched this dive together, so
    // it can be pulled back apart (issue #1504). Read separately
    // from the source count: the halves of a combined import
    // collapse to a single display source (#1451).
    //
    // Read through the built-in AsyncValue.value, not the
    // valueOrNull polyfill. The two agree on every rebuild this
    // provider takes today: invalidateSelfWhen on the analysis tick
    // and the outright invalidate after a separation are both
    // self-invalidates, and the polyfill is `when`, which defaults
    // skipLoadingOnRefresh: true, so a refresh keeps the previous
    // count either way.
    //
    // They diverge on a RELOAD, the rebuild a changed dependency
    // forces, where `when` takes its loading branch and valueOrNull
    // answers null. Nothing reloads this provider yet: it watches
    // only singletons that never rebuild. `.value` is what keeps the
    // read correct if that changes, since `valueOrNull ?? 0` would
    // read as "never combined" for a frame and blink the Separate
    // action out of the section. DiveDetailProfileSection reads the same
    // way, and there the reload path is already live (#1468).
    final segmentCount =
        ref.watch(diveSegmentCountProvider(dive.id)).value ?? 0;
    return DataSourcesSection(
      dataSources: dataSources,
      diveCreatedAt: dive.dateTime,
      diveId: dive.id,
      units: units,
      viewedSourceId: viewedSourceId,
      onTapSource: (sourceId) {
        final notifier = ref.read(activeDiveSourceProvider(dive.id).notifier);
        notifier.state = notifier.state == sourceId ? null : sourceId;
      },
      onSetPrimary: actions.setPrimarySource,
      onSplit: (readingId) => actions.splitSource(dive, readingId),
      onSeparate: segmentCount >= 2
          ? () => actions.separateSegments(dive, segmentCount)
          : null,
      onCompareIn3d: () => Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) =>
              Dive3dPage(diveId: dive.id, initialMode: SceneKind.computers),
        ),
      ),
    );
  }
}
