import 'package:submersion/core/constants/certification_enums.dart';
import 'package:submersion/features/agent_access/data/records/record_repositories.dart';
import 'package:submersion/features/agent_access/data/writes/families/built_in_rule.dart';
import 'package:submersion/features/agent_access/data/writes/field_codec.dart';
import 'package:submersion/features/agent_access/data/writes/writable_entity.dart';
import 'package:submersion/features/agent_access/domain/agent_tool_error.dart';
import 'package:submersion/features/certification_agencies/domain/entities/certification_usage.dart';
import 'package:submersion/features/certification_agencies/domain/entities/custom_certification_agency.dart';
import 'package:submersion/features/certification_agencies/domain/entities/custom_certification_level.dart';

/// A block for a delete of an agency or level a certification or course
/// uses, which the repository would refuse.
PlanBlock? _usedBlock(CertificationUsage usage, String what) => usage.isUsed
    ? PlanBlock(
        BlockReason.notPermitted,
        'Certifications (${usage.certifications}) and courses '
        '(${usage.courses}) use this $what, and the app does not delete one '
        'in use.',
      )
    : null;

PlanBlock _nameTaken(String name) => PlanBlock(
  BlockReason.duplicateRecord,
  'name: "$name" is already the name of an agency or level the diver sees.',
);

/// Whether a rename, or sharing a record, can clash with another name, as
/// the repository decides when to check.
bool _mayClash(WriteCheck check) {
  final name = check.values['name'] as String?;
  final before = check.document?['name'] as String?;
  final renamed =
      name != null && name.toLowerCase() != (before ?? '').toLowerCase();
  final shared =
      check.values['is_shared'] == true && check.document?['is_shared'] != true;
  return check.kind == ChangeKind.create || renamed || shared;
}

/// Custom certification agencies, through the repository the certification
/// pages use. A name is free against the built-in agencies and those the
/// diver sees; an agency in use cannot be deleted, and an unused one goes
/// with its levels.
class CustomAgencyWrites extends WritableEntry {
  CustomAgencyWrites(this._r);

  final RecordRepositories _r;

  @override
  String get name => 'custom_agencies';

  @override
  String get table => 'custom_certification_agencies';

  @override
  final Map<String, FieldCodec> fields = const {
    'name': FieldCodec.text(maxLength: 100),
    'color_argb': FieldCodec.integer(min: 0, max: 0xFFFFFFFF),
    'is_shared': FieldCodec.flag(),
  };

  @override
  Set<String> get requiredOnCreate => const {'name'};

  @override
  Future<PlanBlock?> refuse(WriteCheck check) async {
    final certs = _r.customCertifications;
    if (check.kind == ChangeKind.delete) {
      return _usedBlock(await certs.agencyUsage(check.id!), 'agency');
    }
    if (!_mayClash(check)) return null;
    final name =
        check.values['name'] as String? ?? check.document!['name']! as String;
    final taken = await certs.agencyNameTaken(
      name,
      diverId: check.ownerId!,
      isShared:
          check.values['is_shared'] as bool? ??
          check.document?['is_shared'] == true,
      exceptId: check.id,
    );
    return taken ? _nameTaken(name) : null;
  }

  @override
  Future<DeleteReach> deleteReach(
    String id, {
    Map<String, Set<String>> alongside = const {},
  }) async {
    final levels = await countLinks(
      'custom_certification_levels',
      'agency_id',
      id,
    );
    return DeleteReach(
      parts: {if (levels > 0) 'custom_certification_levels': levels},
    );
  }

  @override
  Future<String> create(String diverId, Map<String, Object?> values) async =>
      (await _r.customCertifications.createAgency(
        diverId: diverId,
        name: values['name']! as String,
        colorArgb: values['color_argb'] as int?,
        isShared: values['is_shared'] as bool? ?? false,
      )).id;

  @override
  Future<void> update(String id, String? ownerId, RecordUpdate update) async {
    final certs = _r.customCertifications;
    final current = await _agency(id);
    final v = update.values;
    await certs.updateAgency(
      CustomCertificationAgency(
        id: id,
        diverId: current.diverId,
        name: v['name'] as String? ?? current.name,
        colorArgb: v['color_argb'] as int? ?? current.colorArgb,
        isShared: v['is_shared'] as bool? ?? current.isShared,
        createdAt: current.createdAt,
        updatedAt: current.updatedAt,
      ),
      actingDiverId: current.diverId,
    );
  }

  @override
  Future<void> delete(String id, String? ownerId) async {
    final current = await _agency(id);
    final usage = await _r.customCertifications.deleteAgency(
      id,
      actingDiverId: current.diverId,
    );
    if (usage != null) _refused('Agency $id is in use.', id);
  }

  Future<CustomCertificationAgency> _agency(String id) async =>
      (await _r.customCertifications.getAllAgencies())
          .where((a) => a.id == id)
          .firstOrNull ??
      _refused('Agency $id no longer exists.', id);
}

/// Custom certification levels, under a built-in agency or one of the
/// diver's own, through the repository the certification pages use. A
/// progression level moves into a slot its progression already holds, and
/// the levels between shift, as the reorder on the agency page does.
class CustomLevelWrites extends WritableEntry {
  CustomLevelWrites(this._r);

  final RecordRepositories _r;

  @override
  String get name => 'custom_levels';

  @override
  String get table => 'custom_certification_levels';

  @override
  final Map<String, FieldCodec> fields = const {
    'agency_id': FieldCodec.text(maxLength: 100),
    'name': FieldCodec.text(maxLength: 100),
    'is_progression': FieldCodec.flag(),
    'sort_order': FieldCodec.integer(min: 0, max: 9999),
    'is_shared': FieldCodec.flag(),
  };

  @override
  Set<String> get requiredOnCreate => const {'agency_id', 'name'};

  @override
  Set<String> get createOnly => const {'agency_id'};

  @override
  String get note =>
      'agency_id is a built-in agency\'s name, such as padi, or the id of '
      'one of the diver\'s custom agencies. sort_order moves a progression '
      'level into a slot its progression already holds';

  @override
  Future<PlanBlock?> refuse(WriteCheck check) async {
    final certs = _r.customCertifications;
    if (check.kind == ChangeKind.delete) {
      return _usedBlock(await certs.usage(check.id!), 'level');
    }
    final agencyId =
        check.values['agency_id'] as String? ??
        check.document!['agency_id']! as String;
    if (check.kind == ChangeKind.create) {
      final block = await _agencyBlock(agencyId, check.ownerId!);
      if (block != null) return block;
    }
    if (check.values.containsKey('sort_order')) {
      final block = await _slotBlock(check, agencyId);
      if (block != null) return block;
    }
    if (!_mayClash(check)) return null;
    final name =
        check.values['name'] as String? ?? check.document!['name']! as String;
    final taken = await certs.levelNameTaken(
      name,
      agencyId: agencyId,
      diverId: check.ownerId!,
      isShared:
          check.values['is_shared'] as bool? ??
          check.document?['is_shared'] == true,
      exceptId: check.id,
    );
    return taken ? _nameTaken(name) : null;
  }

  /// A block unless [agencyId] is a built-in agency or one of [ownerId]'s.
  Future<PlanBlock?> _agencyBlock(String agencyId, String ownerId) async {
    if (CertificationAgency.fromId(agencyId) != null) return null;
    final agency = (await _r.customCertifications.getAllAgencies())
        .where((a) => a.id == agencyId)
        .firstOrNull;
    if (agency == null) {
      return PlanBlock(
        BlockReason.unknownReference,
        'agency_id: $agencyId is neither a built-in agency nor a custom one.',
      );
    }
    if (agency.diverId != ownerId) {
      return const PlanBlock(
        BlockReason.notPermitted,
        'agency_id: a custom agency\'s levels belong to the diver who made it.',
      );
    }
    return null;
  }

  /// A block unless the level is on its progression and the order it asks
  /// for is a slot that progression holds.
  Future<PlanBlock?> _slotBlock(WriteCheck check, String agencyId) async {
    if (check.document?['is_progression'] != true ||
        check.values.containsKey('is_progression')) {
      return const PlanBlock(
        BlockReason.invalidValue,
        'sort_order: only a level already on its agency\'s progression has '
        'an order; change is_progression in a change of its own.',
      );
    }
    final slots = [
      for (final level in await _rungs(agencyId, check.ownerId!))
        level.sortOrder,
    ];
    if (slots.contains(check.values['sort_order'])) return null;
    return PlanBlock(
      BlockReason.invalidValue,
      'sort_order: the progression holds slots ${slots.join(', ')}.',
    );
  }

  @override
  Future<String> create(String diverId, Map<String, Object?> values) async =>
      (await _r.customCertifications.createLevel(
        diverId: diverId,
        agencyId: values['agency_id']! as String,
        name: values['name']! as String,
        isProgression: values['is_progression'] as bool? ?? false,
        isShared: values['is_shared'] as bool? ?? false,
      )).id;

  @override
  Future<void> update(String id, String? ownerId, RecordUpdate update) async {
    final certs = _r.customCertifications;
    final current = await _level(id);
    final v = update.values;
    if (v.keys.any(const {'name', 'is_progression', 'is_shared'}.contains)) {
      await certs.updateLevel(
        CustomCertificationLevel(
          id: id,
          diverId: current.diverId,
          agencyId: current.agencyId,
          name: v['name'] as String? ?? current.name,
          isProgression: v['is_progression'] as bool? ?? current.isProgression,
          sortOrder: current.sortOrder,
          isShared: v['is_shared'] as bool? ?? current.isShared,
          createdAt: current.createdAt,
          updatedAt: current.updatedAt,
        ),
        actingDiverId: current.diverId,
      );
    }
    if (v['sort_order'] case final int slot) {
      // The rungs trade the slots they hold, so this one lands in [slot]
      // and the rungs between shift by one.
      final rungs = await _rungs(current.agencyId, current.diverId);
      final slots = [for (final level in rungs) level.sortOrder];
      final ordered = [
        for (final level in rungs)
          if (level.id != id) level.id,
      ]..insert(slots.indexOf(slot), id);
      await certs.reorderProgression(
        current.agencyId,
        ordered,
        actingDiverId: current.diverId,
      );
    }
  }

  @override
  Future<void> delete(String id, String? ownerId) async {
    final current = await _level(id);
    final usage = await _r.customCertifications.deleteLevel(
      id,
      actingDiverId: current.diverId,
    );
    if (usage != null) _refused('Level $id is in use.', id);
  }

  /// [diverId]'s progression levels of [agencyId], in order.
  Future<List<CustomCertificationLevel>> _rungs(
    String agencyId,
    String diverId,
  ) async => [
    for (final level in await _r.customCertifications.getAllLevels())
      if (level.agencyId == agencyId &&
          level.diverId == diverId &&
          level.isProgression)
        level,
  ]..sort((a, b) => a.sortOrder.compareTo(b.sortOrder));

  Future<CustomCertificationLevel> _level(String id) async =>
      (await _r.customCertifications.getAllLevels())
          .where((l) => l.id == id)
          .firstOrNull ??
      _refused('Level $id no longer exists.', id);
}

Never _refused(String message, String id) => throw AgentToolException(
  AgentToolErrorCode.writeRefused,
  message,
  details: {'id': id},
);
