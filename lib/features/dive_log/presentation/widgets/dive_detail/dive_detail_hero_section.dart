import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:submersion/core/providers/provider.dart';
import 'package:submersion/core/router/section_navigation.dart';
import 'package:submersion/core/utils/unit_formatter.dart';
import 'package:submersion/features/data_quality/presentation/providers/quality_inbox_providers.dart';
import 'package:submersion/features/dive_log/domain/entities/dive.dart';
import 'package:submersion/features/dive_log/domain/entities/dive_data_source.dart';
import 'package:submersion/features/dive_log/domain/services/bottom_time_calculator.dart';
import 'package:submersion/features/dive_log/presentation/providers/active_source_provider.dart';
import 'package:submersion/features/dive_log/presentation/providers/dive_providers.dart';
import 'package:submersion/features/dive_log/presentation/widgets/dive_hero_header.dart';
import 'package:submersion/features/settings/presentation/providers/settings_providers.dart';
import 'package:submersion/l10n/l10n_extension.dart';
import 'package:submersion/shared/widgets/master_detail/responsive_breakpoints.dart';

/// The fixed header card at the top of the page.
class DiveDetailHeroSection extends ConsumerWidget {
  const DiveDetailHeroSection({
    super.key,
    required this.dive,
    required this.embedded,
  });

  final Dive dive;

  /// In the master-detail pane, where a site opens beside the list.
  final bool embedded;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final units = UnitFormatter(ref.watch(settingsProvider));
    final viewedSourceId = ref.watch(activeDiveSourceProvider(dive.id));
    final dataSources =
        ref.watch(diveDataSourcesProvider(dive.id)).valueOrNull ?? [];
    // Header stat values follow the active source when a non-primary source
    // is selected on a multi-source dive; the SOURCES bar carries the
    // attribution, so the stat metrics themselves stay badge-free.
    final activeSource = viewedSourceId == null
        ? null
        : dataSources
              .where((s) => s.id == viewedSourceId && !s.isPrimary)
              .firstOrNull;
    final site = dive.site;
    return DiveHeroHeader(
      dive: dive,
      units: units,
      maxDepth: activeSource?.maxDepth,
      waterTemp: activeSource?.waterTemp,
      runtimeText: _formatRuntimeForSource(dive, activeSource),
      bottomTimeText: _formatBottomTimeForSource(ref, dive, activeSource),
      belowTitle: Consumer(
        builder: (context, ref, _) {
          final count =
              ref.watch(diveOpenFindingsCountProvider(dive.id)).value ?? 0;
          if (count == 0) return const SizedBox.shrink();
          return Padding(
            padding: const EdgeInsets.only(top: 4),
            child: ActionChip(
              avatar: Icon(
                Icons.rule,
                size: 16,
                color: Theme.of(context).colorScheme.tertiary,
              ),
              label: Text(context.l10n.dataQuality_detail_chipCount(count)),
              onPressed: () => context.push('/dives/quality?dive=${dive.id}'),
            ),
          );
        },
      ),
      onSiteTap: site == null
          ? null
          : () {
              if (embedded && ResponsiveBreakpoints.isMasterDetail(context)) {
                final state = GoRouterState.of(context);
                final currentPath = state.uri.path;
                final params = Map<String, String>.from(
                  state.uri.queryParameters,
                );
                params['site'] = site.id;
                context.goInPlace(
                  Uri(path: currentPath, queryParameters: params).toString(),
                );
              } else {
                context.push('/sites/${site.id}');
              }
            },
    );
  }

  /// Bottom time for the header, following the viewed source like the other
  /// stats. A source's bottom time is derived from its own profile, never
  /// read from its duration, which is the runtime it measured (issue #2421).
  /// Falls back to the dive's bottom time when the source has no profile
  /// that yields one.
  String _formatBottomTimeForSource(
    WidgetRef ref,
    Dive dive,
    DiveDataSource? activeSource,
  ) {
    int? seconds;
    if (activeSource != null) {
      final points = ref
          .watch(sourceProfilesProvider(dive.id))
          .value?[activeSource.id]
          ?.points;
      if (points != null) {
        seconds = BottomTimeCalculator.secondsFromSamples([
          for (final p in points) (timestamp: p.timestamp, depth: p.depth),
        ], totalDurationSeconds: activeSource.duration);
      }
    }
    seconds ??= dive.bottomTime?.inSeconds;
    return DiveHeroHeader.formatBottomTimeSeconds(seconds);
  }

  /// Runtime for the active source: its entry/exit span when both are
  /// known, else the dive's own runtime.
  String _formatRuntimeForSource(Dive dive, DiveDataSource? activeSource) {
    if (activeSource?.entryTime != null && activeSource?.exitTime != null) {
      final span = activeSource!.exitTime!.difference(activeSource.entryTime!);
      return '${span.inMinutes} min';
    }
    return DiveHeroHeader.formatRuntime(dive);
  }
}
