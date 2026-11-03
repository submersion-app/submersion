import 'package:submersion/features/agent_access/data/records/record_repositories.dart';
import 'package:submersion/features/agent_access/data/writes/families/built_in_rule.dart';
import 'package:submersion/features/agent_access/data/writes/field_codec.dart';
import 'package:submersion/features/agent_access/data/writes/writable_entity.dart';
import 'package:submersion/features/agent_access/domain/agent_tool_error.dart';
import 'package:submersion/features/dive_types/domain/entities/dive_type_entity.dart';

/// Dive types, through the repository the dive types page uses. A built-in
/// type keeps its name and order and stays; only where its badge shows may
/// change. A type a dive uses cannot be deleted.
class DiveTypeWrites extends WritableEntry {
  DiveTypeWrites(this._r);

  final RecordRepositories _r;

  static const _visibility = {'show_in_detail_header', 'show_in_list_view'};

  @override
  String get name => 'dive_types';

  @override
  String get table => 'dive_types';

  @override
  final Map<String, FieldCodec> fields = const {
    'name': FieldCodec.text(maxLength: 60),
    'short_name': FieldCodec.text(maxLength: 12, nullable: true),
    'sort_order': FieldCodec.integer(min: 0, max: 999),
    'show_in_detail_header': FieldCodec.flag(),
    'show_in_list_view': FieldCodec.flag(),
  };

  @override
  Set<String> get requiredOnCreate => const {'name'};

  @override
  Future<PlanBlock?> refuse(WriteCheck check) async =>
      builtInBlock(check, 'dive types', allowed: _visibility) ??
      appendSlotBlock(check) ??
      await inUseBlock(check, 'dive type', (id) => _stillInUse(id, check));

  /// Whether a dive still carries type [id] once the set's earlier changes
  /// run, counted as isDiveTypeInUse counts it.
  Future<bool> _stillInUse(String id, WriteCheck check) async {
    final freed = [...?check.soFar.unlinked[('dive_types', id)]?['dives']];
    final count = await countLinks(
      'dive_dive_types',
      'dive_type_id',
      id,
      except: ('dive_id', freed),
    );
    return count > 0;
  }

  @override
  Future<String> create(String diverId, Map<String, Object?> values) async {
    final type = await _r.diveTypes.createDiveType(
      DiveTypeEntity.create(
        id: '',
        name: values['name']! as String,
        diverId: diverId,
        sortOrder: values['sort_order'] as int? ?? 0,
        shortName: values['short_name'] as String?,
        showInDetailHeader: values['show_in_detail_header'] as bool? ?? true,
        showInListView: values['show_in_list_view'] as bool? ?? true,
      ),
    );
    return type.id;
  }

  @override
  Future<void> update(String id, String? ownerId, RecordUpdate update) async {
    final current = await _r.diveTypes.getDiveTypeById(id) ?? _gone(id);
    final v = update.values;
    if (current.isBuiltIn) {
      return _r.diveTypes.setDiveTypeVisibility(
        id,
        showInDetailHeader:
            v['show_in_detail_header'] as bool? ?? current.showInDetailHeader,
        showInListView:
            v['show_in_list_view'] as bool? ?? current.showInListView,
      );
    }
    await _r.diveTypes.updateDiveType(
      current.copyWith(
        name: v['name'] as String?,
        shortName: v.containsKey('short_name')
            ? v['short_name'] as String?
            : current.shortName,
        sortOrder: v['sort_order'] as int?,
        showInDetailHeader: v['show_in_detail_header'] as bool?,
        showInListView: v['show_in_list_view'] as bool?,
      ),
    );
  }

  @override
  Future<void> delete(String id, String? ownerId) =>
      _r.diveTypes.deleteDiveType(id);

  Never _gone(String id) => throw AgentToolException(
    AgentToolErrorCode.writeRefused,
    'Dive type $id no longer exists.',
    details: {'id': id},
  );
}
