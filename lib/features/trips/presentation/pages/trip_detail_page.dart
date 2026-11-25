import 'package:clock/clock.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import 'package:submersion/features/change_log/presentation/widgets/change_log_history_menu_item.dart';
import 'package:submersion/features/connections/domain/entities/connection_kind.dart';
import 'package:submersion/features/connections/domain/entities/node_ref.dart';
import 'package:submersion/features/connections/presentation/widgets/open_in_connections.dart';
import 'package:submersion/core/data/visibility/shared_item_policy.dart';
import 'package:submersion/core/providers/provider.dart';
import 'package:submersion/core/utils/unit_formatter.dart';
import 'package:submersion/core/router/pushed_route.dart';
import 'package:submersion/features/dive_log/presentation/navigation/open_dive_list.dart';
import 'package:submersion/features/dive_log/presentation/providers/dive_providers.dart';
import 'package:submersion/features/divers/presentation/providers/diver_providers.dart';
import 'package:submersion/features/settings/presentation/providers/settings_providers.dart';
import 'package:submersion/features/divers/presentation/providers/new_record_diver.dart';
import 'package:submersion/features/trips/data/services/trip_edit_save_service.dart';
import 'package:submersion/features/trips/domain/entities/trip.dart';
import 'package:submersion/features/trips/domain/entities/trip_story.dart';
import 'package:submersion/features/trips/domain/services/trip_draft.dart';
import 'package:submersion/features/trips/domain/services/trip_story_builder.dart';
import 'package:submersion/features/trips/domain/services/trip_day_notes.dart';
import 'package:submersion/features/trips/presentation/helpers/side_trip_delete_lines.dart';
import 'package:submersion/features/trips/presentation/helpers/trip_edit_navigation.dart';
import 'package:submersion/features/trips/presentation/providers/side_trip_providers.dart';
import 'package:submersion/features/trips/presentation/providers/trip_providers.dart';
import 'package:submersion/features/trips/presentation/pages/trip_edit_routes.dart';
import 'package:submersion/features/trips/presentation/widgets/overview/trip_prepare_overview.dart';
import 'package:submersion/features/trips/presentation/widgets/part_of_trip_link.dart';
import 'package:submersion/features/trips/presentation/widgets/story/trip_story_view.dart';
import 'package:submersion/features/trips/presentation/widgets/trip_detail_tabs.dart';
import 'package:submersion/l10n/l10n_extension.dart';
import 'package:submersion/shared/widgets/shared_items/shared_by_banner.dart';
import 'package:submersion/shared/widgets/shared_items/shared_item_dialogs.dart';
import 'package:submersion/features/trips/presentation/editing/trip_card_ids.dart';
import 'package:submersion/features/trips/presentation/editing/trip_card_slots.dart';
import 'package:submersion/features/trips/presentation/editing/trip_edit_cards.dart';
import 'package:submersion/features/trips/presentation/editing/trip_new_sitting.dart';
import 'package:submersion/features/trips/presentation/editing/trip_overview_card_editors.dart';
import 'package:submersion/features/trips/presentation/editing/trip_sitting_host.dart';
import 'package:submersion/shared/widgets/record_editing/add_strip.dart';
import 'package:submersion/shared/widgets/record_editing/edit_card.dart';
import 'package:submersion/shared/widgets/record_editing/edit_session.dart';
import 'package:submersion/shared/widgets/record_editing/record_card_frame.dart';
import 'package:submersion/shared/widgets/record_editing/record_creating.dart';
import 'package:submersion/shared/widgets/record_editing/record_edit_host.dart';
import 'package:submersion/shared/widgets/record_editing/record_edit_tabs.dart';
import 'package:submersion/shared/widgets/record_editing/record_open_unlocked.dart';
import 'package:submersion/shared/widgets/record_editing/record_operation_gate.dart';
import 'package:submersion/shared/widgets/record_editing/record_pane_row.dart';

part 'trip_detail_page_creating.dart';
part 'trip_detail_page_editing.dart';
part 'trip_detail_page_menu.dart';

/// A trip's page: six tabs under its name. It opens locked and edits in
/// place (issue #4527): its cards, on every tab, are held in one sitting and
/// written by one Save.
class TripDetailPage extends ConsumerStatefulWidget {
  final String tripId;
  final bool embedded;
  final VoidCallback? onDeleted;

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

  /// A trip not yet created, with what a trip made from selected dives
  /// suggests ([TripDraft]), when the page is one (issue #4527, plan 11).
  final ({TripDraft? draft})? newTrip;

  /// The pane's own, for a new trip: told its id once it is created.
  final void Function(String id)? onCreated;

  /// The pane's own, for a new trip: told when it leaves uncreated.
  final VoidCallback? onCreateCancelled;

  const TripDetailPage({
    super.key,
    required this.tripId,
    this.embedded = false,
    this.onDeleted,
    this.openUnlocked = false,
    this.onSittingEnded,
    this.openSection,
    this.openNoteDay,
  }) : newTrip = null,
       onCreated = null,
       onCreateCancelled = null;

  /// A new trip's page (issue #4527, phase 3, plan 11): it opens unlocked
  /// on a trip not yet created, its Overview in the prepare shape and no
  /// other tab, with what [draft] suggests as changes.
  const TripDetailPage.newTrip({
    super.key,
    TripDraft? draft,
    this.embedded = false,
    this.onCreated,
    this.onCreateCancelled,
  }) : newTrip = (draft: draft),
       tripId = '',
       onDeleted = null,
       openUnlocked = false,
       onSittingEnded = null,
       openSection = null,
       openNoteDay = null;

  @override
  ConsumerState<TripDetailPage> createState() => _TripDetailPageState();
}

class _TripDetailPageState extends ConsumerState<TripDetailPage>
    with
        SingleTickerProviderStateMixin,
        RecordEditHost<TripDetailPage, Trip>,
        RecordOpenUnlocked<TripDetailPage, Trip>,
        RecordEditTabs<TripDetailPage, Trip>,
        TripSittingHost<TripDetailPage>,
        _TripDetailPageEditing,
        RecordCreating<TripDetailPage, Trip>,
        _TripDetailPageCreating {
  bool _hasRedirected = false;

  /// The page's tabs, here so the sitting knows the tab in view and can
  /// bring another forward (a card refused at Save).
  @override
  late final TabController tabController;

  @override
  void initState() {
    super.initState();
    tabController = TabController(
      length: TripDetailTab.values.length,
      vsync: this,
    )..addListener(_onTabChanged);
  }

  /// Which page of the Overview's story shows, here so a link can open the
  /// story at a day.
  final _storySelection = ValueNotifier<TripStorySelection?>(null);

  @override
  ValueNotifier<TripStorySelection?> get storySelection => _storySelection;

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
        return;
      }
      // On the story, the Plan and the whole notes are on its Trip page.
      _storySelection.value = const TripStorySelection.trip();
      controller.openCard(
        section == TripEditSection.planning
            ? TripCardId.plan.name
            : TripCardId.notes.name,
      );
    });
  }

  void _onTabChanged() {
    // The strip offers the cards of the tab in view.
    if (mounted) setState(() {});
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
    // A page handed another address opens at the card that one names.
    if (oldWidget.tripId != widget.tripId ||
        oldWidget.openUnlocked != widget.openUnlocked ||
        oldWidget.openSection != widget.openSection ||
        oldWidget.openNoteDay != widget.openNoteDay) {
      _openedAtCard = false;
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
    if (isCreating) {
      final seed = newRecordSeed;
      return newRecordWaiting(context) ??
          _buildNewTrip(context, shownRecord(seed!), seed);
    }
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
      // An edit address keeps asking for edit mode, at its card, in the
      // pane (issue #4527).
      final location = tripPaneLocation(
        widget.tripId,
        openUnlocked: widget.openUnlocked,
        section: widget.openSection,
        noteDay: widget.openNoteDay,
      );
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) context.go(location);
      });
    }

    final tripAsync = ref.watch(tripWithStatsProvider(widget.tripId));
    followStored(tripByIdProvider(widget.tripId));

    return tripAsync.when(
      data: (tripWithStats) {
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

  /// The trip the cards show: the sitting's while unlocked.
  final Trip shown;
  final bool embedded;
  final VoidCallback? onDeleted;

  /// The page, which edits in place.
  final _TripDetailPageState host;

  const _TripDetailContent({
    required this.tripWithStats,
    required this.shown,
    required this.host,
    this.embedded = false,
    this.onDeleted,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final stored = tripWithStats.trip;
    final trip = shown;
    // One layout for every trip type (#2845): the tab row under the "Shared
    // by" banner, embedded under the master-detail header or in a Scaffold.
    // The header block, with who the trip is shared with (#3766, issue
    // #4527), is on the Overview with the rest of the trip summary, so the
    // tabs start right under the banners (issue #4927).
    final slots = host._slots(trip, stored);
    final body = TripCardSlotsScope(
      slots: slots,
      child: Column(
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
          Expanded(
            child: TripDetailTabs(
              tripWithStats: tripWithStats,
              controller: host.tabController,
              storySelection: host._storySelection,
              // The day's note is its Day plan, opened where it is,
              // unlocking first when locked.
              onEditDayNote: (day) => host._openCard(TripCardId.notes, trip),
            ),
          ),
        ],
      ),
    );

    if (embedded) {
      return host.editPane(
        header: RecordPaneRow(
          locked: _buildEmbeddedHeader(context, ref, trip),
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

    final bar = AppBar(
      title: Text(trip.name),
      actions: _buildAppBarActions(context, ref, trip),
    );
    return host.editScaffold(
      record: stored,
      shown: trip,
      lockedBar: bar,
      unlockedActions: [_buildMoreMenu(context, ref, trip)],
      content: body,
    );
  }

  /// The page's AppBar actions.
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
          openDiveList(
            context,
            ref,
            DiveFilterState(tripId: trip.id),
            map: true,
          );
        },
      ),
      host.lockButton(trip),
      _buildMoreMenu(context, ref, trip),
    ];
  }

  Widget _buildEmbeddedHeader(BuildContext context, WidgetRef ref, Trip trip) {
    final colorScheme = Theme.of(context).colorScheme;
    final units = ref.watch(unitFormatterProvider);

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
          host.lockButton(trip, compact: true),
          _buildMoreMenu(context, ref, trip),
        ],
      ),
    );
  }
}
