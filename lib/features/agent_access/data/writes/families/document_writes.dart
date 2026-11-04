import 'package:drift/drift.dart' show Variable;

import 'package:submersion/core/services/logger_service.dart';
import 'package:submersion/features/agent_access/data/records/record_catalog.dart';
import 'package:submersion/features/agent_access/data/records/record_reader.dart';
import 'package:submersion/features/agent_access/data/records/record_repositories.dart';
import 'package:submersion/features/agent_access/data/writes/families/service_ledger_rules.dart';
import 'package:submersion/features/agent_access/data/writes/families/write_reach.dart';
import 'package:submersion/features/agent_access/data/writes/field_codec.dart';
import 'package:submersion/features/agent_access/data/writes/writable_entity.dart';
import 'package:submersion/features/agent_access/domain/agent_tool_error.dart';
import 'package:submersion/features/documents/data/repositories/document_row_mapper.dart';
import 'package:submersion/features/documents/domain/entities/document.dart';

/// Re-arms the expiry reminders of saved documents, as the documents page
/// does after a save.
typedef DocumentRearm = Future<void> Function(Iterable<Document> documents);

/// A diver's documents, through the repository the documents page saves
/// with: their details only, since pages are files and stay in the app.
/// A save keeps the pages it holds; an insurance document can be the
/// primary one, which takes over from the profile's other.
class DocumentWrites extends WritableEntry {
  DocumentWrites(this._r, {DocumentRearm? rearm}) : _rearm = rearm;

  final RecordRepositories _r;
  final DocumentRearm? _rearm;

  static final _log = LoggerService.forClass(DocumentWrites);

  static const _insuranceOnly = ['phone', 'emergency_phone'];

  @override
  String get name => 'documents';

  @override
  String get table => 'documents';

  @override
  String get note =>
      'A document is written as its details; its pages are added in the '
      'app. owner_kind and owner_id attach it to a record, personal for '
      'none. phone, emergency_phone and is_primary are an insurance '
      'document\'s; is_primary takes over from the profile\'s other.';

  @override
  late final Map<String, FieldCodec> fields = {
    'type': FieldCodec.enumName(DocumentType.values),
    'owner_kind': FieldCodec.enumName(DocumentOwnerKind.values),
    'owner_id': const FieldCodec.text(maxLength: 100, nullable: true),
    'title': const FieldCodec.text(
      maxLength: 200,
      allowBlank: true,
      trim: true,
    ),
    'issuer': const FieldCodec.text(maxLength: 200, nullable: true, trim: true),
    'reference_number': const FieldCodec.text(
      maxLength: 100,
      nullable: true,
      trim: true,
    ),
    'issue_date': const FieldCodec.calendarDate(nullable: true),
    'expiry_date': const FieldCodec.calendarDate(nullable: true),
    'reminder_lead_days': const FieldCodec.integer(
      min: 0,
      max: 3650,
      nullable: true,
    ),
    'phone': const FieldCodec.text(maxLength: 50, nullable: true, trim: true),
    'emergency_phone': const FieldCodec.text(
      maxLength: 50,
      nullable: true,
      trim: true,
    ),
    'is_primary': const FieldCodec.flag(),
    'notes': const FieldCodec.text(allowBlank: true, trim: true),
  };

  @override
  final Map<String, RelationSpec> relations = const {
    'tag_ids': RelationSpec(refEntity: 'tags'),
  };

  @override
  Set<String> get requiredOnCreate => const {'type'};

  @override
  Set<String> get createOnly => const {'type', 'owner_kind', 'owner_id'};

  @override
  String? titleOf(Map<String, Object?> document) =>
      document['title'] as String?;

  @override
  Future<Set<String>> currentRelation(String id, String relation) async => {
    for (final row
        in await _r.db
            .customSelect(
              'SELECT tag_id FROM document_tags WHERE document_id = ?',
              variables: [Variable.withString(id)],
            )
            .get())
      row.read<String>('tag_id'),
  };

  @override
  Future<Map<String, Object?>> createDefaults(
    String diverId,
    Map<String, Object?> values,
  ) async => {'owner_kind': DocumentOwnerKind.personal.name};

  @override
  Future<PlanBlock?> refuse(WriteCheck check) async {
    if (check.kind == ChangeKind.delete) return null;
    final doc = {...?check.document, ...check.values};
    final type = doc['type'];
    if (type != DocumentType.insurance.name) {
      final named = [
        for (final key in [..._insuranceOnly, 'is_primary'])
          if (check.values[key] != null && check.values[key] != false) key,
      ];
      if (named.isNotEmpty) {
        return PlanBlock(
          BlockReason.invalidValue,
          '${named.join(', ')}: an insurance document\'s only.',
        );
      }
    }
    if (type == DocumentType.certificationCard.name &&
        check.values['expiry_date'] != null) {
      return const PlanBlock(
        BlockReason.invalidValue,
        'expiry_date: a card\'s expiry is kept on its certification.',
      );
    }
    for (final key in const ['issue_date', 'expiry_date']) {
      final day = calendarDay(check.values[key]);
      if (day != null && (day.year < 1900 || day.year > 2100)) {
        return PlanBlock(
          BlockReason.invalidValue,
          '$key: a day from 1900 to 2100.',
        );
      }
    }
    if (check.kind == ChangeKind.create) {
      return _ownerProblem(
        DocumentOwnerKind.values.byName(doc['owner_kind']! as String),
        doc['owner_id'] as String?,
        check.ownerId,
      );
    }
    return null;
  }

  @override
  Future<Map<String, int>> createTouched(
    String diverId,
    Map<String, Object?> values,
  ) async => values['is_primary'] == true
      ? await _otherPrimaries(diverId, '')
      : const {};

  @override
  Future<SideEffects> sideEffects(
    String id,
    String? ownerId,
    RecordUpdate update,
    Map<String, Object?> document,
  ) async => update.values['is_primary'] == true && ownerId != null
      ? SideEffects(touched: await _otherPrimaries(ownerId, id))
      : const SideEffects();

  @override
  Future<DeleteReach> deleteReach(
    String id, {
    Map<String, Set<String>> alongside = const {},
  }) async => DeleteReach(
    parts: await countOwned(const {'document_pages': 'document_id'}, id),
  );

  @override
  Future<String> create(String diverId, Map<String, Object?> values) async {
    final now = DateTime.now();
    final kind = DocumentOwnerKind.values.byName(
      values['owner_kind']! as String,
    );
    final saved = await _r.documents.save(
      _applied(
        Document(
          id: '',
          diverId: diverId,
          owner: kind == DocumentOwnerKind.personal
              ? const DocumentOwner.personal()
              : DocumentOwner(kind, values['owner_id']! as String),
          type: DocumentType.values.byName(values['type']! as String),
          createdAt: now,
          updatedAt: now,
        ),
        values,
      ),
      const [],
    );
    return saved.id;
  }

  @override
  Future<void> update(String id, String? ownerId, RecordUpdate update) async {
    final current =
        await _r.documents.getById(id) ??
        (throw AgentToolException(
          AgentToolErrorCode.writeRefused,
          'Document $id no longer exists.',
          details: {'id': id},
        ));
    final tags = update.relations['tag_ids'];
    final now = tags == null ? null : await currentRelation(id, 'tag_ids');
    await _r.documents.save(
      _applied(current, update.values),
      // The pages as stored, without their bytes: kept as they are.
      await _r.documents.getPages(id, withBytes: false),
      tagIds: tags == null
          ? null
          : [...now!.difference(tags.remove), ...tags.add],
    );
  }

  @override
  Future<void> delete(String id, String? ownerId) => _r.documents.delete(id);

  @override
  Future<void> afterApply(List<AppliedChange> changes, ApplyRun run) async {
    final rearm = _rearm;
    if (rearm == null) return;
    final saved = [
      for (final c in changes)
        if (c.kind != ChangeKind.delete) ?await _r.documents.getById(c.id),
    ];
    try {
      if (saved.isNotEmpty) await rearm(saved);
    } catch (e, stackTrace) {
      _log.warning(
        'Document reminders not re-armed',
        error: e,
        stackTrace: stackTrace,
      );
    }
  }

  Future<Map<String, int>> _otherPrimaries(String diverId, String id) async {
    final row = await _r.db
        .customSelect(
          'SELECT COUNT(*) AS n FROM documents WHERE diver_id = ? AND id != ? '
          'AND type = ? AND is_primary = 1',
          variables: [
            Variable.withString(diverId),
            Variable.withString(id),
            Variable.withString(DocumentType.insurance.name),
          ],
        )
        .getSingle();
    final n = row.read<int>('n');
    return {if (n > 0) 'documents': n};
  }

  /// Why [kind] and [ownerId] cannot hold a document of [diverId]'s, or
  /// null: the record has to exist and be one [diverId] can see, as the
  /// record's own page only offers its documents to that profile.
  Future<PlanBlock?> _ownerProblem(
    DocumentOwnerKind kind,
    String? ownerId,
    String? diverId,
  ) async {
    if (kind == DocumentOwnerKind.personal) {
      return ownerId == null
          ? null
          : const PlanBlock(
              BlockReason.invalidValue,
              'owner_id: a personal document names no owner.',
            );
    }
    if (ownerId == null) {
      return const PlanBlock(
        BlockReason.missingField,
        'owner_id: the record the document is attached to.',
      );
    }
    final entity = switch (kind) {
      DocumentOwnerKind.dive => 'dives',
      DocumentOwnerKind.site => 'sites',
      DocumentOwnerKind.trip => 'trips',
      DocumentOwnerKind.equipment => 'equipment',
      DocumentOwnerKind.course => 'courses',
      DocumentOwnerKind.certification => 'certifications',
      DocumentOwnerKind.buddy => 'buddies',
      DocumentOwnerKind.diveCenter => 'centers',
      DocumentOwnerKind.personal => '',
    };
    assert(kDocumentOwnerColumns.containsKey(kind));
    final entry = _records.named(entity);
    if (await countRows(entry.table, 'id = ?1', ownerId) == 0) {
      return PlanBlock(
        BlockReason.unknownReference,
        'owner_id: no ${kind.name} has id $ownerId.',
      );
    }
    if (diverId == null) return null;
    final visible = await RecordReader(
      _r.db,
    ).visibleIds(entry, [ownerId], diverId);
    return visible.isNotEmpty
        ? null
        : PlanBlock(
            BlockReason.otherProfileReference,
            'owner_id: $ownerId belongs to another profile.',
          );
  }

  late final _records = RecordCatalog(_r);

  static Document _applied(Document doc, Map<String, Object?> v) {
    T? kept<T>(String key, T? held) => v.containsKey(key) ? v[key] as T? : held;
    DateTime? day(String key, DateTime? held) =>
        v.containsKey(key) ? calendarDay(v[key]) : held;
    return Document(
      id: doc.id,
      diverId: doc.diverId,
      owner: doc.owner,
      type: doc.type,
      title: kept('title', doc.title)!,
      issuer: kept('issuer', doc.issuer),
      referenceNumber: kept('reference_number', doc.referenceNumber),
      issueDate: day('issue_date', doc.issueDate),
      expiryDate: day('expiry_date', doc.expiryDate),
      reminderLeadDays: kept('reminder_lead_days', doc.reminderLeadDays),
      emergencyPhone: kept('emergency_phone', doc.emergencyPhone),
      phone: kept('phone', doc.phone),
      isPrimary: kept('is_primary', doc.isPrimary)!,
      notes: kept('notes', doc.notes)!,
      createdAt: doc.createdAt,
      updatedAt: doc.updatedAt,
    );
  }
}
