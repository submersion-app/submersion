import 'package:drift/drift.dart' show Variable;

import 'package:submersion/features/agent_access/data/records/record_repositories.dart';
import 'package:submersion/features/agent_access/data/writes/families/merge_reach.dart';
import 'package:submersion/features/agent_access/data/writes/field_codec.dart';
import 'package:submersion/features/agent_access/data/writes/writable_entity.dart';
import 'package:submersion/features/dive_log/data/repositories/dive_computer_merge_repository.dart';

/// A dive computer's own settings, through the repository the computer
/// page uses: the favourite star, which moves from the profile's other
/// computer, and whether it downloads on its own. A computer is named,
/// noted and deleted through its gear item, as the app keeps one record
/// for both, and is added by connecting it.
class DiveComputerWrites extends WritableEntry {
  DiveComputerWrites(this._r);

  final RecordRepositories _r;

  @override
  String get name => 'dive_computers';

  @override
  String get table => 'dive_computers';

  @override
  String get note =>
      'is_favorite takes true only: it moves the star from the profile\'s '
      'other computer. A computer\'s name and notes, and its delete, go '
      'through its gear item, equipment_id.';

  @override
  late final Map<String, FieldCodec> fields = {
    'is_favorite': const FieldCodec.flag(),
    'auto_download_disabled': const FieldCodec.flag(),
    'name': const FieldCodec.text(maxLength: 100),
    'notes': const FieldCodec.text(allowBlank: true),
  };

  @override
  Set<String> get requiredOnCreate => const {};

  @override
  Future<PlanBlock?> refuse(WriteCheck check) async {
    final item = check.document?['equipment_id'];
    final through = item == null
        ? 'its gear item'
        : 'its gear item, equipment $item';
    if (check.kind == ChangeKind.create) {
      return const PlanBlock(
        BlockReason.notPermitted,
        'A dive computer is added by connecting it, or with a computer gear '
        'item.',
      );
    }
    if (check.kind == ChangeKind.delete && check.mergeInto == null) {
      return PlanBlock(
        BlockReason.notPermitted,
        'A dive computer goes with $through.',
      );
    }
    final named = [
      for (final key in const ['name', 'notes'])
        if (check.values.containsKey(key)) key,
    ];
    if (named.isNotEmpty) {
      return PlanBlock(
        BlockReason.notPermitted,
        '${named.join(' and ')} of a dive computer change through $through.',
      );
    }
    if (check.values['is_favorite'] == false) {
      return const PlanBlock(
        BlockReason.invalidValue,
        'is_favorite: make another computer the favourite instead.',
      );
    }
    return null;
  }

  @override
  Future<SideEffects> sideEffects(
    String id,
    String? ownerId,
    RecordUpdate update,
    Map<String, Object?> document,
  ) async {
    if (update.values['is_favorite'] != true) return const SideEffects();
    final row = await _r.db
        .customSelect(
          'SELECT COUNT(*) AS n FROM dive_computers WHERE is_favorite = 1 '
          'AND id != ? AND diver_id IS ?',
          variables: [Variable.withString(id), Variable(ownerId)],
        )
        .getSingle();
    final n = row.read<int>('n');
    return SideEffects(touched: {if (n > 0) 'dive_computers': n});
  }

  @override
  Future<String> create(String diverId, Map<String, Object?> values) =>
      throw UnsupportedError('A dive computer is added by connecting it.');

  @override
  Future<void> update(String id, String? ownerId, RecordUpdate update) async {
    final v = update.values;
    if (v['is_favorite'] == true) {
      await _r.computers.setFavoriteComputer(id, diverId: ownerId);
    }
    if (v['auto_download_disabled'] case final bool off) {
      await _r.computers.setAutoDownloadDisabled(id, off);
    }
  }

  @override
  Future<void> delete(String id, String? ownerId) =>
      throw UnsupportedError('A dive computer goes with its gear item.');

  /// A duplicate computer merges into another, as the computer page merges
  /// them: its dives, profiles and tanks move to the survivor.
  @override
  bool get mergeable => true;

  @override
  Future<DeleteReach> mergeReach(
    String id,
    String intoId, {
    Set<String> mergedBefore = const {},
  }) => linksMoved('dive_computers', id);

  @override
  Future<void> merge(String id, String intoId, String? ownerId) =>
      DiveComputerMergeRepository().mergeComputers(
        survivorId: intoId,
        duplicateIds: [id],
      );
}
