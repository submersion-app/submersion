part of 'document_repository.dart';

/// [DocumentRepository]'s medical clearance reads (issue #4541): which
/// documents can remind once superseded clearances are left out, and each
/// diver's current clearance.
mixin _DocumentClearanceQueries {
  AppDatabase get _db;

  /// [diverId]'s documents that can remind: an expiry date, not a card,
  /// and not a medical clearance a later one supersedes (#4541). Undated
  /// clearances are read too, since one issued later supersedes by its
  /// issue date, though it never reminds itself.
  Future<List<Document>> getRemindingForDiver(String diverId) async {
    final rows =
        await (_db.select(_db.documents)..where(
              (t) =>
                  t.diverId.equals(diverId) &
                  ((t.expiryDate.isNotNull() &
                          t.type
                              .equals(DocumentType.certificationCard.storage)
                              .not()) |
                      t.type.equals(_clearance)),
            ))
            .get();
    return [
      for (final d in withoutSupersededClearances(
        rows.map(documentFromRow).toList(),
      ))
        if (d.remindsOnExpiry) d,
    ];
  }

  /// Every medical clearance of [diverId], dated or not: the set a renewal
  /// re-arms together, since one clearance's save can supersede another.
  Future<List<Document>> getMedicalClearancesForDiver(String diverId) async {
    final rows =
        await (_db.select(_db.documents)..where(
              (t) => t.diverId.equals(diverId) & t.type.equals(_clearance),
            ))
            .get();
    return rows.map(documentFromRow).toList();
  }

  /// The medical clearances among [ids], by diver: the divers a delete of
  /// [ids] has to re-arm (#4609).
  Future<Map<String, Set<String>>> _clearancesByDiverOf(
    List<String> ids,
  ) async {
    final id = _db.documents.id;
    final diverId = _db.documents.diverId;
    final out = <String, Set<String>>{};
    for (final chunk in ids.slices(DocumentRepository._inListChunk)) {
      final q = _db.selectOnly(_db.documents)
        ..addColumns([id, diverId])
        ..where(id.isIn(chunk) & _db.documents.type.equals(_clearance));
      for (final row in await q.get()) {
        final String diver = row.read(diverId)!;
        final String document = row.read(id)!;
        (out[diver] ??= {}).add(document);
      }
    }
    return out;
  }

  /// The expiry of each diver's current medical clearance, the one that
  /// alone reminds (currentClearances): their own, not one filed under a
  /// buddy. A diver whose current clearance has no expiry has none here.
  Future<Map<String, DateTime>> latestClearanceExpiryByDiver({
    String? diverId,
  }) async {
    final q = _db.select(_db.documents)
      ..where((t) => t.type.equals(_clearance) & t.buddyId.isNull());
    if (diverId != null) q.where((t) => t.diverId.equals(diverId));
    final current = currentClearances((await q.get()).map(documentFromRow));
    return {
      for (final MapEntry(key: holder, value: d) in current.entries)
        holder.diverId: ?d.expiryDate,
    };
  }
}

String get _clearance => DocumentType.medicalClearance.storage;

/// List order: by type, medical clearances newest first (#4508): by
/// expiry, else issue date, undated last, ties broken as currentClearances
/// breaks them, so the first one listed is the one that reminds. Then by
/// title and age. [prefix] is the table alias with its dot.
String _documentOrder([String prefix = '']) {
  String newestClearance(String key) =>
      "CASE WHEN ${prefix}type = '$_clearance' THEN $key END DESC";
  return [
    '${prefix}type',
    newestClearance('COALESCE(${prefix}expiry_date, ${prefix}issue_date)'),
    newestClearance('${prefix}issue_date'),
    newestClearance('${prefix}created_at'),
    newestClearance('${prefix}id'),
    '${prefix}title',
    '${prefix}created_at',
  ].join(', ');
}

/// [_documentOrder] for the typed personal-documents query.
List<OrderClauseGenerator<$DocumentsTable>> get _documentOrderTerms => [
  (t) => OrderingTerm(expression: t.type),
  (t) => _newestClearance(t, coalesce([t.expiryDate, t.issueDate])),
  (t) => _newestClearance(t, t.issueDate),
  (t) => _newestClearance(t, t.createdAt),
  (t) => _newestClearance(t, t.id),
  (t) => OrderingTerm(expression: t.title),
  (t) => OrderingTerm(expression: t.createdAt),
];

OrderingTerm _newestClearance<T extends Object>(
  $DocumentsTable t,
  Expression<T> key,
) => OrderingTerm.desc(
  CaseWhenExpression<T>(
    cases: [CaseWhen(t.type.equals(_clearance), then: key)],
  ),
);
