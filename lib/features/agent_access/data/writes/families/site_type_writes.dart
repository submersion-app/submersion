import 'package:submersion/features/agent_access/data/records/record_repositories.dart';
import 'package:submersion/features/agent_access/data/writes/families/built_in_rule.dart';
import 'package:submersion/features/agent_access/data/writes/field_codec.dart';
import 'package:submersion/features/agent_access/data/writes/writable_entity.dart';
import 'package:submersion/features/agent_access/domain/agent_tool_error.dart';
import 'package:submersion/features/site_types/domain/entities/site_type_entity.dart';

/// Site types, through the repository the site types page uses. A built-in
/// type stays as the app ships it; deleting a custom one takes it off every
/// site using it, as the page warns.
class SiteTypeWrites extends WritableEntry {
  SiteTypeWrites(this._r);

  final RecordRepositories _r;

  @override
  String get name => 'site_types';

  @override
  String get table => 'site_types';

  @override
  final Map<String, FieldCodec> fields = const {
    'name': FieldCodec.text(maxLength: 60, trim: true),
    'sort_order': FieldCodec.integer(min: 0, max: 999),
  };

  @override
  Set<String> get requiredOnCreate => const {'name'};

  @override
  Future<PlanBlock?> refuse(WriteCheck check) async =>
      builtInBlock(check, 'site types') ?? appendSlotBlock(check);

  @override
  Future<DeleteReach> deleteReach(
    String id, {
    Map<String, Set<String>> alongside = const {},
  }) async {
    final sites = await countLinks('site_site_types', 'site_type_id', id);
    return DeleteReach(unlinked: {if (sites > 0) 'site_site_types': sites});
  }

  @override
  Future<String> create(String diverId, Map<String, Object?> values) async =>
      (await _r.siteTypes.createSiteType(
        SiteTypeEntity.create(
          id: '',
          name: values['name']! as String,
          diverId: diverId,
          sortOrder: values['sort_order'] as int? ?? 0,
        ),
      )).id;

  @override
  Future<void> update(String id, String? ownerId, RecordUpdate update) async {
    final current = await _r.siteTypes.getSiteTypeById(id) ?? _gone(id);
    await _r.siteTypes.updateSiteType(
      current.copyWith(
        name: update.values['name'] as String?,
        sortOrder: update.values['sort_order'] as int?,
      ),
    );
  }

  @override
  Future<void> delete(String id, String? ownerId) =>
      _r.siteTypes.deleteSiteType(id);

  Never _gone(String id) => throw AgentToolException(
    AgentToolErrorCode.writeRefused,
    'Site type $id no longer exists.',
    details: {'id': id},
  );
}
