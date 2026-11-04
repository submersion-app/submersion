import 'package:submersion/core/constants/certification_enums.dart';
import 'package:submersion/features/agent_access/data/records/record_repositories.dart';
import 'package:submersion/features/agent_access/data/writes/families/service_ledger_rules.dart';
import 'package:submersion/features/agent_access/data/writes/families/write_reach.dart';
import 'package:submersion/features/agent_access/data/writes/field_codec.dart';
import 'package:submersion/features/agent_access/data/writes/writable_entity.dart';
import 'package:submersion/features/agent_access/domain/agent_tool_error.dart';
import 'package:submersion/features/certification_agencies/domain/certification_catalog.dart';
import 'package:submersion/features/certifications/domain/certification_primary.dart';
import 'package:submersion/features/certifications/domain/entities/certification.dart';
import 'package:submersion/features/documents/domain/entities/document.dart'
    show DocumentOwner, DocumentOwnerKind;

/// Certification cards, through the repository the certification edit page
/// uses. A card is the diver's own or one of their buddies', never both.
/// Picking an instructor copies the buddy's name and instructor card number,
/// as the page's picker does. The card photos are not written here.
class CertificationWrites extends WritableEntry {
  CertificationWrites(this._r);

  final RecordRepositories _r;

  static const _nullableText = FieldCodec.text(
    maxLength: 100,
    nullable: true,
    trim: true,
  );

  @override
  String get name => 'certifications';

  @override
  String get table => 'certifications';

  /// A buddy's card has no diver of its own; it is the buddy's profile's.
  @override
  String ownerOf(String alias) =>
      'COALESCE($alias.diver_id, (SELECT ${alias}b.diver_id FROM buddies '
      '${alias}b WHERE ${alias}b.id = $alias.buddy_id))';

  @override
  String get note =>
      'agency is a built-in agency\'s name, such as padi, or a custom '
      'agency\'s id; level one of that agency\'s levels. A card needs a name '
      'or a level. buddy_id makes it a buddy\'s card. instructor_id, a buddy, '
      'fills instructor_name and instructor_number from them.';

  @override
  late final Map<String, FieldCodec> fields = {
    'buddy_id': const FieldCodec.reference('buddies', nullable: true),
    'name': const FieldCodec.text(maxLength: 200, allowBlank: true, trim: true),
    'agency': const FieldCodec.text(maxLength: 100),
    'level': const FieldCodec.text(maxLength: 100, nullable: true),
    'card_number': _nullableText,
    'issue_date': const FieldCodec.calendarDate(nullable: true),
    'expiry_date': const FieldCodec.calendarDate(nullable: true),
    'instructor_id': const FieldCodec.reference('buddies', nullable: true),
    'instructor_name': _nullableText,
    'instructor_number': _nullableText,
    'notes': const FieldCodec.text(allowBlank: true, trim: true),
  };

  @override
  Set<String> get requiredOnCreate => const {};

  @override
  Set<String> get createOnly => const {'buddy_id'};

  @override
  Future<Map<String, Object?>> createDefaults(
    String diverId,
    Map<String, Object?> values,
  ) async => {
    'agency': CertificationAgency.padi.name,
    'name': '',
    for (final MapEntry(:key, :value) in (await _instructorCopy(
      values['instructor_id'],
    )).entries)
      key: ?value,
  };

  @override
  Future<PlanBlock?> refuse(WriteCheck check) async {
    if (check.kind == ChangeKind.delete) return null;
    final card = {...?check.document, ...check.values};
    if ((card['name'] as String? ?? '').isEmpty && card['level'] == null) {
      return const PlanBlock(
        BlockReason.missingField,
        'A certification needs a name or a level.',
      );
    }
    for (final key in const ['issue_date', 'expiry_date']) {
      final day = calendarDay(check.values[key]);
      if (day != null && (day.year < 1950 || day.year > 2100)) {
        return PlanBlock(
          BlockReason.invalidValue,
          '$key: a day from 1950 to 2100.',
        );
      }
    }
    if (!check.values.containsKey('agency') &&
        !check.values.containsKey('level')) {
      return null;
    }
    return _credentialProblem(
      card['agency']! as String,
      card['level'] as String?,
      check.ownerId,
    );
  }

  @override
  Future<SideEffects> sideEffects(
    String id,
    String? ownerId,
    RecordUpdate update,
    Map<String, Object?> document,
  ) async => SideEffects(
    fields: {
      for (final MapEntry(:key, :value) in (await _instructorCopy(
        update.values['instructor_id'],
      )).entries)
        if (!update.values.containsKey(key) && document[key] != value)
          key: value,
    },
    touched: await _courseRefresh(id),
  );

  @override
  Future<List<DocumentOwner>> deletedDocumentOwners(String id) async => [
    DocumentOwner(DocumentOwnerKind.certification, id),
  ];

  @override
  Future<DeleteReach> deleteReach(
    String id, {
    Map<String, Set<String>> alongside = const {},
  }) async {
    final documents = await countDocuments(await deletedDocumentOwners(id));
    return DeleteReach(
      records: {if (documents > 0) 'documents': documents},
      parts: await countCascaded(
        'certifications',
        id,
        except: const {'documents'},
      ),
      unlinked: await countUnlinked(
        'certifications',
        id,
        except: const {'documents'},
      ),
      touched: await _courseRefresh(id),
    );
  }

  @override
  Future<String> create(String diverId, Map<String, Object?> values) async {
    final now = DateTime.now();
    final buddyId = values['buddy_id'] as String?;
    final blank = Certification(
      id: '',
      diverId: buddyId == null ? diverId : null,
      buddyId: buddyId,
      name: '',
      agency: CertificationAgency.padi.name,
      cardImagesLoaded: false,
      createdAt: now,
      updatedAt: now,
    );
    return (await _r.certifications.createCertification(
      _applied(blank, values),
    )).id;
  }

  @override
  Future<void> update(String id, String? ownerId, RecordUpdate update) async {
    final current =
        await _r.certifications.getCertificationById(id) ??
        (throw AgentToolException(
          AgentToolErrorCode.writeRefused,
          'Certification $id no longer exists.',
          details: {'id': id},
        ));
    await _r.certifications.updateCertification(
      _applied(current, {
        ...await _instructorCopy(update.values['instructor_id']),
        ...update.values,
      }),
    );
  }

  @override
  Future<void> delete(String id, String? ownerId) =>
      _r.certifications.deleteCertification(id);

  /// What picking buddy [instructorId] as the instructor writes: their name
  /// and the card number of their highest instructor card, or none.
  Future<Map<String, Object?>> _instructorCopy(Object? instructorId) async {
    if (instructorId is! String) return const {};
    final buddy = await _r.buddies.getBuddyById(instructorId);
    if (buddy == null) return const {};
    final teaching = [
      for (final c in await _r.certifications.getCertificationMetadataByBuddy(
        instructorId,
      ))
        if (CertificationLevel.fromId(c.level)?.isInstructorLevel ?? false) c,
    ];
    return {
      'instructor_name': buddy.name,
      'instructor_number': primaryCertification(teaching)?.cardNumber,
    };
  }

  /// The course whose representative card a change to [id] can move.
  Future<Map<String, int>> _courseRefresh(String id) async {
    final card = await _r.certifications.getCertificationById(id);
    return card?.courseId == null ? const {} : const {'courses': 1};
  }

  /// Why [agency] and [level] cannot go on a card of [ownerId], or null:
  /// the agency is built in or a custom one the profile sees, and the level
  /// one the agency offers.
  Future<PlanBlock?> _credentialProblem(
    String agency,
    String? level,
    String? ownerId,
  ) async {
    final custom = _r.customCertifications;
    final catalog = CertificationCatalog(
      agencies: await custom.getAllAgencies(),
      levels: await custom.getAllLevels(),
      viewerDiverId: ownerId,
    );
    if (!catalog.agencies.any((a) => a.id == agency)) {
      return PlanBlock(
        BlockReason.invalidValue,
        'agency: $agency is not an agency this profile can use.',
      );
    }
    if (level != null && !catalog.levelsFor(agency).any((l) => l.id == level)) {
      return PlanBlock(
        BlockReason.invalidValue,
        'level: $level is not one of ${catalog.agency(agency).name}\'s levels.',
      );
    }
    return null;
  }

  /// [card] with [values] written over it, as the page builds a save: every
  /// field from the form, the photos left as they are.
  static Certification _applied(
    Certification card,
    Map<String, Object?> values,
  ) {
    T? kept<T>(String key, T? held) =>
        values.containsKey(key) ? values[key] as T? : held;
    DateTime? day(String key, DateTime? held) =>
        values.containsKey(key) ? calendarDay(values[key]) : held;
    return Certification(
      id: card.id,
      diverId: card.diverId,
      buddyId: card.buddyId,
      name: kept('name', card.name)!,
      agency: kept('agency', card.agency)!,
      level: kept('level', card.level),
      additionalCredentials: card.additionalCredentials,
      cardNumber: kept('card_number', card.cardNumber),
      issueDate: day('issue_date', card.issueDate),
      expiryDate: day('expiry_date', card.expiryDate),
      instructorName: kept('instructor_name', card.instructorName),
      instructorNumber: kept('instructor_number', card.instructorNumber),
      instructorId: kept('instructor_id', card.instructorId),
      courseId: card.courseId,
      cardId: card.cardId,
      cardImagesLoaded: false,
      notes: kept('notes', card.notes)!,
      createdAt: card.createdAt,
      updatedAt: card.updatedAt,
    );
  }
}
