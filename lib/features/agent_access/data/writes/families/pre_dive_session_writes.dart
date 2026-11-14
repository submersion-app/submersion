import 'package:drift/drift.dart' show Variable;

import 'package:submersion/features/agent_access/data/records/record_repositories.dart';
import 'package:submersion/features/agent_access/data/writes/families/write_reach.dart';
import 'package:submersion/features/agent_access/data/writes/field_codec.dart';
import 'package:submersion/features/agent_access/data/writes/writable_entity.dart';
import 'package:submersion/features/agent_access/domain/agent_tool_error.dart';
import 'package:submersion/features/pre_dive/domain/entities/pre_dive_checklist_template.dart';
import 'package:submersion/features/pre_dive/domain/entities/pre_dive_session.dart';
import 'package:submersion/features/pre_dive/domain/services/checklist_session_engine.dart';
import 'package:submersion/features/pre_dive/domain/services/session_item_composer.dart';

/// Pre-dive checklist runs, through the repository the start sheet and the
/// runner use. A run starts from a template's snapshot, ends completed or
/// aborted and is locked from then on; its dive link stays editable.
class PreDiveSessionWrites extends WritableEntry {
  PreDiveSessionWrites(this._r);

  final RecordRepositories _r;

  static const _contents = {
    'pre_dive_session_items': 'session_id',
    'pre_dive_session_sections': 'session_id',
  };

  @override
  String get name => 'pre_dive_sessions';

  @override
  String get table => 'pre_dive_sessions';

  @override
  String get note =>
      'A run starts from template_id, with equipment_set_id for a template '
      'that checks a set. Its items are pre_dive_session_items. status moves '
      'from inProgress to completed (every required item done or flagged) '
      'or aborted, and the run is locked from then on; dive_id stays '
      'editable, one run to a dive.';

  @override
  late final Map<String, FieldCodec> fields = {
    'template_id': const FieldCodec.reference('pre_dive_templates'),
    'equipment_set_id': const FieldCodec.reference(
      'equipment_sets',
      nullable: true,
    ),
    'trip_id': const FieldCodec.reference('trips', nullable: true),
    'dive_id': const FieldCodec.reference('dives', nullable: true),
    'status': FieldCodec.enumName(PreDiveSessionStatus.values),
  };

  @override
  Set<String> get requiredOnCreate => const {'template_id'};

  @override
  Set<String> get createOnly => const {
    'template_id',
    'equipment_set_id',
    'trip_id',
  };

  @override
  String? titleOf(Map<String, Object?> document) =>
      document['template_name'] as String?;

  @override
  UniqueClaim? uniqueKey(WriteCheck check) => switch (check.values['dive_id']) {
    final String diveId => UniqueClaim('pre-dive/$diveId'),
    _ => null,
  };

  @override
  Future<Map<String, int>> alsoCreates(
    String diverId,
    Map<String, Object?> values,
  ) async {
    final templateId = values['template_id']! as String;
    final repo = _r.preDiveTemplates;
    final items = (await repo.getItemsForTemplate(templateId)).length;
    final sections = (await repo.getSectionsForTemplate(templateId)).length;
    return {
      if (items > 0) 'pre_dive_session_items': items,
      if (sections > 0) 'pre_dive_session_sections': sections,
    };
  }

  @override
  Future<PlanBlock?> refuse(WriteCheck check) async {
    if (check.kind == ChangeKind.delete) return null;
    final v = check.values;
    if (v['dive_id'] case final String diveId) {
      final other = await _r.preDiveSessions.getSessionForDive(diveId);
      if (other != null && other.id != check.id) {
        return PlanBlock(
          BlockReason.duplicateRecord,
          'dive_id: dive $diveId has a pre-dive run already, ${other.id}.',
        );
      }
    }
    final status = v['status'] as String?;
    if (check.kind == ChangeKind.create) {
      return status == null || status == PreDiveSessionStatus.inProgress.name
          ? null
          : const PlanBlock(
              BlockReason.invalidValue,
              'status: a run starts in progress.',
            );
    }
    if (status == null) return null;
    if (check.document?['status'] != PreDiveSessionStatus.inProgress.name) {
      return const PlanBlock(
        BlockReason.notPermitted,
        'status: a finished run stays as it ended.',
      );
    }
    if (status == PreDiveSessionStatus.inProgress.name) return null;
    if (status == PreDiveSessionStatus.completed.name) {
      final items = [
        for (final item in await _r.preDiveSessions.getItemsForSession(
          check.id!,
        ))
          switch (check.soFar.values[(
            'pre_dive_session_items',
            item.id,
          )]?['state']) {
            final String state => item.copyWith(
              state: PreDiveItemState.parse(state),
            ),
            _ => item,
          },
      ];
      if (!ChecklistSessionEngine.canComplete(items)) {
        return const PlanBlock(
          BlockReason.invalidValue,
          'status: every required item is done or flagged before a run '
          'completes.',
        );
      }
    }
    return null;
  }

  @override
  Future<DeleteReach> deleteReach(
    String id, {
    Map<String, Set<String>> alongside = const {},
  }) async => DeleteReach(parts: await countOwned(_contents, id));

  @override
  Future<String> create(String diverId, Map<String, Object?> values) async {
    final templateId = values['template_id']! as String;
    final repo = _r.preDiveTemplates;
    final template =
        await repo.getTemplateById(templateId) ??
        (throw AgentToolException(
          AgentToolErrorCode.writeRefused,
          'Pre-dive template $templateId no longer exists.',
          details: {'id': templateId},
        ));
    final templateItems = await repo.getItemsForTemplate(templateId);
    final setId = values['equipment_set_id'] as String?;
    final set =
        setId == null ||
            !templateItems.any(
              (i) => i.itemType == PreDiveItemType.equipmentSet,
            )
        ? null
        : await _r.equipmentSets.getSetById(setId);
    final all = await _r.equipment.getAllEquipment(diverId: diverId);
    // What the set applies: its own gear and that of the sets it includes
    // (issue #4525), as the start sheet checks it. The lead and cylinder
    // checks the sheet adds are worded in the diver's units and language,
    // which this path does not have.
    final setGearIds = set == null
        ? null
        : await _r.equipmentSets.getEffectiveEquipmentIds(set.id);
    // The set's members bar the wishlist, which is not in the kit, as the
    // start sheet checks them; single items keep their remembered device.
    final gear = [
      for (final g in all)
        if (!g.isWanted &&
            ((setGearIds?.contains(g.id) ?? false) ||
                templateItems.any((i) => i.equipmentId == g.id)))
          g,
    ];
    final composed = SessionItemComposer.compose(
      templateItems: templateItems,
      templateSections: await repo.getSectionsForTemplate(templateId),
      equipmentSet: set,
      equipmentSetGearIds: setGearIds,
      equipmentItems: gear,
      now: DateTime.now(),
    );
    final session = await _r.preDiveSessions.startSession(
      template: template,
      items: composed.items,
      sections: composed.sections,
      diverId: diverId,
      diveId: values['dive_id'] as String?,
      tripId: values['trip_id'] as String?,
      equipmentSetId: set?.id,
      equipmentSetName: set?.name,
    );
    return session.id;
  }

  @override
  Future<void> update(String id, String? ownerId, RecordUpdate update) async {
    final v = update.values;
    final repo = _r.preDiveSessions;
    if (v.containsKey('dive_id')) {
      final diveId = v['dive_id'] as String?;
      if (diveId == null) {
        await repo.unlinkFromDive(id);
      } else {
        await repo.linkToDive(id, diveId);
      }
    }
    switch (v['status']) {
      case 'completed':
        await repo.completeSession(id);
      case 'aborted':
        await repo.abortSession(id);
    }
  }

  @override
  Future<void> delete(String id, String? ownerId) =>
      _r.preDiveSessions.deleteSession(id);
}

/// One item of a pre-dive run, as the runner ticks it: done, skipped,
/// flagged or back to pending, with its reading and a note. Items come
/// from the template; a run's items are neither added nor removed.
class PreDiveSessionItemWrites extends WritableEntry {
  PreDiveSessionItemWrites(this._r);

  final RecordRepositories _r;

  @override
  String get name => 'pre_dive_session_items';

  @override
  String get table => 'pre_dive_session_items';

  @override
  ChildOf get parent =>
      const ChildOf(entity: 'pre_dive_sessions', field: 'session_id');

  @override
  String get note =>
      'A locked run\'s items do not change. In a strict-order run only the '
      'next pending item may be resolved.';

  @override
  late final Map<String, FieldCodec> fields = {
    'session_id': const FieldCodec.reference('pre_dive_sessions'),
    'state': FieldCodec.enumName(PreDiveItemState.values),
    // A reading is written over, as the runner records one; the store never
    // clears it, so null is not offered.
    'value_number': const FieldCodec.number(),
    'value_text': const FieldCodec.text(maxLength: 500, trim: true),
    'note': const FieldCodec.text(allowBlank: true, trim: true),
  };

  @override
  Set<String> get requiredOnCreate => const {};

  @override
  String? titleOf(Map<String, Object?> document) =>
      document['title'] as String?;

  @override
  Future<PlanBlock?> refuse(WriteCheck check) async {
    if (check.kind != ChangeKind.update) {
      return const PlanBlock(
        BlockReason.notPermitted,
        'A run\'s items come from its template; they are not added or '
        'removed.',
      );
    }
    final sessionId = check.document!['session_id']! as String;
    final session = await _r.preDiveSessions.getSessionById(sessionId);
    if (session == null || session.isLocked) {
      return const PlanBlock(
        BlockReason.notPermitted,
        'This run is finished; its items stay as they were.',
      );
    }
    final leaving =
        check.document!['state'] == PreDiveItemState.pending.name &&
        check.values['state'] != null &&
        check.values['state'] != PreDiveItemState.pending.name;
    if (!session.strictOrder || !leaving) return null;
    final items = [
      for (final item in await _r.preDiveSessions.getItemsForSession(sessionId))
        switch (check.soFar.values[(name, item.id)]?['state']) {
          final String state => item.copyWith(
            state: PreDiveItemState.parse(state),
          ),
          _ => item,
        },
    ]..sort((a, b) => a.sortOrder.compareTo(b.sortOrder));
    final next = ChecklistSessionEngine.nextActionableItem(session, items);
    if (next?.id == check.id) return null;
    return PlanBlock(
      BlockReason.notPermitted,
      'This run keeps strict order; the next item is ${next?.id}.',
    );
  }

  @override
  Future<String> create(String diverId, Map<String, Object?> values) =>
      throw UnsupportedError('A run\'s items come from its template.');

  @override
  Future<void> update(String id, String? ownerId, RecordUpdate update) async {
    final rows = await _r.db
        .customSelect(
          'SELECT session_id FROM pre_dive_session_items WHERE id = ?',
          variables: [Variable.withString(id)],
        )
        .get();
    final sessionId = rows.isEmpty
        ? null
        : rows.single.read<String>('session_id');
    final items = sessionId == null
        ? const <PreDiveSessionItem>[]
        : await _r.preDiveSessions.getItemsForSession(sessionId);
    final current =
        items.where((i) => i.id == id).firstOrNull ??
        (throw AgentToolException(
          AgentToolErrorCode.writeRefused,
          'Pre-dive item $id no longer exists.',
          details: {'id': id},
        ));
    final v = update.values;
    final state = switch (v['state']) {
      final String s => PreDiveItemState.parse(s),
      _ => current.state,
    };
    // A cell linearity check freezes the air reading it was made against.
    final source = current.sourceItemId == null
        ? null
        : items.where((i) => i.id == current.sourceItemId).firstOrNull;
    await _r.preDiveSessions.updateItemState(
      sessionId: sessionId!,
      itemId: id,
      state: state,
      valueNumber: (v['value_number'] as num?)?.toDouble(),
      valueText: v['value_text'] as String?,
      note: v['note'] as String?,
      overdueServices: current.overdueServices,
      sourceValueNumber: source?.valueNumber,
    );
  }

  @override
  Future<void> delete(String id, String? ownerId) =>
      throw UnsupportedError('A run\'s items come from its template.');
}
