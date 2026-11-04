import 'package:submersion/features/agent_access/data/records/record_repositories.dart';
import 'package:submersion/features/agent_access/data/writes/field_codec.dart';
import 'package:submersion/features/agent_access/data/writes/writable_entity.dart';

/// A dive's safety findings, which the safety review writes; a diver only
/// dismisses one, or restores it, as the dive's safety card does. The dive
/// is marked for sync with it, so the change reaches other devices.
class SafetyFindingWrites extends WritableEntry {
  SafetyFindingWrites(this._r);

  final RecordRepositories _r;

  @override
  String get name => 'safety_findings';

  @override
  String get table => 'dive_safety_findings';

  @override
  ChildOf get parent => const ChildOf(entity: 'dives', field: 'dive_id');

  @override
  String get note =>
      'A finding comes from the safety review; dismissed hides it from the '
      'dive, and false restores it.';

  @override
  late final Map<String, FieldCodec> fields = {
    'dive_id': const FieldCodec.reference('dives'),
    'dismissed': const FieldCodec.flag(),
  };

  @override
  Set<String> get requiredOnCreate => const {};

  @override
  String? titleOf(Map<String, Object?> document) =>
      document['rule_id'] as String?;

  /// Dismissal as the flag a write takes, from the moment a read shows.
  @override
  Future<Map<String, Object?>> stored(
    String id,
    Map<String, Object?> document,
  ) async => {...document, 'dismissed': document['dismissed_at'] != null};

  @override
  Future<PlanBlock?> refuse(WriteCheck check) async =>
      check.kind == ChangeKind.update
      ? null
      : const PlanBlock(
          BlockReason.notPermitted,
          'A finding comes from the safety review; it is dismissed, not '
          'added or deleted.',
        );

  @override
  Future<SideEffects> sideEffects(
    String id,
    String? ownerId,
    RecordUpdate update,
    Map<String, Object?> document,
  ) async => const SideEffects(touched: {'dives': 1});

  @override
  Future<String> create(String diverId, Map<String, Object?> values) =>
      throw UnsupportedError('A finding comes from the safety review.');

  @override
  Future<void> update(String id, String? ownerId, RecordUpdate update) async {
    if (update.values['dismissed'] case final bool dismissed) {
      await _r.safetyFindings.setDismissed(
        findingId: id,
        dismissed: dismissed,
        now: DateTime.now(),
      );
    }
  }

  @override
  Future<void> delete(String id, String? ownerId) =>
      throw UnsupportedError('A finding comes from the safety review.');
}
