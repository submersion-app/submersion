import 'package:drift/drift.dart' show Value;

import 'package:submersion/core/database/database.dart' show BuddiesCompanion;
import 'package:submersion/features/agent_access/data/records/record_repositories.dart';
import 'package:submersion/features/agent_access/data/writes/field_codec.dart';
import 'package:submersion/features/agent_access/data/writes/writable_entity.dart';
import 'package:submersion/features/buddies/domain/entities/buddy.dart'
    as domain;

class BuddyWrites implements WritableEntry {
  BuddyWrites(this._r);

  final RecordRepositories _r;

  @override
  String get name => 'buddies';

  @override
  String get table => 'buddies';

  @override
  final Map<String, FieldCodec> fields = const {
    'name': FieldCodec.text(maxLength: 200),
    'email': FieldCodec.text(maxLength: 320, nullable: true),
    'phone': FieldCodec.text(maxLength: 60, nullable: true),
    'social_handle': FieldCodec.text(maxLength: 200, nullable: true),
    'notes': FieldCodec.text(allowBlank: true),
    'is_favorite': FieldCodec.flag(),
    'excluded_from_rankings': FieldCodec.flag(),
  };

  @override
  Map<String, RelationSpec> get relations => const {};

  @override
  Set<String> get requiredOnCreate => const {'name'};

  @override
  Future<Set<String>> currentRelation(String id, String relation) async =>
      const {};

  @override
  Future<PlanBlock?> refuse(WriteCheck check) async => null;

  @override
  Future<String> create(String diverId, Map<String, Object?> values) async {
    final now = DateTime.now();
    final buddy = await _r.buddies.createBuddy(
      domain.Buddy(
        id: '',
        diverId: diverId,
        name: values['name']! as String,
        email: values['email'] as String?,
        phone: values['phone'] as String?,
        socialHandle: values['social_handle'] as String?,
        notes: values['notes'] as String? ?? '',
        isFavorite: values['is_favorite'] as bool? ?? false,
        excludedFromRankings:
            values['excluded_from_rankings'] as bool? ?? false,
        createdAt: now,
        updatedAt: now,
      ),
    );
    return buddy.id;
  }

  @override
  Future<void> update(String id, String? ownerId, RecordUpdate update) {
    final v = update.values;
    Value<T> field<T>(String key) =>
        v.containsKey(key) ? Value(v[key] as T) : const Value.absent();
    return _r.buddies.updateFields(
      id,
      BuddiesCompanion(
        name: field('name'),
        email: field('email'),
        phone: field('phone'),
        socialHandle: field('social_handle'),
        notes: field('notes'),
        isFavorite: field('is_favorite'),
        excludedFromRankings: field('excluded_from_rankings'),
      ),
    );
  }

  @override
  Future<void> delete(String id, String? ownerId) => _r.buddies.deleteBuddy(id);
}
