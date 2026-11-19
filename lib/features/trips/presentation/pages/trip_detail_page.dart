import 'package:clock/clock.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import 'package:submersion/features/change_log/presentation/widgets/change_log_history_menu_item.dart';
import 'package:submersion/features/connections/domain/entities/connection_kind.dart';
import 'package:submersion/features/connections/domain/entities/node_ref.dart';
import 'package:submersion/features/connections/presentation/widgets/open_in_connections.dart';
import 'package:submersion/core/constants/feature_flags.dart';
import 'package:submersion/core/data/visibility/shared_item_policy.dart';
import 'package:submersion/core/providers/provider.dart';
import 'package:submersion/core/utils/unit_formatter.dart';
import 'package:submersion/core/router/pushed_route.dart';
import 'package:submersion/features/dive_log/presentation/navigation/open_dive_list.dart';
import 'package:submersion/features/dive_log/presentation/providers/dive_providers.dart';
import 'package:submersion/features/divers/presentation/providers/diver_providers.dart';
import 'package:submersion/features/media/presentation/providers/lightroom_providers.dart';
import 'package:submersion/features/settings/presentation/providers/settings_providers.dart';
import 'package:submersion/features/trips/domain/entities/trip.dart';
import 'package:submersion/features/trips/domain/services/trip_day_notes.dart';
import 'package:submersion/features/trips/presentation/helpers/side_trip_delete_lines.dart';
import 'package:submersion/features/trips/presentation/helpers/trip_edit_navigation.dart';
import 'package:submersion/features/trips/presentation/helpers/trip_scan_actions.dart';
import 'package:submersion/features/trips/presentation/providers/side_trip_providers.dart';
import 'package:submersion/features/trips/presentation/providers/trip_providers.dart';
import 'package:submersion/features/trips/presentation/widgets/dive_assignment_dialog.dart';
import 'package:submersion/features/trips/presentation/widgets/part_of_trip_link.dart';
import 'package:submersion/features/trips/presentation/widgets/story/trip_story_view.dart';
import 'package:submersion/features/trips/presentation/widgets/trip_detail_tabs.dart';
import 'package:submersion/l10n/l10n_extension.dart';
import 'package:submersion/shared/widgets/shared_items/shared_by_banner.dart';
import 'package:submersion/shared/widgets/shared_items/shared_item_dialogs.dart';
import 'package:submersion/features/documents/domain/entities/document.dart';
import 'package:submersion/features/documents/presentation/editing/record_document_links_sitting.dart';
import 'package:submersion/features/trips/data/services/trip_edit_save_service.dart';
import 'package:submersion/features/trips/presentation/editing/trip_card_ids.dart';
import 'package:submersion/features/trips/presentation/editing/trip_card_slots.dart';
import 'package:submersion/features/trips/presentation/editing/trip_edit_cards.dart';
import 'package:submersion/features/trips/presentation/editing/trip_header_card_editor.dart';
import 'package:submersion/features/trips/presentation/editing/trip_itinerary_sitting.dart';
import 'package:submersion/features/trips/presentation/editing/trip_overview_card_editors.dart';
import 'package:submersion/features/trips/presentation/editing/trip_vessel_sitting.dart';
import 'package:submersion/features/trips/presentation/providers/liveaboard_providers.dart';
import 'package:submersion/shared/widgets/record_editing/add_strip.dart';
import 'package:submersion/shared/widgets/record_editing/edit_card.dart';
import 'package:submersion/shared/widgets/record_editing/edit_session.dart';
import 'package:submersion/shared/widgets/record_editing/record_card_frame.dart';
import 'package:submersion/shared/widgets/record_editing/record_edit_host.dart';
import 'package:submersion/shared/widgets/record_editing/record_edit_tabs.dart';
import 'package:submersion/shared/widgets/record_editing/record_open_unlocked.dart';
import 'package:submersion/shared/widgets/record_editing/record_operation_gate.dart';
import 'package:submersion/shared/widgets/record_editing/record_pane_row.dart';
import 'package:submersion/shared/widgets/record_editing/unlock_record_editing_flag.dart';

part 'trip_detail_page_editing.dart';
part 'trip_detail_page_menu.dart';

/// A trip's page: six tabs under its name. Behind phase 3's switch
/// ([unlockEditing]) it opens locked and edits in place (issue #4527): its
/// cards, on every tab, are held in one sitting and written by one Save.
class TripDetailPage extends ConsumerStatefulWidget {
  final String tripId;
  final bool embedded;
  final VoidCallback? onDeleted;

  /// Whether the page edits in place: phase 3's switch, a parameter so a
  /// test can turn it on.
  final bool unlockEditing;

  /// Opens unlocked, as the old edit address asks (`?mode=edit`).
  final bool openUnlocked;

  /// Told when a sitting the page opened unlocked ends: the list pane's
  /// edit returns to the trip in view.
  final VoidCallback? onSittingEnded;

  /// The card a page opened unlocked opens at, as the form opened at a
  /// section (`section=planning` or `section=notes`).
  final TripEditSection? openSection;

  /// The day whose note a page opened unlocked opens at: the story shows
  /// that day with its Day plan open (`noteDate`, `noteDay`).
  final TripNoteDay? openNoteDay;

  const TripDetailPage({
    super.key,
    required this.tripId,
    this.embedded = false,
    this.onDeleted,
    this.unlockEditing = kUnlockRecordEditing,
    this.openUnlocked = false,
    this.onSittingEnded,
    this.openSection,
    this.openNoteDay,
  });

  @override
  ConsumerState<TripDetailPage> createState() => _TripDetailPageState();
}

class _TripDetailPageState extends ConsumerState<TripDetailPage>
    with
        SingleTickerProviderStateMixin,
        RecordEditHost<TripDetailPage, Trip>,
        RecordOpenUnlocked<TripDetailPage, Trip>,
        RecordEditTabs<TripDetailPage, Trip>,
        _TripDetailPageEditing {
  bool _hasRedirected = false;

  /// The page's tabs, here so the sitting knows the tab in view and can
  /// bring another forward (a card refused at Save).
  @override
  late final TabController tabController = TabController(
    length: TripDetailTab.values.length,
    vsync: this,
  )..addListener(_onTabChanged);

  /// Which page of the Overview's story shows, here so a link can open the
  /// story at a day.
  final _storySelection = ValueNotifier<TripStorySelection?>(null);

  /// Whether the card the address names has been opened, or tried.
  bool _openedAtCard = false;

  /// Opens the card the address names, once, after the page has opened
  /// unlocked (which happens after this frame).
  void _openAtCardOnce() {
    if (_openedAtCard || !widget.openUnlocked) return;
    final noteDay = widget.openNoteDay;
    final section = widget.openSection;
    if (noteDay == null && section == null) return;
    _openedAtCard = true;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      final controller = maybeEditController;
      if (controller == null || !controller.isUnlocked) return;
      tabController.index = TripDetailTab.overview.index;
      if (noteDay != null) {
        _storySelection.value = TripStorySelection.day(noteDay.date);
        controller.openCard(TripCardId.notes.name);
      } else if (section == TripEditSection.planning) {
        controller.openCard(TripCardId.plan.name);
      } else {
        controller.openCard(TripCardId.notes.name);
      }
    });
  }

  void _onTabChanged() {
    // The strip offers the cards of the tab in view.
    if (mounted && hostsEditing) setState(() {});
  }

  @override
  void didUpdateWidget(TripDetailPage oldWidget) {
    super.didUpdateWidget(oldWidget);
    // The master-detail pane reuses this page for the next trip, which opens
    // on its Overview, at the story's own opening page.
    if (oldWidget.tripId != widget.tripId) {
      tabController.index = 0;
      _storySelection.value = null;
    }
  }

  @override
  void dispose() {
    disposeEditing();
    tabController
      ..removeListener(_onTabChanged)
      ..dispose();
    _storySelection.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    // Desktop redirect: a root visit (deep link, sidebar) moves into the
    // master-detail split. A pushed page, opened from a dive's details
    // say, stays put: the redirect's go() would erase the page under it
    // and its back arrow (#3292).
    if (!_hasRedirected &&
        shouldRedirectToMasterDetail(
          context,
          embedded: widget.embedded,
          viewMode: ref.read(tripListViewModeProvider),
        )) {
      _hasRedirected = true;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) {
          context.go('/trips?selected=${widget.tripId}');
        }
      });
    }

    final tripAsync = ref.watch(tripWithStatsProvider(widget.tripId));
    if (hostsEditing) followStored(tripByIdProvider(widget.tripId));

    return tripAsync.when(
      data: (tripWithStats) {
        if (!hostsEditing) {
          return _TripDetailContent(
            tripWithStats: tripWithStats,
            embedded: widget.embedded,
            onDeleted: widget.onDeleted,
          );
        }
        final stored = tripWithStats.trip;
        openUnlockedOnce(stored);
        _openAtCardOnce();
        final shown = shownRecord(stored);
        return _TripDetailContent(
          tripWithStats: tripWithStats,
          shown: shown,
          embedded: widget.embedded,
          onDeleted: widget.onDeleted,
          host: this,
        );
      },
      loading: () => widget.embedded
          ? const Center(child: CircularProgressIndicator())
          : Scaffold(
              appBar: AppBar(
                title: Text(context.l10n.trips_detail_appBar_title),
              ),
              body: const Center(child: CircularProgressIndicator()),
            ),
      // The repository logs the failure; the diver gets a plain line.
      error: (_, _) => widget.embedded
          ? Center(child: Text(context.l10n.trips_detail_error_loading))
          : Scaffold(
              appBar: AppBar(
                title: Text(context.l10n.trips_detail_appBar_title),
              ),
              body: Center(
                child: Text(context.l10n.trips_detail_error_loading),
              ),
            ),
    );
  }
}

class _TripDetailContent extends ConsumerWidget {
  final TripWithStats tripWithStats;

  /// The trip the cards show: the sitting's while unlocked; null shows the
  /// stored one.
  final Trip? shown;
  final bool embedded;
  final VoidCallback? onDeleted;

  /// The page, where it edits in place.
  final _TripDetailPageState? host;

  const _TripDetailContent({
    required this.tripWithStats,
    this.shown,
    this.embedded = false,
    this.onDeleted,
    this.host,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final stored = tripWithStats.trip;
    final trip = shown ?? stored;
    final host = this.host;
    // One layout for every trip type (#2845): the tab row under the "Shared
    // by" banner, embedded under the master-detail header or in a Scaffold.
    // Who the trip is shared with is shown and changed on the edit page
    // only (#3766).
    Widget body = Column(
      children: [
        SharedByBanner(
          kind: SharedItemKind.trip,
          itemId: trip.id,
          ownerId: trip.diverId,
        ),
        // A side trip names its larger trip (issue #3658).
        PartOfTripLink(
          tripId: trip.id,
          padding: const EdgeInsets.fromLTRB(16, 4, 16, 0),
        ),
        // The header block, on every tab, where the page edits in place:
        // the trip's values nothing else shows, and its editor (issue
        // #4527).
        if (host != null)
          host
              ._slots(trip, stored)
              .frame(TripCardId.header, TripHeaderRows(trip: trip)),
        Expanded(
          child: TripDetailTabs(
            tripWithStats: tripWithStats,
            controller: host?.tabController,
            storySelection: host?._storySelection,
            // In the master-detail pane the edit stays in the pane (#2880).
            onEditPlan: () => openTripEdit(
              context,
              trip.id,
              embedded: embedded,
              section: TripEditSection.planning,
            ),
            // Where the page edits in place, the day's note is its Day
            // plan, opened where it is, unlocking first when locked.
            onEditDayNote: host != null
                ? (day) => host._openCard(TripCardId.notes, trip)
                : (day) => openTripEdit(
                    context,
                    trip.id,
                    embedded: embedded,
                    noteDay: day,
                  ),
          ),
        ),
      ],
    );
    if (host != null) {
      body = TripCardSlotsScope(slots: host._slots(trip, stored), child: body);
    }

    if (embedded) {
      final header = _buildEmbeddedHeader(context, ref, trip);
      if (host != null) {
        return host.editPane(
          header: RecordPaneRow(
            locked: header,
            unlocked: host.isSittingOpen
                ? host.editingPaneRow(
                    stored,
                    menu: _buildMoreMenu(context, ref, trip),
                  )
                : null,
          ),
          shown: trip,
          content: body,
        );
      }
      return Column(
        children: [
          header,
          Expanded(child: body),
        ],
      );
    }

    final bar = AppBar(
      title: Text(trip.name),
      actions: _buildAppBarActions(context, ref, trip),
    );
    if (host != null) {
      return host.editScaffold(
        record: stored,
        shown: trip,
        lockedBar: bar,
        unlockedActions: [_buildMoreMenu(context, ref, trip)],
        content: body,
      );
    }
    return Scaffold(appBar: bar, body: body);
  }

  /// The page's AppBar actions.
  List<Widget> _buildAppBarActions(
    BuildContext context,
    WidgetRef ref,
    Trip trip,
  ) {
    final host = this.host;
    return [
      IconButton(
        icon: const Icon(Icons.map_outlined),
        tooltip: context.l10n.trips_detail_tooltip_viewOnMap,
        onPressed: () {
          openDiveList(
            context,
            ref,
            DiveFilterState(tripId: trip.id),
            map: true,
          );
        },
      ),
      if (host != null) host.lockButton(trip),
      IconButton(
        icon: const Icon(Icons.edit),
        tooltip: context.l10n.trips_detail_tooltip_edit,
        // Where the page edits in place, Edit unlocks it as the lock does.
        onPressed: host != null
            ? () => host.editController.unlock(trip)
            : () => openTripEdit(context, trip.id, embedded: false),
      ),
      _buildMoreMenu(context, ref, trip),
    ];
  }

  Widget _buildEmbeddedHeader(BuildContext context, WidgetRef ref, Trip trip) {
    final colorScheme = Theme.of(context).colorScheme;
    final units = ref.watch(unitFormatterProvider);
    final host = this.host;

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
                  '${units.formatMonthDay(trip.startDate)} - ${units.formatMonthDay(trip.endDate)}',
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
              openDiveList(
                context,
                ref,
                DiveFilterState(tripId: trip.id),
                map: true,
              );
            },
          ),
          if (host != null) host.lockButton(trip, compact: true),
          IconButton(
            icon: const Icon(Icons.edit_outlined, size: 20),
            visualDensity: VisualDensity.compact,
            onPressed: host != null
                ? () => host.editController.unlock(trip)
                : () => openTripEdit(context, trip.id, embedded: true),
            tooltip: context.l10n.trips_detail_tooltip_editShort,
          ),
          _buildMoreMenu(context, ref, trip),
        ],
      ),
    );
  }
}
