import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

import 'package:submersion/core/utils/unit_formatter.dart';
import 'package:submersion/features/dive_log/presentation/providers/dive_providers.dart';
import 'package:submersion/features/settings/presentation/providers/settings_providers.dart';
import 'package:submersion/features/trips/domain/entities/trip.dart';
import 'package:submersion/features/trips/presentation/providers/trip_providers.dart';
import 'package:submersion/features/trips/presentation/widgets/trip_itinerary_tab.dart';
import 'package:submersion/features/trips/presentation/widgets/trip_overview_tab.dart';
import 'package:submersion/features/trips/presentation/widgets/trip_photo_section.dart';
import 'package:submersion/l10n/l10n_extension.dart';
import 'package:submersion/shared/widgets/master_detail/responsive_breakpoints.dart';

class TripDetailPage extends ConsumerStatefulWidget {
  final String tripId;
  final bool embedded;
  final VoidCallback? onDeleted;

  const TripDetailPage({
    super.key,
    required this.tripId,
    this.embedded = false,
    this.onDeleted,
  });

  @override
  ConsumerState<TripDetailPage> createState() => _TripDetailPageState();
}

class _TripDetailPageState extends ConsumerState<TripDetailPage> {
  bool _hasRedirected = false;

  @override
  Widget build(BuildContext context) {
    // Desktop redirect: If accessed directly (not embedded), redirect to master-detail view
    if (!widget.embedded &&
        !_hasRedirected &&
        ResponsiveBreakpoints.isMasterDetail(context)) {
      _hasRedirected = true;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) {
          context.go('/trips?selected=${widget.tripId}');
        }
      });
    }

    final tripAsync = ref.watch(tripWithStatsProvider(widget.tripId));

    return tripAsync.when(
      data: (tripWithStats) => _TripDetailContent(
        tripWithStats: tripWithStats,
        embedded: widget.embedded,
        onDeleted: widget.onDeleted,
      ),
      loading: () => widget.embedded
          ? const Center(child: CircularProgressIndicator())
          : Scaffold(
              appBar: AppBar(
                title: Text(context.l10n.trips_detail_appBar_title),
              ),
              body: const Center(child: CircularProgressIndicator()),
            ),
      error: (error, stack) => widget.embedded
          ? Center(child: Text('${context.l10n.common_label_error}: $error'))
          : Scaffold(
              appBar: AppBar(
                title: Text(context.l10n.trips_detail_appBar_title),
              ),
              body: Center(
                child: Text('${context.l10n.common_label_error}: $error'),
              ),
            ),
    );
  }
}

class _TripDetailContent extends ConsumerWidget {
  final TripWithStats tripWithStats;
  final bool embedded;
  final VoidCallback? onDeleted;

  const _TripDetailContent({
    required this.tripWithStats,
    this.embedded = false,
    this.onDeleted,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final trip = tripWithStats.trip;

    if (trip.isLiveaboard) {
      return _buildLiveaboardLayout(context, ref, trip);
    }

    return _buildStandardLayout(context, ref, trip);
  }

  /// Standard single-scroll layout for non-liveaboard trips.
  Widget _buildStandardLayout(BuildContext context, WidgetRef ref, Trip trip) {
    final body = TripOverviewTab(tripWithStats: tripWithStats);

    if (embedded) {
      return Column(
        children: [
          _buildEmbeddedHeader(context, ref, trip),
          Expanded(child: body),
        ],
      );
    }

    return Scaffold(
      appBar: AppBar(
        title: Text(trip.name),
        actions: _buildAppBarActions(context, ref, trip),
      ),
      body: body,
    );
  }

  /// Tabbed layout for liveaboard trips with 4 tabs:
  /// Overview, Itinerary, Photos, Dives.
  Widget _buildLiveaboardLayout(
    BuildContext context,
    WidgetRef ref,
    Trip trip,
  ) {
    final tabbedBody = DefaultTabController(
      length: 4,
      child: Column(
        children: [
          Material(
            color: Theme.of(context).colorScheme.surface,
            child: TabBar(
              tabs: [
                Tab(text: context.l10n.trips_detail_tab_overview),
                Tab(text: context.l10n.trips_detail_tab_itinerary),
                Tab(text: context.l10n.trips_detail_tab_photos),
                Tab(text: context.l10n.trips_detail_tab_dives),
              ],
            ),
          ),
          Expanded(
            child: TabBarView(
              children: [
                TripOverviewTab(tripWithStats: tripWithStats),
                TripItineraryTab(tripId: trip.id),
                _buildPhotosTab(context, ref, trip),
                _buildDivesTab(context, ref, trip),
              ],
            ),
          ),
        ],
      ),
    );

    if (embedded) {
      return Column(
        children: [
          _buildEmbeddedHeader(context, ref, trip),
          Expanded(child: tabbedBody),
        ],
      );
    }

    return Scaffold(
      appBar: AppBar(
        title: Text(trip.name),
        actions: _buildAppBarActions(context, ref, trip),
      ),
      body: tabbedBody,
    );
  }

  /// Shared AppBar actions for both standard and liveaboard layouts.
  List<Widget> _buildAppBarActions(
    BuildContext context,
    WidgetRef ref,
    Trip trip,
  ) {
    return [
      IconButton(
        icon: const Icon(Icons.map_outlined),
        tooltip: context.l10n.trips_detail_tooltip_viewOnMap,
        onPressed: () {
          ref.read(diveFilterProvider.notifier).state = DiveFilterState(
            tripId: trip.id,
          );
          context.go('/dives?view=map');
        },
      ),
      IconButton(
        icon: const Icon(Icons.edit),
        tooltip: context.l10n.trips_detail_tooltip_edit,
        onPressed: () => context.push('/trips/${trip.id}/edit'),
      ),
      _buildMoreMenu(context, ref, trip),
    ];
  }

  /// Standalone photos tab for the liveaboard tabbed layout.
  Widget _buildPhotosTab(BuildContext context, WidgetRef ref, Trip trip) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: TripPhotoSection(tripId: trip.id),
    );
  }

  /// Standalone dives tab for the liveaboard tabbed layout.
  /// Shows all dives (not limited to 5 like the overview).
  Widget _buildDivesTab(BuildContext context, WidgetRef ref, Trip trip) {
    final divesAsync = ref.watch(divesForTripProvider(trip.id));
    final settings = ref.watch(settingsProvider);
    final units = UnitFormatter(settings);
    final theme = Theme.of(context);
    final dateFormat = DateFormat.MMMd();

    return divesAsync.when(
      data: (dives) {
        if (dives.isEmpty) {
          return Center(child: Text(context.l10n.trips_detail_dives_empty));
        }
        final sortedDives = List.of(dives)
          ..sort((a, b) => a.dateTime.compareTo(b.dateTime));
        return ListView.builder(
          padding: const EdgeInsets.all(16),
          itemCount: sortedDives.length,
          itemBuilder: (context, index) {
            final dive = sortedDives[index];
            return InkWell(
              onTap: () => context.push('/dives/${dive.id}'),
              borderRadius: BorderRadius.circular(8),
              child: Padding(
                padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 4),
                child: Row(
                  children: [
                    Container(
                      width: 40,
                      height: 40,
                      decoration: BoxDecoration(
                        color: theme.colorScheme.primaryContainer,
                        borderRadius: BorderRadius.circular(8),
                      ),
                      alignment: Alignment.center,
                      child: Text(
                        '#${dive.diveNumber ?? '-'}',
                        style: theme.textTheme.labelMedium?.copyWith(
                          color: theme.colorScheme.onPrimaryContainer,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            dive.site?.name ??
                                context.l10n.trips_detail_dives_unknownSite,
                            style: theme.textTheme.bodyMedium?.copyWith(
                              fontWeight: FontWeight.w500,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                          const SizedBox(height: 2),
                          Text(
                            dateFormat.format(dive.dateTime),
                            style: theme.textTheme.bodySmall?.copyWith(
                              color: theme.colorScheme.onSurfaceVariant,
                            ),
                          ),
                        ],
                      ),
                    ),
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: [
                        if (dive.maxDepth != null)
                          Text(
                            units.formatDepth(dive.maxDepth),
                            style: theme.textTheme.bodyMedium?.copyWith(
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        if (dive.bottomTime != null)
                          Text(
                            '${dive.bottomTime!.inMinutes}min',
                            style: theme.textTheme.bodySmall?.copyWith(
                              color: theme.colorScheme.onSurfaceVariant,
                            ),
                          ),
                      ],
                    ),
                    const SizedBox(width: 4),
                    Icon(
                      Icons.chevron_right,
                      color: theme.colorScheme.onSurfaceVariant,
                      size: 20,
                    ),
                  ],
                ),
              ),
            );
          },
        );
      },
      loading: () => const Center(child: CircularProgressIndicator.adaptive()),
      error: (e, _) =>
          Center(child: Text(context.l10n.trips_detail_dives_errorLoading)),
    );
  }

  Widget _buildEmbeddedHeader(BuildContext context, WidgetRef ref, Trip trip) {
    final colorScheme = Theme.of(context).colorScheme;
    final dateFormat = DateFormat.MMMd();

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      decoration: BoxDecoration(
        color: colorScheme.surface,
        border: Border(
          bottom: BorderSide(color: colorScheme.outlineVariant, width: 1),
        ),
      ),
      child: Row(
        children: [
          CircleAvatar(
            radius: 20,
            backgroundColor: colorScheme.primaryContainer,
            child: Icon(
              trip.isLiveaboard ? Icons.sailing : Icons.flight_takeoff,
              size: 20,
              color: colorScheme.onPrimaryContainer,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  trip.name,
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w600,
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
                Text(
                  '${dateFormat.format(trip.startDate)} - ${dateFormat.format(trip.endDate)}',
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: colorScheme.onSurfaceVariant,
                  ),
                ),
              ],
            ),
          ),
          IconButton(
            icon: const Icon(Icons.map_outlined, size: 20),
            visualDensity: VisualDensity.compact,
            tooltip: context.l10n.trips_detail_tooltip_viewOnMap,
            onPressed: () {
              ref.read(diveFilterProvider.notifier).state = DiveFilterState(
                tripId: trip.id,
              );
              context.go('/dives?view=map');
            },
          ),
          IconButton(
            icon: const Icon(Icons.edit_outlined, size: 20),
            visualDensity: VisualDensity.compact,
            onPressed: () {
              final state = GoRouterState.of(context);
              final currentPath = state.uri.path;
              context.go('$currentPath?selected=${trip.id}&mode=edit');
            },
            tooltip: context.l10n.trips_detail_tooltip_editShort,
          ),
          _buildMoreMenu(context, ref, trip),
        ],
      ),
    );
  }

  Widget _buildMoreMenu(BuildContext context, WidgetRef ref, Trip trip) {
    return PopupMenuButton<String>(
      tooltip: context.l10n.trips_detail_tooltip_moreOptions,
      onSelected: (value) async {
        if (value == 'delete') {
          final confirmed = await _showDeleteConfirmation(context);
          if (confirmed && context.mounted) {
            await ref
                .read(tripListNotifierProvider.notifier)
                .deleteTrip(trip.id);
            if (context.mounted) {
              if (embedded) {
                onDeleted?.call();
              } else {
                context.pop();
              }
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Text(context.l10n.trips_detail_snackBar_deleted),
                ),
              );
            }
          }
        } else if (value == 'export') {
          _showExportOptions(context, ref);
        }
      },
      itemBuilder: (context) => [
        PopupMenuItem(
          value: 'export',
          child: Row(
            children: [
              const Icon(Icons.file_download),
              const SizedBox(width: 8),
              Text(context.l10n.trips_detail_action_export),
            ],
          ),
        ),
        PopupMenuItem(
          value: 'delete',
          child: Row(
            children: [
              Icon(Icons.delete, color: Theme.of(context).colorScheme.error),
              const SizedBox(width: 8),
              Text(
                context.l10n.trips_detail_action_delete,
                style: TextStyle(color: Theme.of(context).colorScheme.error),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Future<bool> _showDeleteConfirmation(BuildContext context) async {
    return await showDialog<bool>(
          context: context,
          builder: (context) => AlertDialog(
            title: Text(context.l10n.trips_detail_dialog_deleteTitle),
            content: Text(
              context.l10n.trips_detail_dialog_deleteContent(
                tripWithStats.trip.name,
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.of(context).pop(false),
                child: Text(context.l10n.trips_detail_dialog_cancel),
              ),
              FilledButton(
                onPressed: () => Navigator.of(context).pop(true),
                style: FilledButton.styleFrom(
                  backgroundColor: Theme.of(context).colorScheme.error,
                ),
                child: Text(context.l10n.trips_detail_dialog_deleteConfirm),
              ),
            ],
          ),
        ) ??
        false;
  }

  void _showExportOptions(BuildContext context, WidgetRef ref) {
    showModalBottomSheet(
      context: context,
      builder: (context) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Semantics(
              button: true,
              label:
                  '${context.l10n.trips_detail_export_csv_title}. ${context.l10n.trips_detail_export_csv_subtitle}',
              child: ListTile(
                leading: const Icon(Icons.description),
                title: Text(context.l10n.trips_detail_export_csv_title),
                subtitle: Text(context.l10n.trips_detail_export_csv_subtitle),
                onTap: () {
                  Navigator.pop(context);
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text(
                        context.l10n.trips_detail_export_csv_comingSoon,
                      ),
                    ),
                  );
                },
              ),
            ),
            Semantics(
              button: true,
              label:
                  '${context.l10n.trips_detail_export_pdf_title}. ${context.l10n.trips_detail_export_pdf_subtitle}',
              child: ListTile(
                leading: const Icon(Icons.picture_as_pdf),
                title: Text(context.l10n.trips_detail_export_pdf_title),
                subtitle: Text(context.l10n.trips_detail_export_pdf_subtitle),
                onTap: () {
                  Navigator.pop(context);
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text(
                        context.l10n.trips_detail_export_pdf_comingSoon,
                      ),
                    ),
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}
