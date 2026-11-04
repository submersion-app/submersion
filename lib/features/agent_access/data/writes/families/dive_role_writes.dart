import 'package:submersion/features/agent_access/data/records/record_repositories.dart';
import 'package:submersion/features/agent_access/data/writes/families/built_in_rule.dart';
import 'package:submersion/features/agent_access/data/writes/field_codec.dart';
import 'package:submersion/features/agent_access/data/writes/writable_entity.dart';

/// Dive roles, through the repository the dive roles page uses: a custom
/// role is named and renamed, a built-in one stays as the app ships it, and
/// a role a dive uses cannot be deleted.
class DiveRoleWrites extends WritableEntry {
  DiveRoleWrites(this._r);

  final RecordRepositories _r;

  @override
  String get name => 'dive_roles';

  @override
  String get table => 'dive_roles';

  @override
  final Map<String, FieldCodec> fields = const {
    'name': FieldCodec.text(maxLength: 60, trim: true),
  };

  @override
  Set<String> get requiredOnCreate => const {'name'};

  @override
  Future<PlanBlock?> refuse(WriteCheck check) async =>
      builtInBlock(check, 'dive roles') ??
      await inUseBlock(check, 'role', _r.diveRoles.isDiveRoleInUse);

  @override
  Future<String> create(String diverId, Map<String, Object?> values) async =>
      (await _r.diveRoles.createDiveRole(
        name: values['name']! as String,
        diverId: diverId,
      )).id;

  @override
  Future<void> update(String id, String? ownerId, RecordUpdate update) async {
    if (update.values['name'] case final String name) {
      await _r.diveRoles.renameDiveRole(id, name);
    }
  }

  @override
  Future<void> delete(String id, String? ownerId) =>
      _r.diveRoles.deleteDiveRole(id);
}
