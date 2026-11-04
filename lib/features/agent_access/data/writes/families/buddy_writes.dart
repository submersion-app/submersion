import 'package:drift/drift.dart' show Value;

import 'package:submersion/core/database/database.dart' show BuddiesCompanion;
import 'package:submersion/features/agent_access/data/records/record_repositories.dart';
import 'package:submersion/features/agent_access/data/writes/families/merge_reach.dart';
import 'package:submersion/features/agent_access/data/writes/families/write_reach.dart';
import 'package:submersion/features/agent_access/data/writes/field_codec.dart';
import 'package:submersion/features/agent_access/data/writes/writable_entity.dart';
import 'package:submersion/features/agent_access/domain/agent_tool_error.dart';
import 'package:submersion/features/buddies/domain/entities/buddy.dart'
    as domain;
import 'package:submersion/features/documents/domain/entities/document.dart'
    show DocumentOwner, DocumentOwnerKind;

class BuddyWrites extends WritableEntry {
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
  Set<String> get requiredOnCreate => const {'name'};

  @override
  Future<DeleteReach> deleteReach(
    String id, {
    Map<String, Set<String>> alongside = const {},
  }) async {
    final documents = await countDocuments(await deletedDocumentOwners(id));
    // A dive the set deletes goes, rather than losing its buddy.
    final dives = [...?alongside['dives']];
    return DeleteReach(
      linkedDives: await countDivesByOwner(
        'SELECT d.diver_id AS owner, COUNT(*) AS n FROM dive_buddies l '
        'JOIN dives d ON d.id = l.dive_id WHERE l.buddy_id = ?1 '
        'AND d.id NOT IN (${marksFrom2(dives.length)}) GROUP BY d.diver_id',
        id,
        dives,
      ),
      records: {
        ...await countOwned({'certifications': 'buddy_id'}, id),
        if (documents > 0) 'documents': documents,
      },
      parts: await countCascaded(
        'buddies',
        id,
        except: const {'certifications', 'dive_buddies'},
      ),
      unlinked: await countUnlinked('buddies', id, except: const {'documents'}),
    );
  }

  @override
  Future<List<DocumentOwner>> deletedDocumentOwners(String id) async => [
    DocumentOwner(DocumentOwnerKind.buddy, id),
    for (final cert in await _r.certifications.getCertificationMetadataByBuddy(
      id,
    ))
      DocumentOwner(DocumentOwnerKind.certification, cert.id),
  ];

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

  @override
  bool get mergeable => true;

  /// The merged buddy's dives, cards, documents and photo tags move to the
  /// survivor, as the buddy merge moves them; the survivor keeps its own
  /// details.
  @override
  Future<DeleteReach> mergeReach(
    String id,
    String intoId, {
    Set<String> mergedBefore = const {},
  }) => linksMoved('buddies', id);

  @override
  Future<void> merge(String id, String intoId, String? ownerId) async {
    final survivor = await _r.buddies.getBuddyById(intoId);
    if (survivor == null) {
      throw AgentToolException(
        AgentToolErrorCode.writeRefused,
        'Buddy $intoId no longer exists.',
        details: {'id': intoId},
      );
    }
    await _r.buddies.mergeBuddies(
      mergedBuddy: survivor,
      buddyIds: [intoId, id],
    );
  }
}
