import 'package:submersion/features/agent_access/data/records/record_repositories.dart';
import 'package:submersion/features/agent_access/data/writes/field_codec.dart';
import 'package:submersion/features/agent_access/data/writes/json_object_codec.dart';
import 'package:submersion/features/agent_access/data/writes/writable_entity.dart';
import 'package:submersion/features/agent_access/domain/agent_tool_error.dart';
import 'package:submersion/features/planner/data/services/plan_engine_settings.dart';
import 'package:submersion/features/planner/data/services/planned_dives_writer.dart';
import 'package:submersion/features/planner/data/services/stored_series_results.dart';
import 'package:submersion/features/planner/domain/entities/plan_series.dart';
import 'package:submersion/features/planner/domain/services/plan_engine.dart';
import 'package:submersion/features/planner/domain/services/plan_series_calculator.dart'
    show SeriesDiveResult;
import 'package:submersion/features/settings/presentation/providers/settings_providers.dart'
    show AppSettings;

/// What `planned_dives` asks of a write: the options an agent sends with it.
class PlannedDivesRequest {
  const PlannedDivesRequest({
    this.deleteRemoved = false,
    this.moveDivedLink = false,
  });

  /// Delete the planned entries of dives the same update takes out of the
  /// series. Without it they stay in the log, unlinked.
  final bool deleteRemoved;

  /// Let a single plan linked to a dived dive take a new entry, moving its
  /// link off the dived one, as Convert to Dive did (#4058).
  final bool moveDivedLink;

  /// The request a parsed `planned_dives` value holds, or null for none.
  static PlannedDivesRequest? of(Object? parsed) {
    if (parsed == null) return null;
    final map = JsonObjectCodec.decoded(parsed);
    return PlannedDivesRequest(
      deleteRemoved: map[PlannedDivesEffect.deleteRemoved] == true,
      moveDivedLink: map[PlannedDivesEffect.moveDivedLink] == true,
    );
  }
}

/// A plan or series computed for writing its dives to the log, and what the
/// write would do with each.
class PlannedDivesOutlook {
  const PlannedDivesOutlook({
    required this.series,
    required this.results,
    required this.decided,
    required this.needsFirstStart,
    this.removed = const [],
  });

  final PlanSeries series;
  final List<SeriesDiveResult> results;
  final PlannedDivesPlan decided;

  /// A series with a dive still to write and no start to lay it out on.
  final bool needsFirstStart;

  /// Entries of dives the same update takes out of the series, with whether
  /// they go: (dive id, deleted). A dived entry never does.
  final List<(String, bool)> removed;
}

/// The `planned_dives` effect field of `dive_plan_series` and `dive_plans`
/// (issue #4203): the planner's "Create / Update planned dives", run by the
/// write core, so a preview lists each dive's entry, the diver allows it in
/// the app, and one revert undoes it with the rest of the set.
///
/// Both entities run it through [PlannedDivesWriter], as the planner does,
/// so the app and an agent write the same entries for the same plan.
class PlannedDivesEffect {
  PlannedDivesEffect(this._r, {SeriesFollowReader? followOf})
    : _followOf = followOf;

  final RecordRepositories _r;
  final SeriesFollowReader? _followOf;

  static const field = 'planned_dives';
  static const deleteRemoved = 'delete_removed';
  static const moveDivedLink = 'move_dived_link';

  /// The per-dive outcome a preview lists, as an indirect field.
  static const entriesKey = 'planned_dive_entries';

  static const codec = JsonObjectCodec(
    shape:
        'an object {$deleteRemoved: bool, $moveDivedLink: bool}, '
        'either key optional',
    normalize: _normalize,
  );

  static Map<String, Object?> _normalize(Map<String, Object?> raw) {
    final unknown = raw.keys.where(
      (k) => k != deleteRemoved && k != moveDivedLink,
    );
    if (unknown.isNotEmpty) {
      throw FieldRefusal(
        '${unknown.join(', ')} is not an option; these are: '
        '$deleteRemoved, $moveDivedLink.',
      );
    }
    for (final MapEntry(:key, :value) in raw.entries) {
      if (value != null && value is! bool) {
        throw FieldRefusal('$key takes true or false.');
      }
    }
    return {
      deleteRemoved: raw[deleteRemoved] == true,
      moveDivedLink: raw[moveDivedLink] == true,
    };
  }

  /// The entities whose records are the log: dives, and every record that
  /// belongs to one. Writing a planned entry replaces its tanks, gas
  /// switches, notes and safety review, so a change to any of these earlier
  /// in the set would be decided on and then overwritten.
  static const logEntities = {
    'dives',
    'dive_tanks',
    'dive_weights',
    'dive_custom_fields',
    'dive_events',
    'dive_scenarios',
    'gas_switches',
    'safety_findings',
    'sightings',
  };

  /// Whether a change earlier in the set, as [soFar] holds it, writes the
  /// log, links a dive to a plan (which takes it off any other plan), or
  /// writes a record [owns] names: the plan or series being written, and a
  /// series' plans. The planned dives would be decided without any of it.
  static bool changedEarlier(
    SetSoFar soFar,
    bool Function(String entity, String id) owns,
  ) {
    bool touches(String entity, String id) =>
        logEntities.contains(entity) || owns(entity, id);
    bool links(Map<String, Object?> values) => values['linked_dive_id'] != null;
    return soFar.values.entries.any(
          (e) =>
              touches(e.key.$1, e.key.$2) ||
              (e.key.$1 == 'dive_plans' && links(e.value)),
        ) ||
        soFar.deleted.entries.any(
          (e) => e.value.any((id) => touches(e.key, id)),
        ) ||
        logEntities.any((e) => soFar.created[e]?.isNotEmpty ?? false) ||
        (soFar.created['dive_plans'] ?? const []).any(links);
  }

  /// What the tool description says about the field.
  static const note =
      '$field writes the plan\'s dives into the log as planned dives, as the '
      'planner\'s Create / Update planned dives does: a dive with no entry '
      'gets one, a planned entry is rewritten in place, a dived one is left '
      'alone. An update\'s preview lists each in $entriesKey; a create '
      'gives every dive an entry and counts them in also_creates. A series '
      'needs the first dive\'s start_date_time.';

  PlannedDivesWriter get _writer => PlannedDivesWriter(
    dives: _r.dives,
    plans: _r.divePlans,
    siteOf: _r.sites.getSiteById,
    shares: _r.itemShares,
  );

  /// [ownerId]'s planner settings, or the defaults for none.
  Future<PlanEngineConfig> configFor(String? ownerId) async {
    final settings = ownerId == null
        ? null
        : await _r.diverSettings.getSettingsForDiver(ownerId);
    return planEngineConfigFromSettings(settings ?? const AppSettings());
  }

  /// The reader a saved plan is computed with, or a refusal when this
  /// server has none.
  SeriesFollowReader get followOf =>
      _followOf ??
      (throw const AgentToolException(
        AgentToolErrorCode.writeRefused,
        'Planned dives cannot be written here.',
      ));

  /// What writing [computed] to the log for [ownerId] does, as the planner
  /// decides it. [removed] are the entries of dives the same update takes
  /// out of the series.
  Future<PlannedDivesOutlook> outlook(
    ({PlanSeries series, List<SeriesDiveResult> results}) computed, {
    required String? ownerId,
    required PlannedDivesRequest request,
    Set<String> removed = const {},
  }) async {
    final writer = _writer;
    final lookups = await writer.lookUp(computed.series, diverId: ownerId);
    final decided = writer.decide(
      computed.series,
      computed.results,
      lookups,
      moveDivedLink: request.moveDivedLink,
    );
    final gone = <(String, bool)>[];
    for (final id in removed) {
      final dive = await _r.dives.getDiveById(id);
      if (dive == null) continue;
      gone.add((id, request.deleteRemoved && dive.isPlanned));
    }
    return PlannedDivesOutlook(
      series: computed.series,
      results: computed.results,
      decided: decided,
      needsFirstStart: seriesNeedsFirstStart(computed.series, computed.results),
      removed: gone,
    );
  }

  /// Why [outlook] cannot be written, or null when it can.
  static PlanBlock? blockOf(PlannedDivesOutlook outlook) {
    final decided = outlook.decided;
    if (decided.needsLinkMove) {
      return const PlanBlock(
        BlockReason.notPermitted,
        '$field: this plan is linked to a dive that has been dived. Send '
        '$moveDivedLink: true to give the plan a new planned entry and move '
        'its link to it; the dived dive stays as it is.',
      );
    }
    if (decided.blockedIndex case final i?) {
      final which = outlook.series.isSeries
          ? 'Dive ${seriesDiveLetter(i)}'
          : 'The plan';
      return PlanBlock(
        BlockReason.invalidValue,
        decided.blockedEmpty
            ? '$field: $which has no segments, so it cannot be logged.'
            : '$field: $which has a critical warning, so it cannot be '
                  'logged; compute_plan lists it.',
      );
    }
    if (outlook.needsFirstStart) {
      return const PlanBlock(
        BlockReason.missingField,
        '$field: the first dive of the series needs start_date_time, so '
        'its dives can be laid out in the log.',
      );
    }
    return null;
  }

  /// What [outlook] does beyond the record itself, as a preview lists it.
  static SideEffects effectsOf(PlannedDivesOutlook outlook) {
    final steps = outlook.decided.steps;
    int count(PlannedDiveAction action) =>
        steps.where((s) => s.action == action).length;
    final created = count(PlannedDiveAction.create);
    final updated = count(PlannedDiveAction.update);
    final deleted = outlook.removed.where((r) => r.$2).length;
    return SideEffects(
      fields: {entriesKey: entriesOf(outlook)},
      created: {if (created > 0) 'dives': created},
      touched: {if (updated > 0) 'dives': updated},
      parts: {if (deleted > 0) 'dives': deleted},
    );
  }

  /// Each dive's outcome, as the preview lists it: the dive by its letter
  /// and name, what happens to its entry, and the entry's id where it has
  /// one.
  static List<Map<String, Object?>> entriesOf(PlannedDivesOutlook outlook) => [
    for (final step in outlook.decided.steps)
      {
        'dive': _label(outlook.series, step.index, step.name),
        'action': switch (step.action) {
          PlannedDiveAction.create => 'create',
          PlannedDiveAction.update => 'update',
          PlannedDiveAction.skipDived => 'skip_dived',
        },
        'dive_id': ?step.entry?.id,
      },
    for (final (id, deleted) in outlook.removed)
      {
        'dive': 'removed',
        'action': deleted ? 'delete_removed' : 'keep_removed',
        'dive_id': id,
      },
  ];

  static String _label(PlanSeries series, int index, String? name) {
    if (!series.isSeries) return name ?? 'plan';
    final letter = seriesDiveLetter(index);
    return name == null || name.isEmpty ? letter : '$letter $name';
  }

  /// Writes [computed] to the log for [ownerId], as the planner does once
  /// the plan is saved: the entries, then each new entry's link. Refuses,
  /// writing nothing, when it can no longer be written, and rethrows a write
  /// that fails part way, so the apply rolls the whole set back.
  Future<void> write(
    ({PlanSeries series, List<SeriesDiveResult> results}) computed, {
    required String? ownerId,
    required PlannedDivesRequest request,
    Set<String> removed = const {},
  }) async {
    final seen = await outlook(
      computed,
      ownerId: ownerId,
      request: request,
      removed: removed,
    );
    if (blockOf(seen) case final block?) {
      throw AgentToolException(AgentToolErrorCode.writeRefused, block.detail);
    }
    final writer = _writer;
    final written = await writer.write(
      seen.decided,
      config: await configFor(ownerId),
      addDive: (dive) => _r.dives.createDive(
        dive.diverId == null && ownerId != null
            ? dive.copyWith(diverId: ownerId)
            : dive,
      ),
      updateDive: _r.dives.updateDive,
    );
    if (written.failure case final failure?) {
      Error.throwWithStackTrace(failure, written.failureStack!);
    }
    await writer.link(written);
    if (!request.deleteRemoved) return;
    final orphans = [for (final dive in await writer.orphans(removed)) dive.id];
    if (orphans.isEmpty) return;
    // As a dive's own delete runs: a revert restores the rows, and its
    // media needs the blobs still there.
    await _r.dives.bulkDeleteDives(orphans, holdRemoteMedia: true);
  }
}
