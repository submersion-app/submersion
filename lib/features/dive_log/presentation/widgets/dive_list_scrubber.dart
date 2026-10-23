import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:submersion/core/constants/sort_options.dart';
import 'package:submersion/core/constants/units.dart';
import 'package:submersion/core/providers/provider.dart';
import 'package:submersion/core/services/logger_service.dart';
import 'package:submersion/core/theme/app_colors.dart';
import 'package:submersion/core/utils/unit_formatter.dart';
import 'package:submersion/features/dive_log/domain/entities/dive_scrubber_entry.dart';
import 'package:submersion/features/dive_log/domain/entities/dive_summary.dart';
import 'package:submersion/features/dive_log/presentation/helpers/dive_scrubber_details.dart';
import 'package:submersion/features/dive_log/presentation/helpers/dive_scrubber_labels.dart';
import 'package:submersion/features/dive_log/presentation/helpers/dive_scrubber_slots.dart';
import 'package:submersion/features/dive_log/presentation/providers/dive_providers.dart';
import 'package:submersion/features/dive_log/presentation/providers/dive_scrubber_providers.dart';
import 'package:submersion/features/dive_log/presentation/widgets/gas_colors.dart';
import 'package:submersion/features/divers/presentation/providers/diver_providers.dart';
import 'package:submersion/features/settings/presentation/providers/settings_providers.dart';
import 'package:submersion/l10n/arb/app_localizations.dart';
import 'package:submersion/l10n/l10n_extension.dart';
import 'package:submersion/shared/widgets/list_scrubber/list_scrubber.dart';
import 'package:submersion/shared/widgets/list_scrubber/scrubber_marker.dart';

final _log = LoggerService.forClass(DiveListScrubber);

/// The dive list's scrubber: every dive the list shows, labelled by the
/// active sort.
class DiveListScrubber extends ConsumerStatefulWidget {
  const DiveListScrubber({
    super.key,
    required this.controller,
    required this.loadedDives,
    required this.groupingEnabled,
    required this.collapsedTripIds,
    required this.onLand,
    required this.child,
    this.selectedDiveId,
  });

  final ScrollController controller;
  final List<DiveSummary> loadedDives;
  final bool groupingEnabled;
  final Set<String> collapsedTripIds;

  /// Shows [diveId], or the header of the collapsed trip holding it: at the
  /// top of the list when [toTop], otherwise scrolling only as far as it
  /// takes to show it whole. [context] sits below the list's keyboard
  /// navigator.
  final void Function(
    BuildContext context,
    String diveId, {
    required bool toTop,
  })
  onLand;

  /// The dive the detail pane shows, marked with a dot on the track.
  final String? selectedDiveId;
  final Widget child;

  @override
  ConsumerState<DiveListScrubber> createState() => _DiveListScrubberState();
}

/// The colours of the per-sort details: trip stripes and number gap ticks.
typedef _DetailColors = ({Color trip, Color gap});

_DetailColors _detailColors(BuildContext context) => (
  trip: Theme.of(context).colorScheme.tertiary.withValues(alpha: 0.7),
  gap: AppColors.warning,
);

class _DiveListScrubberState extends ConsumerState<DiveListScrubber> {
  bool _loading = false;
  int _drop = 0;
  late final StateController<bool> _scrubbing;

  List<DiveScrubberEntry>? _entries;
  bool? _grouping;
  Set<String>? _collapsed;
  DiveSortField? _field;
  SortDirection? _direction;
  DepthUnit? _depthUnit;
  DateFormatPreference? _dateFormat;
  String? _locale;
  int? _loadedCount;
  List<DiveScrubberSlot> _slots = const [];
  List<ScrubberMarker> _markers = const [];
  _DetailColors? _colors;
  List<ScrubberSegment> _segments = const [];
  List<ScrubberTick> _contextTicks = const [];
  List<ScrubberDensityBin> _density = const [];
  List<int> _favorites = const [];
  int _loadedSlotCount = 0;
  String? _selectedId;
  int? _selectedSlot;

  @override
  void initState() {
    super.initState();
    _scrubbing = ref.read(diveListScrubbingProvider.notifier);
  }

  @override
  void dispose() {
    final scrubbing = _scrubbing;
    Future.microtask(() {
      if (scrubbing.mounted) scrubbing.state = false;
    });
    super.dispose();
  }

  /// Recomputes the slots, favourite slots, markers, per-sort details,
  /// month bars, loaded slot count and selected slot only when what they are built from
  /// changes.
  void _refreshCache({
    required List<DiveScrubberEntry> entries,
    required DiveSortField field,
    required SortDirection direction,
    required UnitFormatter units,
    required AppLocalizations l10n,
    required String locale,
    required int loadedCount,
    required _DetailColors colors,
  }) {
    final slotsStale =
        !identical(entries, _entries) ||
        widget.groupingEnabled != _grouping ||
        !setEquals(widget.collapsedTripIds, _collapsed);
    if (slotsStale) {
      _slots = buildDiveScrubberSlots(
        entries: entries,
        groupingEnabled: widget.groupingEnabled,
        collapsedTripIds: widget.collapsedTripIds,
      );
      _favorites = diveScrubberFavoriteSlots(_slots);
    }
    final depthUnit = units.settings.depthUnit;
    final dateFormat = units.settings.dateFormat;
    if (slotsStale ||
        field != _field ||
        direction != _direction ||
        depthUnit != _depthUnit ||
        dateFormat != _dateFormat ||
        locale != _locale ||
        colors != _colors) {
      _markers = diveScrubberMarkers(
        _slots,
        field,
        direction: direction,
        units: units,
        l10n: l10n,
      );
      _segments = switch (field) {
        DiveSortField.date => [
          for (final run in diveScrubberTripRuns(_slots))
            ScrubberSegment(
              firstSlot: run.firstSlot,
              lastSlot: run.lastSlot,
              color: colors.trip,
            ),
        ],
        _ => const [],
      };
      _contextTicks = switch (field) {
        DiveSortField.depth => [
          for (final tick in diveScrubberGasSlots(entries, _slots))
            ScrubberTick(
              slot: tick.slot,
              color: switch (tick.gas) {
                DiveScrubberGas.air => GasColors.air,
                DiveScrubberGas.nitrox => GasColors.nitrox,
                DiveScrubberGas.trimix => GasColors.trimix,
              },
            ),
        ],
        DiveSortField.diveNumber => [
          for (final slot in diveScrubberGapSlots(
            entries,
            _slots,
            direction: direction,
          ))
            ScrubberTick(slot: slot, color: colors.gap),
        ],
        _ => const [],
      };
      _density = field == DiveSortField.date
          ? diveScrubberMonthBins(entries, _slots)
          : const [];
    }
    if (slotsStale || widget.selectedDiveId != _selectedId) {
      _selectedSlot = _slotOf(entries, widget.selectedDiveId);
    }
    if (slotsStale || loadedCount != _loadedCount) {
      _loadedSlotCount = _slots.where((s) => s.entryIndex < loadedCount).length;
    }
    _entries = entries;
    _grouping = widget.groupingEnabled;
    _collapsed = widget.collapsedTripIds;
    _field = field;
    _direction = direction;
    _depthUnit = depthUnit;
    _dateFormat = dateFormat;
    _locale = locale;
    _colors = colors;
    _loadedCount = loadedCount;
    _selectedId = widget.selectedDiveId;
  }

  /// The slot holding dive [id]: its own, or its collapsed trip's.
  int? _slotOf(List<DiveScrubberEntry> entries, String? id) {
    if (id == null || _slots.isEmpty) return null;
    final index = entries.indexWhere((e) => e.id == id);
    if (index < 0) return null;
    var low = 0;
    var high = _slots.length - 1;
    while (low < high) {
      final mid = (low + high + 1) ~/ 2;
      if (_slots[mid].entryIndex <= index) {
        low = mid;
      } else {
        high = mid - 1;
      }
    }
    return _slots[low].entryIndex <= index ? low : null;
  }

  @override
  Widget build(BuildContext context) {
    final sort = ref.watch(diveSortProvider);
    // Kept through a refetch for the same query; never used for another one.
    final index = ref.watch(diveScrubberIndexProvider).value;
    final entries =
        index != null &&
            index.builtFor(
              diverId: ref.watch(currentDiverIdProvider),
              filter: ref.watch(diveFilterProvider),
              sort: sort,
            )
        ? index.entries
        : const <DiveScrubberEntry>[];
    final field = sort.field;
    final units = UnitFormatter(ref.watch(settingsProvider));
    final l10n = context.l10n;
    final locale = Localizations.localeOf(context).toString();
    _refreshCache(
      entries: entries,
      field: field,
      direction: sort.direction,
      units: units,
      l10n: l10n,
      locale: locale,
      loadedCount: widget.loadedDives.length,
      colors: _detailColors(context),
    );
    final slots = _slots;

    return ListScrubber(
      controller: widget.controller,
      slotCount: slots.length,
      loadedSlotCount: _loadedSlotCount,
      labelFor: (slot) {
        final entry = slots[slot].entry;
        final value = diveScrubberValue(entry, field, units: units, l10n: l10n);
        final trip = entry.tripName?.trim();
        return field == DiveSortField.date && trip != null && trip.isNotEmpty
            ? l10n.diveLog_scrubber_valueWithTrip(value, trip)
            : value;
      },
      markers: _markers,
      highlightSlot: _selectedSlot,
      highlightTicks: _favorites,
      highlightTickColor: AppColors.favorite,
      segments: _segments,
      contextTicks: _contextTicks,
      density: _density,
      busyLabel: _loading ? l10n.common_label_loading : null,
      onScrubEnd: (slot) => _land(slots[slot]),
      onActiveChanged: (active) => _scrubbing.state = active,
      child: widget.child,
    );
  }

  /// Only the latest drop clears the busy state and lands. A drop on a loaded
  /// row leaves the list where the drag scrolled it when the row is in full
  /// view (#3574), and otherwise scrolls only as far as it takes to show it;
  /// only a drop past the loaded rows, which the list could not follow,
  /// loads and lands at the top.
  Future<void> _land(DiveScrubberSlot slot) async {
    final drop = ++_drop;
    final id = slot.entry.id;
    final needsLoad = !widget.loadedDives.any((d) => d.id == id);
    if (_loading != needsLoad) setState(() => _loading = needsLoad);
    if (!needsLoad) {
      _show(drop, id, toTop: false);
      return;
    }
    var loaded = false;
    try {
      loaded = await ref
          .read(paginatedDiveListProvider.notifier)
          .loadThrough(id, targetIndex: slot.entryIndex);
    } catch (e, stackTrace) {
      _log.error(
        'Failed to load the dive list through a scrubber drop',
        error: e,
        stackTrace: stackTrace,
      );
    } finally {
      if (mounted && drop == _drop) setState(() => _loading = false);
    }
    if (!mounted || drop != _drop || !loaded) return;
    _show(drop, id, toTop: true);
  }

  /// Shows [id] after the frame, unless a later drop came in first.
  void _show(int drop, String id, {required bool toTop}) {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted && drop == _drop) widget.onLand(context, id, toTop: toTop);
    });
  }
}
