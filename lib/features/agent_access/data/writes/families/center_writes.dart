import 'dart:convert';

import 'package:submersion/features/agent_access/data/records/record_repositories.dart';
import 'package:submersion/features/agent_access/data/writes/families/write_reach.dart';
import 'package:submersion/features/agent_access/data/writes/field_codec.dart';
import 'package:submersion/features/agent_access/data/writes/writable_entity.dart';
import 'package:submersion/features/agent_access/domain/agent_tool_error.dart';
import 'package:submersion/features/dive_centers/domain/entities/dive_center.dart';
import 'package:submersion/features/documents/domain/entities/document.dart'
    show DocumentOwner, DocumentOwnerKind;

/// Dive centers, through the repository the center pages use. A center has a
/// position or none, and fill hours or none; deleting one takes it off its
/// dives, fills and places and takes its documents and gear notes.
class CenterWrites extends WritableEntry {
  CenterWrites(this._r);

  final RecordRepositories _r;

  @override
  String get name => 'centers';

  @override
  String get table => 'dive_centers';

  @override
  late final Map<String, FieldCodec> fields = {
    'name': const FieldCodec.text(maxLength: 200),
    for (final key in const [
      'street',
      'city',
      'state_province',
      'postal_code',
      'country',
      'phone',
      'email',
      'website',
    ])
      key: const FieldCodec.text(maxLength: 200, nullable: true),
    'affiliations': const FieldCodec.textList(
      maxItems: 20,
      maxLength: 60,
      separator: ',',
    ),
    'latitude': const FieldCodec.number(min: -90, max: 90, nullable: true),
    'longitude': const FieldCodec.number(min: -180, max: 180, nullable: true),
    'rating': const FieldCodec.number(min: 0, max: 5, nullable: true),
    'notes': const FieldCodec.text(allowBlank: true),
    'fill_opens_at_min': const FieldCodec.integer(
      min: 0,
      max: 1439,
      nullable: true,
    ),
    'fill_closes_at_min': const FieldCodec.integer(
      min: 0,
      max: 1439,
      nullable: true,
    ),
    'is_permanently_closed': const FieldCodec.flag(),
  };

  @override
  Set<String> get requiredOnCreate => const {'name'};

  @override
  Future<PlanBlock?> refuse(WriteCheck check) async =>
      _pairBlock(check, 'latitude', 'longitude') ??
      _pairBlock(check, 'fill_opens_at_min', 'fill_closes_at_min');

  /// A block when the change leaves one of [a] and [b] set without the
  /// other, as the center editor never stores.
  PlanBlock? _pairBlock(WriteCheck check, String a, String b) {
    final values = check.values;
    if (!values.containsKey(a) && !values.containsKey(b)) return null;
    Object? pick(String key) =>
        values.containsKey(key) ? values[key] : check.document?[key];
    if ((pick(a) == null) == (pick(b) == null)) return null;
    return PlanBlock(
      BlockReason.invalidValue,
      '$a and $b are set or cleared together.',
    );
  }

  @override
  Future<DeleteReach> deleteReach(
    String id, {
    Map<String, Set<String>> alongside = const {},
  }) async {
    final documents = await countDocuments(await deletedDocumentOwners(id));
    // A dive the set deletes goes, rather than losing its center.
    final dives = [...?alongside['dives']];
    return DeleteReach(
      linkedDives: await countDivesByOwner(
        'SELECT diver_id AS owner, COUNT(*) AS n FROM dives '
        'WHERE dive_center_id = ?1 AND id NOT IN (${marksFrom2(dives.length)}) '
        'GROUP BY diver_id',
        id,
        dives,
      ),
      records: {if (documents > 0) 'documents': documents},
      parts: await countCascaded('dive_centers', id),
      unlinked: await countUnlinked(
        'dive_centers',
        id,
        except: const {'dives', 'documents'},
      ),
    );
  }

  @override
  Future<List<DocumentOwner>> deletedDocumentOwners(String id) async => [
    DocumentOwner(DocumentOwnerKind.diveCenter, id),
  ];

  @override
  Future<String> create(String diverId, Map<String, Object?> values) async {
    final now = DateTime.now();
    final blank = DiveCenter(
      id: '',
      diverId: diverId,
      name: values['name']! as String,
      createdAt: now,
      updatedAt: now,
    );
    return (await _r.centers.createDiveCenter(_applied(blank, values))).id;
  }

  @override
  Future<void> update(String id, String? ownerId, RecordUpdate update) async {
    final current = await _r.centers.getDiveCenterById(id);
    if (current == null) {
      throw AgentToolException(
        AgentToolErrorCode.writeRefused,
        'Dive center $id no longer exists.',
        details: {'id': id},
      );
    }
    await _r.centers.updateDiveCenter(_applied(current, update.values));
  }

  @override
  Future<void> delete(String id, String? ownerId) =>
      _r.centers.deleteDiveCenter(id);

  /// [center] with the named values, a key sent as null cleared.
  DiveCenter _applied(DiveCenter center, Map<String, Object?> v) {
    T? kept<T>(String key, T? now) => v.containsKey(key) ? v[key] as T? : now;
    final affiliations = v['affiliations'];
    return DiveCenter(
      id: center.id,
      diverId: center.diverId,
      name: v['name'] as String? ?? center.name,
      street: kept('street', center.street),
      city: kept('city', center.city),
      stateProvince: kept('state_province', center.stateProvince),
      postalCode: kept('postal_code', center.postalCode),
      latitude: kept('latitude', center.latitude),
      longitude: kept('longitude', center.longitude),
      country: kept('country', center.country),
      phone: kept('phone', center.phone),
      email: kept('email', center.email),
      website: kept('website', center.website),
      affiliations: affiliations is String
          ? [for (final a in jsonDecode(affiliations) as List) '$a']
          : center.affiliations,
      rating: kept('rating', center.rating),
      notes: v['notes'] as String? ?? center.notes,
      fillOpensAt: kept('fill_opens_at_min', center.fillOpensAt),
      fillClosesAt: kept('fill_closes_at_min', center.fillClosesAt),
      isPermanentlyClosed:
          v['is_permanently_closed'] as bool? ?? center.isPermanentlyClosed,
      createdAt: center.createdAt,
      updatedAt: center.updatedAt,
    );
  }
}
