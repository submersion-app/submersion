import 'dart:convert';

import 'package:submersion/core/providers/provider.dart';
import 'package:submersion/core/services/logger_service.dart';
import 'package:submersion/features/buddies/presentation/providers/buddy_providers.dart';
import 'package:submersion/features/dive_centers/presentation/providers/dive_center_providers.dart';
import 'package:submersion/features/dive_log/data/repositories/dive_repository_impl.dart';
import 'package:submersion/features/dive_log/domain/entities/dive_summary.dart';
import 'package:submersion/features/dive_log/domain/models/dive_filter_state.dart';
import 'package:submersion/features/dive_log/presentation/providers/dive_computer_providers.dart';
import 'package:submersion/features/dive_log/presentation/providers/dive_repository_provider.dart';
import 'package:submersion/features/dive_log/query/dive_filter_query.dart';
import 'package:submersion/features/dive_sites/presentation/providers/site_providers.dart';
import 'package:submersion/features/divers/presentation/providers/diver_providers.dart';
import 'package:submersion/features/equipment/presentation/providers/equipment_providers.dart';
import 'package:submersion/features/explore/data/explore_repository.dart';
import 'package:submersion/features/explore/data/name_index_builder.dart';
import 'package:submersion/features/explore/data/recent_query_repository.dart';
import 'package:submersion/features/explore/domain/chart_selection.dart';
import 'package:submersion/features/explore/domain/compiled_query.dart';
import 'package:submersion/features/explore/domain/name_index.dart';
import 'package:submersion/features/explore/domain/nl_engine.dart';
import 'package:submersion/features/explore/domain/query_compiler.dart';
import 'package:submersion/features/explore/domain/query_model.dart';
import 'package:submersion/features/explore/domain/unit_grounding.dart';
import 'package:submersion/features/explore/presentation/providers/explore_gate_providers.dart';
import 'package:submersion/features/marine_life/presentation/providers/species_providers.dart';
import 'package:submersion/features/settings/presentation/providers/settings_providers.dart';
import 'package:submersion/features/insights/domain/trend_aggregation.dart';
import 'package:submersion/features/insights/presentation/providers/insights_providers.dart';
import 'package:submersion/features/tags/presentation/providers/tag_providers.dart';
import 'package:submersion/features/trips/presentation/providers/trip_providers.dart';
import 'package:submersion/l10n/l10n_extension.dart';

/// Explore's own filter scope, so editing chips never rescopes the dive list
/// or Statistics until the diver asks for a handoff.
final exploreFilterProvider = StateProvider<DiveFilterState>(
  (ref) => const DiveFilterState(),
);

final unitPrefsProvider = Provider<UnitPrefs>((ref) {
  final s = ref.watch(settingsProvider);
  return (
    depth: s.depthUnit,
    temperature: s.temperatureUnit,
    pressure: s.pressureUnit,
  );
});

final exploreRepositoryProvider = Provider<ExploreRepository>(
  (ref) => ExploreRepository(),
);

/// Labels for the resolver, rebuilt when any source table changes.
final nameIndexProvider = FutureProvider<NameIndex>((ref) async {
  final diverId = await ref.watch(validatedCurrentDiverIdProvider.future);
  final builder = NameIndexBuilder(
    sites: ref.watch(siteRepositoryProvider),
    species: ref.watch(speciesRepositoryProvider),
    equipment: ref.watch(equipmentRepositoryProvider),
    buddies: ref.watch(buddyRepositoryProvider),
    dives: ref.watch(diveRepositoryProvider),
    tags: ref.watch(tagRepositoryProvider),
    centers: ref.watch(diveCenterRepositoryProvider),
    trips: ref.watch(tripRepositoryProvider),
    computers: ref.watch(diveComputerRepositoryProvider),
  );
  ref.invalidateSelfWhen(builder.sites.watchSitesChanges());
  ref.invalidateSelfWhen(builder.species.watchSpeciesChanges());
  ref.invalidateSelfWhen(builder.equipment.watchEquipmentChanges());
  ref.invalidateSelfWhen(builder.buddies.watchBuddiesChanges());
  ref.invalidateSelfWhen(builder.dives.watchDivesChanges());
  ref.invalidateSelfWhen(builder.tags.watchTagsChanges());
  ref.invalidateSelfWhen(builder.centers.watchDiveCentersChanges());
  ref.invalidateSelfWhen(builder.trips.watchTripsChanges());
  ref.invalidateSelfWhen(builder.computers.watchComputersChanges());
  final locale = ref.watch(localeProvider);
  return builder.build(diverId: diverId, l10n: l10nForLocaleTag(locale));
});

final recentQueryRepositoryProvider = Provider<RecentQueryRepository>(
  (ref) => RecentQueryRepository(),
);

/// Recorded after a successful compile; overridable so provider tests need
/// no local cache database.
typedef RecentQueryRecorder =
    Future<void> Function(String sentence, String locale, ParsedQuery parsed);

// no-tick: the value is a write function, not data; nothing here is cached
// and the list provider follows the table's own tick.
final recentQueryRecorderProvider = Provider<RecentQueryRecorder>((ref) {
  final repo = ref.watch(recentQueryRepositoryProvider);
  return (sentence, locale, parsed) => repo.record(sentence, locale, parsed);
});

/// The diver's recent sentences for the active locale, newest first.
final recentQueriesProvider = FutureProvider<List<RecentQuery>>((ref) async {
  final repo = ref.watch(recentQueryRepositoryProvider);
  ref.invalidateSelfWhen(repo.watchChanges());
  final locale = ref.watch(localeProvider);
  final all = await repo.list();
  return all.where((q) => q.locale == locale).toList();
});

class ExploreState {
  final String sentence;
  final ParsedQuery? parsed;
  final CompiledQuery? compiled;
  final bool running;
  final NlError? error;

  const ExploreState({
    this.sentence = '',
    this.parsed,
    this.compiled,
    this.running = false,
    this.error,
  });

  ExploreState copyWith({
    String? sentence,
    ParsedQuery? parsed,
    CompiledQuery? compiled,
    bool? running,
    NlError? error,
    bool clearError = false,
    bool clearResults = false,
  }) => ExploreState(
    sentence: sentence ?? this.sentence,
    parsed: clearResults ? null : (parsed ?? this.parsed),
    compiled: clearResults ? null : (compiled ?? this.compiled),
    running: running ?? this.running,
    error: clearError ? null : (error ?? this.error),
  );
}

class ExploreQueryNotifier extends StateNotifier<ExploreState> {
  ExploreQueryNotifier(this._ref) : super(const ExploreState());
  final Ref _ref;

  static const _log = LoggerService('ExploreQueryNotifier');

  /// Bumped by every request. A reply is published only while its request is
  /// still the latest, so a slow model call cannot overwrite a sentence the
  /// diver asked for after it (the keyboard's submit and the recent chips
  /// both start requests while one is in flight).
  int _request = 0;

  Future<void> run(String sentence) async {
    final trimmed = sentence.trim();
    if (trimmed.isEmpty) return;
    final request = _begin(trimmed);
    try {
      final locale = _ref.read(localeProvider);
      final json = await _ref
          .read(nlEngineProvider)
          .compile(trimmed, localeTag: locale);
      if (request != _request) return;
      final parsed = ParsedQuery.fromDecoded(jsonDecode(json));
      if (!await _compileAndPublish(parsed, request)) return;
      await _recordRecent(trimmed, locale, parsed);
    } on NlException catch (e) {
      _fail(request, e.error);
    } on QuerySchemaException {
      _fail(request, NlError.schemaMismatch);
    } on FormatException {
      _fail(request, NlError.schemaMismatch);
    } catch (e, stackTrace) {
      // Anything else (the name index failing to build, a database error)
      // must still end the run: otherwise the page spins forever with the
      // send button disabled and nothing on screen says why.
      _log.error('Explore query failed', error: e, stackTrace: stackTrace);
      _fail(request, NlError.unknown);
    }
  }

  /// A stored parse: no model call.
  Future<void> rerun(String sentence, ParsedQuery parsed) async {
    final request = _begin(sentence);
    try {
      await _compileAndPublish(parsed, request);
    } catch (e, stackTrace) {
      _log.error('Explore re-run failed', error: e, stackTrace: stackTrace);
      _fail(request, NlError.unknown);
    }
  }

  int _begin(String sentence) {
    final request = ++_request;
    state = state.copyWith(
      sentence: sentence,
      running: true,
      clearError: true,
      clearResults: true,
    );
    _ref.read(exploreFilterProvider.notifier).state = const DiveFilterState();
    return request;
  }

  void _fail(int request, NlError error) {
    if (request != _request) return;
    state = state.copyWith(running: false, error: error);
  }

  /// Remembering the sentence is a convenience: a failed write must not turn
  /// an answer the diver can already see into an error.
  Future<void> _recordRecent(
    String sentence,
    String locale,
    ParsedQuery parsed,
  ) async {
    try {
      await _ref.read(recentQueryRecorderProvider)(sentence, locale, parsed);
    } catch (e, stackTrace) {
      _log.warning(
        'Could not remember an Explore query',
        error: e,
        stackTrace: stackTrace,
      );
    }
  }

  void removeChip(QueryChip chip) {
    final parsed = state.parsed;
    if (parsed == null) return;
    final next = switch (chip.ref) {
      ChipRef.clause => parsed.withoutClause(chip.index),
      ChipRef.mention => parsed.withoutMention(chip.index),
      ChipRef.time => parsed.withoutTime(),
    };
    _compileSync(next);
  }

  /// Pins the mention to the chosen entry. The label goes into the text so
  /// the chip reads right, and the entry's identity rides along because two
  /// entities can share a label exactly: text alone would stay ambiguous.
  void resolveWith(int mentionIndex, NameEntry entry) {
    final parsed = state.parsed;
    if (parsed == null || mentionIndex >= parsed.mentions.length) return;
    final mentions = [...parsed.mentions];
    mentions[mentionIndex] = QueryMention(
      kind: entry.kind,
      text: entry.label,
      identity: entry.identity,
    );
    _compileSync(
      ParsedQuery(
        subject: parsed.subject,
        clauses: parsed.clauses,
        mentions: mentions,
        time: parsed.time,
        unplaced: parsed.unplaced,
      ),
    );
  }

  void clear() {
    // Also retires any request still in flight.
    _request++;
    state = const ExploreState();
    _ref.read(exploreFilterProvider.notifier).state = const DiveFilterState();
  }

  /// False when a newer request superseded [request] while the name index
  /// loaded, in which case nothing is published.
  Future<bool> _compileAndPublish(ParsedQuery parsed, int request) async {
    final names = await _ref.read(nameIndexProvider.future);
    if (request != _request) return false;
    _publish(parsed, names);
    return true;
  }

  void _compileSync(ParsedQuery parsed) {
    final names = _ref.read(nameIndexProvider).value ?? NameIndex.empty;
    _publish(parsed, names);
  }

  void _publish(ParsedQuery parsed, NameIndex names) {
    final compiled = QueryCompiler.compile(
      parsed,
      CompilerContext(
        units: _ref.read(unitPrefsProvider),
        names: names,
        now: DateTime.now(),
      ),
    );
    _ref.read(exploreFilterProvider.notifier).state = compiled.filter;
    state = state.copyWith(
      parsed: parsed,
      compiled: compiled,
      running: false,
      clearError: true,
    );
  }
}

final exploreQueryProvider =
    StateNotifierProvider<ExploreQueryNotifier, ExploreState>(
      (ref) => ExploreQueryNotifier(ref),
    );

/// ONE debounced tick over `dives` plus whatever else the compiled filter
/// reads, mirroring `orderedDiveIdsProvider` (#2365): a species filter reads
/// `sightings`, a buddy filter the buddy tables, an attribute condition the
/// gear tables. One stream, not one per axis, so a junction write followed
/// by the dive write recomputes the results once.
Stream<void> _exploreTick(DiveRepository repo, DiveFilterState filter) {
  final extra = diveFilterTablesTouched(filter).difference({'dives'});
  return extra.isEmpty
      ? repo.watchDivesChanges()
      : repo.watchTables({'dives', ...extra});
}

final exploreResultsProvider = FutureProvider<List<DiveSummary>>((ref) async {
  final filter = ref.watch(exploreFilterProvider);
  final diverId = await ref.watch(validatedCurrentDiverIdProvider.future);
  final repo = ref.watch(diveRepositoryProvider);
  ref.invalidateSelfWhen(_exploreTick(repo, filter));
  if (!filter.hasActiveFilters) return const [];
  return repo.getDiveSummaries(diverId: diverId, filter: filter, limit: 100);
});

final exploreCountProvider = FutureProvider<int>((ref) async {
  final filter = ref.watch(exploreFilterProvider);
  final diverId = await ref.watch(validatedCurrentDiverIdProvider.future);
  final repo = ref.watch(diveRepositoryProvider);
  ref.invalidateSelfWhen(_exploreTick(repo, filter));
  if (!filter.hasActiveFilters) return 0;
  return repo.getDiveCount(diverId: diverId, filter: filter);
});

class ExploreChartData {
  final List<TrendDataPoint> points;
  final List<({String label, int count})> bars;
  const ExploreChartData({this.points = const [], this.bars = const []});
}

final exploreChartDataProvider =
    FutureProvider.family<ExploreChartData, ChartRequest>((ref, request) async {
      final filter = ref.watch(exploreFilterProvider);
      final diverId = await ref.watch(validatedCurrentDiverIdProvider.future);
      final stats = ref.watch(insightsRepositoryProvider);
      ref.invalidateSelfWhen(stats.watchInsightsChanges());
      if (!filter.hasActiveFilters) return const ExploreChartData();
      switch (request.kind) {
        case ChartKind.divesOverTime:
          return ExploreChartData(
            points: await stats.getCumulativeDiveCount(
              diverId: diverId,
              filter: filter,
            ),
          );
        case ChartKind.depthTrend:
          return ExploreChartData(
            points: await stats.getDepthPerDive(
              diverId: diverId,
              filter: filter,
            ),
          );
        case ChartKind.waterTempTrend:
          return ExploreChartData(
            points: await stats.getWaterTempPerDive(
              diverId: diverId,
              filter: filter,
            ),
          );
        case ChartKind.bottomTimeTrend:
          return ExploreChartData(
            points: await stats.getBottomTimePerDive(
              diverId: diverId,
              filter: filter,
            ),
          );
        case ChartKind.entityCounts:
          final rows = switch (request.entityKind) {
            MentionKind.species => (await stats.getMostCommonSightings(
              diverId: diverId,
              filter: filter,
            )).map((r) => (label: r.name, count: r.count)).toList(),
            MentionKind.buddy => (await stats.getTopBuddies(
              diverId: diverId,
              filter: filter,
            )).map((r) => (label: r.name, count: r.count)).toList(),
            MentionKind.center => (await stats.getTopDiveCenters(
              diverId: diverId,
              filter: filter,
            )).map((r) => (label: r.name, count: r.count)).toList(),
            MentionKind.gear => (await stats.getMostUsedGear(
              diverId: diverId,
              filter: filter,
            )).map((r) => (label: r.name, count: r.count)).toList(),
            MentionKind.site || MentionKind.place =>
              (await ref
                      .watch(exploreRepositoryProvider)
                      .diveCountBySite(filter, diverId: diverId))
                  .map((r) => (label: r.name, count: r.count))
                  .toList(),
            // selectCharts only requests kRankedEntityKinds; anything else
            // draws nothing rather than another kind's counts.
            _ => const <({String label, int count})>[],
          };
          return ExploreChartData(bars: rows);
      }
    });
