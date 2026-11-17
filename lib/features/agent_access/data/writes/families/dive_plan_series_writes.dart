import 'dart:convert';

import 'package:submersion/features/agent_access/data/documents/plan_documents.dart';
import 'package:submersion/features/agent_access/data/records/families/plan_record_loads.dart';
import 'package:submersion/features/agent_access/data/records/record_repositories.dart';
import 'package:submersion/features/agent_access/data/writes/families/dive_plan_series_create.dart';
import 'package:submersion/features/agent_access/data/writes/families/dive_plan_series_names.dart';
import 'package:submersion/features/agent_access/data/writes/families/planned_dives_effect.dart';
import 'package:submersion/features/agent_access/data/writes/field_codec.dart';
import 'package:submersion/features/agent_access/data/writes/writable_entity.dart';
import 'package:submersion/features/agent_access/domain/agent_tool_error.dart';
import 'package:submersion/features/planner/data/services/stored_series_results.dart';
import 'package:submersion/features/planner/domain/entities/plan_series.dart';
import 'package:submersion/features/planner/domain/entities/stored_series.dart';
import 'package:submersion/features/planner/domain/services/plan_series_calculator.dart'
    show SeriesDiveResult;

/// A dive an update renames: its plan, the entry in the log the plan links
/// to, and whether that entry has been dived, as the rename was decided on.
typedef _Rename = ({String planId, String? diveId, bool dived});

/// Repetitive dive series, through the repository the planner saves them
/// with. A series is created from its dives, as `compute_plan` takes them,
/// or as a copy of another; here it is renamed, its dives renamed, kept,
/// reordered or dropped (a dropped dive's plan goes with it), dissolved
/// into one plan, or deleted with its plans; and its dives written to the
/// log as planned dives, on a create or an update.
class DivePlanSeriesWrites extends WritableEntry {
  /// [followOf] reads the logged dive a new series follows, as
  /// `compute_plan` reads it; without it a series cannot follow one, nor
  /// write its planned dives.
  DivePlanSeriesWrites(this._r, {SeriesFollowReader? followOf})
    : _followOf = followOf,
      _planned = PlannedDivesEffect(_r, followOf: followOf);

  final RecordRepositories _r;
  final SeriesFollowReader? _followOf;
  final PlannedDivesEffect _planned;

  static const _copy = 'duplicate_of';
  static const _dissolve = 'dissolve_keeping_plan_id';
  static const _dives = 'dives';
  static const _follow = 'followed_dive_id';
  static const _names = 'dive_names';

  @override
  String get name => 'dive_plan_series';

  @override
  String get table => 'dive_plan_series';

  @override
  String get note =>
      'plan_ids are the series\' dives in order, a selection of the ones it '
      'holds; a plan left out is deleted. $_names names dives by plan id, '
      'null going back to the letter; a dive left out keeps its name, a '
      'dived one cannot be renamed, and planned entries take the names '
      'when ${PlannedDivesEffect.field} is written. $_dissolve turns the '
      'series back into that one plan, deleting the rest. A new series '
      'takes a name and $_dives, as compute_plan takes them (a dive\'s '
      'resolved_inputs save unchanged; each may have a name), and $_follow '
      'for the logged dive it follows; or it is a copy, $_copy. A single '
      'dive is a dive_plans record. '
      '${PlannedDivesEffect.note} ${PlannedDivesEffect.deleteRemoved} '
      'deletes the planned entries of dives plan_ids drops in the same '
      'change.';

  @override
  late final Map<String, FieldCodec> fields = {
    'name': const FieldCodec.text(maxLength: 200, trim: true),
    'plan_ids': const FieldCodec.textList(maxItems: 20),
    _dissolve: const FieldCodec.reference('dive_plans'),
    _copy: const FieldCodec.reference('dive_plan_series'),
    _dives: const PlanSeriesDivesCodec(),
    _follow: const FieldCodec.reference('dives'),
    _names: const SeriesDiveNamesCodec(),
    PlannedDivesEffect.field: PlannedDivesEffect.codec,
  };

  @override
  Set<String> get requiredOnCreate => const {};

  @override
  Set<String> get createOnly => const {_copy, _dives, _follow};

  @override
  Set<String> get effectFields => const {_dissolve, PlannedDivesEffect.field};

  @override
  Future<Map<String, Object?>> stored(
    String id,
    Map<String, Object?> document,
  ) async => {
    ...document,
    'plan_ids': [
      for (final d in document['dives'] as List? ?? const [])
        (d as Map)['plan_id'],
    ],
  };

  @override
  Future<PlanBlock?> refuse(WriteCheck check) async {
    if (check.kind == ChangeKind.create) return _refuseCreate(check);
    if (check.kind != ChangeKind.update) return null;
    final held = [
      for (final d in check.document?['dives'] as List? ?? const [])
        (d as Map)['plan_id'] as String,
    ];
    final v = check.values;
    if (v.containsKey(_dissolve) &&
        (v.containsKey('plan_ids') ||
            v.containsKey(_names) ||
            v[PlannedDivesEffect.field] != null)) {
      return const PlanBlock(
        BlockReason.notPermitted,
        'Dissolve a series in a change of its own.',
      );
    }
    if (v[_dissolve] case final String keep when !held.contains(keep)) {
      return PlanBlock(
        BlockReason.invalidValue,
        '$_dissolve: $keep is not a dive of this series.',
      );
    }
    if (v['plan_ids'] case final Object raw) {
      final ids = _texts(raw);
      if (ids.isEmpty || ids.any((id) => !held.contains(id))) {
        return const PlanBlock(
          BlockReason.invalidValue,
          'plan_ids: one or more of the series\' own dives.',
        );
      }
    }
    if (v.containsKey(_names)) {
      if (await _refuseNames(check, held) case final block?) return block;
    }
    if (PlannedDivesRequest.of(v[PlannedDivesEffect.field]) case final ask?) {
      if (_changedEarlier(check.soFar, check.id!, held) case final block?) {
        return block;
      }
      return PlannedDivesEffect.blockOf(
        await _outlookOfUpdate(check.id!, v, ask, check.pass),
      );
    }
    return null;
  }

  /// A block when [check]'s dive names are not of dives the series keeps,
  /// [held] or the ones `plan_ids` gives, or would rename a dive that has
  /// been dived, whose details the planner no longer changes (issue #4626).
  /// Giving a dived dive the name it has is no change, so is let through.
  /// The stored rows cannot show what an earlier change in the set does to
  /// a renamed dive's plan or entry, which can make it dived, so such a
  /// rename waits for a set of its own.
  Future<PlanBlock?> _refuseNames(WriteCheck check, List<String> held) async {
    final values = check.values;
    final names = SeriesDiveNamesCodec.names(values[_names]);
    final kept = switch (values['plan_ids']) {
      final Object raw => _texts(raw),
      null => held,
    };
    for (final planId in names.keys) {
      if (!kept.contains(planId)) {
        return PlanBlock(
          BlockReason.invalidValue,
          held.contains(planId)
              ? '$_names: $planId is dropped by plan_ids in the same change.'
              : '$_names: $planId is not a dive of this series.',
        );
      }
    }
    for (final rename in (await _renames(
      check.id!,
      values,
      check.pass,
    )).renames) {
      if (rename.dived) {
        return PlanBlock(
          BlockReason.notPermitted,
          '$_names: ${rename.planId} has been dived, so its name stays as it '
          'is.',
        );
      }
      if (_changedEarlierThan(check.soFar, rename)) {
        return PlanBlock(
          BlockReason.notPermitted,
          '$_names: rename ${rename.planId} in a change set after the one '
          'that changes its plan or its entry in the log.',
        );
      }
    }
    return null;
  }

  /// Whether a change earlier in the set writes [rename]'s plan, which can
  /// link it to a dived dive, or the entry in the log it links to.
  static bool _changedEarlierThan(SetSoFar soFar, _Rename rename) =>
      (soFar.touched['dive_plans']?.contains(rename.planId) ?? false) ||
      (soFar.touched['dives']?.contains(rename.diveId) ?? false);

  /// The series [values] name dives of, and each dive whose name they
  /// change, read as the planner reads a dived dive: linked to an entry in
  /// the log that is no longer planned. Read once per preview in [pass], so
  /// the refusal and the side effects decide on the same reads.
  Future<({StoredSeries series, List<_Rename> renames})> _renames(
    String id,
    Map<String, Object?> values,
    PlanningPass? pass,
  ) {
    Future<({StoredSeries series, List<_Rename> renames})> read() async {
      final names = SeriesDiveNamesCodec.names(values[_names]);
      final series = await _series(id);
      // Each entry is read on its own, so all of them at once.
      final renames = await Future.wait([
        for (final dive in series.dives)
          if (names.containsKey(dive.plan.id) &&
              names[dive.plan.id] != dive.name)
            _renameOf(dive),
      ]);
      return (series: series, renames: renames);
    }

    return pass?.once((this, _names, id, values), read) ?? read();
  }

  Future<_Rename> _renameOf(StoredSeriesDive dive) async {
    final diveId = dive.plan.linkedDiveId;
    final logged = diveId == null ? null : await _r.dives.getDiveById(diveId);
    return (
      planId: dive.plan.id,
      diveId: diveId,
      dived: logged != null && !logged.isPlanned,
    );
  }

  /// What an update's dive names show and rest on, when they change one:
  /// the series' dives as its document will read them, so a name going
  /// back to its letter shows beside the name it had, and what each renamed
  /// dive's lock was decided on, so an apply after one is dived or linked
  /// finds the plan stale.
  Future<({Map<String, Object?> fields, String basis})> _namesShown(
    String id,
    Map<String, Object?> values,
    PlanningPass? pass,
  ) async {
    const none = (fields: <String, Object?>{}, basis: '');
    if (values[_names] == null) return none;
    final read = await _renames(id, values, pass);
    if (read.renames.isEmpty) return none;
    final next = _updated(read.series, values);
    // Where each dive stands in the log, as the stored document reads it,
    // so the change shows the names alone.
    final logged = await loggedEntryFlags(
      _r,
      linkedDiveIds([for (final dive in next.dives) dive.plan]),
    );
    return (
      fields: {'dives': divePlanSeriesDocument(next, logged: logged)['dives']},
      basis: jsonEncode([
        for (final r in read.renames) [r.planId, r.diveId, r.dived],
      ]),
    );
  }

  /// A block when an earlier change in the set writes this series, its
  /// plans, a plan's link or the log, which the planned dives would be
  /// decided without (see [PlannedDivesEffect.changedEarlier]).
  static PlanBlock? _changedEarlier(
    SetSoFar soFar,
    String id,
    List<String> planIds,
  ) {
    final plans = planIds.toSet();
    return PlannedDivesEffect.changedEarlier(
          soFar,
          (entity, record) =>
              (entity == 'dive_plans' && plans.contains(record)) ||
              (entity == 'dive_plan_series' && record == id),
        )
        ? const PlanBlock(
            BlockReason.notPermitted,
            '${PlannedDivesEffect.field}: write planned dives in a change set '
            'after the one that changes this series, its plans, a plan\'s '
            'link or the log.',
          )
        : null;
  }

  /// The series as an update of [values] leaves it, computed for writing its
  /// planned dives. Computed once per preview in [pass]: the refusal and the
  /// side effects of one change ask with the same values.
  Future<PlannedDivesOutlook> _outlookOfUpdate(
    String id,
    Map<String, Object?> values,
    PlannedDivesRequest ask,
    PlanningPass? pass,
  ) {
    Future<PlannedDivesOutlook> read() async {
      final current = await _series(id);
      final next = _updated(current, values);
      return _planned.outlook(
        await _computed(next),
        ownerId: await _ownerOf(next),
        request: ask,
        removed: _removedEntries(current, next),
      );
    }

    return pass?.once((this, id, values), read) ?? read();
  }

  /// Whom [series]' planned dives are written for, with whose settings it is
  /// computed: its diver, or for a series with none the active diver, as the
  /// planner and a plan in no series have it.
  Future<String?> _ownerOf(StoredSeries series) async =>
      series.diverId ?? await _r.activeDiverId?.call();

  /// [series] with an update's name, order and dive names, as [update]
  /// saves it.
  static StoredSeries _updated(StoredSeries series, Map<String, Object?> v) {
    final raw = v['plan_ids'];
    final names = SeriesDiveNamesCodec.names(v[_names]);
    final byPlan = {for (final d in series.dives) d.plan.id: d};
    final ordered = raw == null
        ? series.dives
        : [for (final planId in _texts(raw)) byPlan[planId]!];
    return StoredSeries(
      id: series.id,
      name: v['name'] as String? ?? series.name,
      diverId: series.diverId,
      followedDiveId: series.followedDiveId,
      dives: [
        for (final dive in ordered)
          if (names.containsKey(dive.plan.id))
            dive.copyWith(
              name: names[dive.plan.id],
              clearName: names[dive.plan.id] == null,
            )
          else
            dive,
      ],
    );
  }

  /// The log entries of the dives [before] holds and [after] does not.
  static Set<String> _removedEntries(StoredSeries before, StoredSeries after) {
    final kept = {for (final d in after.dives) d.plan.id};
    return {
      for (final d in before.dives)
        if (!kept.contains(d.plan.id)) ?d.plan.linkedDiveId,
    };
  }

  /// [series] computed as the planner computes it on opening, with its
  /// owner's planner settings (see [_ownerOf]).
  Future<({PlanSeries series, List<SeriesDiveResult> results})> _computed(
    StoredSeries series,
  ) async => computeStoredSeries(
    series,
    config: await _planned.configFor(await _ownerOf(series)),
    dives: _r.dives,
    followOf: _planned.followOf,
  );

  Future<PlanBlock?> _refuseCreate(WriteCheck check) async {
    final v = check.values;
    final dives = v[_dives];
    final ask = PlannedDivesRequest.of(v[PlannedDivesEffect.field]);
    // Fields of a saved series' dives, which a create would otherwise take
    // and drop without a word.
    final updateOnly = [
      for (final key in const ['plan_ids', _dissolve, _names])
        if (v.containsKey(key)) key,
    ];
    if (updateOnly.isNotEmpty) {
      return PlanBlock(
        BlockReason.notPermitted,
        '${updateOnly.join(', ')}: only a saved series takes '
        '${updateOnly.length == 1 ? 'this' : 'these'}. A new series names '
        'its dives by each of $_dives\' name; a copy\'s, once it exists.',
      );
    }
    if (v[_copy] != null) {
      if (ask != null) {
        return const PlanBlock(
          BlockReason.notPermitted,
          '${PlannedDivesEffect.field}: write a copy\'s planned dives once it '
          'exists.',
        );
      }
      return dives != null || v[_follow] != null
          ? const PlanBlock(
              BlockReason.notPermitted,
              'A copy takes its dives, and the dive it follows, from '
              '$_copy.',
            )
          : null;
    }
    if (dives == null) {
      return const PlanBlock(
        BlockReason.missingField,
        'A new dive_plan_series record needs $_dives, or $_copy.',
      );
    }
    if (v['name'] == null) {
      return const PlanBlock(
        BlockReason.missingField,
        'A new dive_plan_series record needs a name.',
      );
    }
    if (seriesDiveCountProblem(dives) case final problem?) {
      return PlanBlock(BlockReason.invalidValue, problem);
    }
    final StoredSeries built;
    try {
      built = await _built(v, check.ownerId!);
    } on AgentToolException catch (e) {
      final field = e.details?['field'];
      return PlanBlock(
        BlockReason.invalidValue,
        field == null ? e.message : '$field: ${e.message}',
      );
    }
    if (ask == null) return null;
    if (_changedEarlier(check.soFar, '', const []) case final block?) {
      return block;
    }
    return PlannedDivesEffect.blockOf(
      await _planned.outlook(
        await _computed(built),
        ownerId: check.ownerId,
        request: ask,
      ),
    );
  }

  @override
  Future<Map<String, int>> alsoCreates(
    String diverId,
    Map<String, Object?> values,
  ) async => {
    if (values[_dives] case final Object dives) ...{
      'dive_plans': PlanSeriesDivesCodec.count(dives),
      // A new series has no entries in the log, so each dive gets one.
      if (values[PlannedDivesEffect.field] != null)
        'dives': PlanSeriesDivesCodec.count(dives),
    },
  };

  /// The series [values] create from their dives, computed with [diverId]'s
  /// planner settings, as the planner computes a series it saves for them.
  Future<StoredSeries> _built(
    Map<String, Object?> values,
    String diverId,
  ) async => seriesFromDives(
    dives: values[_dives],
    name: values['name']! as String,
    diverId: diverId,
    followedDiveId: values[_follow] as String?,
    config: await _planned.configFor(diverId),
    followOf: _followOf,
  );

  @override
  Future<SideEffects> sideEffects(
    String id,
    String? ownerId,
    RecordUpdate update,
    Map<String, Object?> document,
  ) async {
    final held = (document['plan_ids'] as List? ?? const []).length;
    final v = update.values;
    final kept = v.containsKey(_dissolve)
        ? 1
        : v['plan_ids'] == null
        ? held
        : _texts(v['plan_ids']!).length;
    final dropped = held - kept;
    final shown = await _namesShown(id, v, update.pass);
    final ask = PlannedDivesRequest.of(v[PlannedDivesEffect.field]);
    if (ask == null) {
      return SideEffects(
        fields: shown.fields,
        parts: {if (dropped > 0) 'dive_plans': dropped},
        basis: shown.basis,
      );
    }
    final planned = PlannedDivesEffect.effectsOf(
      await _outlookOfUpdate(id, v, ask, update.pass),
    );
    return SideEffects(
      fields: {...planned.fields, ...shown.fields},
      created: planned.created,
      touched: planned.touched,
      parts: {if (dropped > 0) 'dive_plans': dropped, ...planned.parts},
      records: planned.records,
      unlinked: planned.unlinked,
      rewrites: planned.rewrites,
      basis: shown.basis.isEmpty
          ? planned.basis
          : '${planned.basis} ${shown.basis}',
    );
  }

  @override
  Future<DeleteReach> deleteReach(
    String id, {
    Map<String, Set<String>> alongside = const {},
  }) async {
    final series = await _r.divePlanSeries.getSeries(id);
    final n = series?.dives.length ?? 0;
    return DeleteReach(records: {if (n > 0) 'dive_plans': n});
  }

  @override
  Future<String> create(String diverId, Map<String, Object?> values) async {
    if (values[_copy] == null) {
      final saved = await _r.divePlanSeries.saveSeries(
        await _built(values, diverId),
      );
      if (PlannedDivesRequest.of(values[PlannedDivesEffect.field])
          case final ask?) {
        await _planned.write(
          await _computed(await _series(saved.id)),
          ownerId: diverId,
          request: ask,
        );
      }
      return saved.id;
    }
    final from = values[_copy]! as String;
    final copy =
        await _r.divePlanSeries.duplicateSeries(from) ??
        (throw AgentToolException(
          AgentToolErrorCode.writeRefused,
          'Series $from no longer exists.',
          details: {'id': from},
        ));
    if (values['name'] case final String name) {
      await _r.divePlanSeries.renameSeries(copy.id, name);
    }
    return copy.id;
  }

  @override
  Future<void> update(String id, String? ownerId, RecordUpdate update) async {
    final v = update.values;
    final repo = _r.divePlanSeries;
    if (v[_dissolve] case final String keep) {
      await repo.dissolveSeries(id, keepPlanId: keep);
      return;
    }
    final ask = PlannedDivesRequest.of(v[PlannedDivesEffect.field]);
    // Read only when the save or the planned dives need it: a rename of the
    // series alone reads nothing.
    final saves = v['plan_ids'] != null || v[_names] != null;
    final before = saves || ask != null ? await _series(id) : null;
    if (saves) {
      final next = _updated(before!, v);
      // Names the dives already have change nothing, and a save rewrites
      // every plan of the series.
      if (next != before) await repo.saveSeries(next);
    } else if (v['name'] case final String name) {
      await repo.renameSeries(id, name);
    }
    if (ask != null) {
      // Read again after the save, which keeps each plan's link.
      final after = await _series(id);
      await _planned.write(
        await _computed(after),
        ownerId: await _ownerOf(after),
        request: ask,
        removed: _removedEntries(before!, after),
      );
    }
  }

  @override
  Future<void> delete(String id, String? ownerId) =>
      _r.divePlanSeries.deleteSeries(id);

  Future<StoredSeries> _series(String id) async =>
      await _r.divePlanSeries.getSeries(id) ??
      (throw AgentToolException(
        AgentToolErrorCode.writeRefused,
        'Series $id no longer exists.',
        details: {'id': id},
      ));

  static List<String> _texts(Object raw) => raw is String
      ? [
          for (final t
              in (const FieldCodec.textList().wire(raw) as List? ?? const []))
            '$t',
        ]
      : [for (final t in raw as List) '$t'];
}
