import 'package:submersion/core/services/sync/sync_data_serializer.dart';

/// A foreign-key column of a conflicting record, resolved to whatever
/// real-world anchor the row it points at carries.
///
/// Junction and relation entities (`diveTags`, `qualityFindings`, ...) store
/// nothing but ids, so the Resolve Conflicts dialog has no way to describe them
/// from the raw record alone (#1031). Resolving the reference gives the dialog
/// a tag's name or a dive's date to show instead of a UUID.
class ConflictReference {
  const ConflictReference({
    required this.field,
    required this.targetType,
    required this.recordId,
    this.exists = true,
    this.name,
    this.timestamp,
  });

  /// The column on the conflicting record, e.g. `diveId`.
  final String field;

  /// The sync entity type the column points at, e.g. `dives`.
  final String targetType;

  /// The referenced row's id.
  final String recordId;

  /// The referenced row's human name, when it has one. A dive borrows its
  /// site's name, matching how the rest of the app names an unnamed dive.
  final String? name;

  /// The referenced row's date anchor, for entities dated rather than named.
  final DateTime? timestamp;

  /// Whether the referenced row is in the local database. Tracked explicitly
  /// rather than inferred from [name] and [timestamp] being null: several
  /// tables (dive tanks, sightings, connected accounts) can carry neither, and
  /// telling a user a record was deleted right before they choose which
  /// version to keep is worse than showing them an id.
  final bool exists;

  /// True when the referenced row is not in the local database: it was deleted
  /// here, or the conflicting record arrived from a peer that still has it.
  /// The dialog says so rather than showing a blank line.
  bool get isMissing => !exists;
}

/// Resolves the foreign keys of a conflicting record into [ConflictReference]s.
///
/// Lookups go through [SyncDataSerializer.fetchRecord], the same method that
/// loads the conflicting row itself, so every entity the serializer can sync is
/// resolvable without a second query layer.
class ConflictReferenceResolver {
  ConflictReferenceResolver(this._serializer);

  final SyncDataSerializer _serializer;

  /// Rows already fetched by this resolver. One resolver serves a whole
  /// batch of conflicts, and a restore raises many conflicts pointing at the
  /// same diver, dive or site, so each referenced row is read once.
  final Map<String, Map<String, dynamic>?> _rows = {};

  /// Foreign-key column -> sync entity type.
  ///
  /// Most entries are transcribed from the `.references(Table, #id)` clauses
  /// in `database.dart`. The rest are columns that hold another row's id
  /// without a declared Drift constraint (`Media.subscriptionId` and
  /// `connectorAccountId`, `DiveDiveTypes.diveTypeId`,
  /// `DivePlanSegments.switchToTankId`, `DiveProfileEvents.tankId`); they are
  /// listed here because the dialog can resolve them just as well, so verify
  /// those against their table rather than expecting a `references` clause.
  /// Columns whose name is ambiguous across tables are disambiguated by
  /// [_targetOverrides].
  static const _defaultTargets = <String, String>{
    'diveId': 'dives',
    'relatedDiveId': 'dives',
    'linkedDiveId': 'dives',
    'sourceDiveId': 'dives',
    'siteId': 'diveSites',
    'tagId': 'tags',
    'diveTypeId': 'diveTypes',
    'diverId': 'divers',
    'buddyId': 'buddies',
    'instructorId': 'buddies',
    'signerId': 'buddies',
    'equipmentId': 'equipment',
    'setId': 'equipmentSets',
    'equipmentSetId': 'equipmentSets',
    'configId': 'cylinderConfigs',
    'computerId': 'diveComputers',
    'sourceId': 'diveDataSources',
    'tankId': 'diveTanks',
    'switchToTankId': 'divePlanTanks',
    'planId': 'divePlans',
    'tripId': 'trips',
    'diveCenterId': 'diveCenters',
    'courseId': 'courses',
    'certificationId': 'certifications',
    'requirementId': 'courseRequirements',
    'serviceKindId': 'serviceKinds',
    'speciesId': 'species',
    'sightingId': 'sightings',
    'mediaId': 'media',
    'subscriptionId': 'mediaSubscriptions',
    'connectorAccountId': 'connectedAccounts',
    'sessionId': 'preDiveSessions',
    'templateId': 'checklistTemplates',
  };

  /// Owning entity type -> column -> target, for the two column names the
  /// schema reuses across unrelated tables.
  static const _targetOverrides = <String, Map<String, String>>{
    'divePlanSegments': {'tankId': 'divePlanTanks'},
    'preDiveSessions': {'templateId': 'preDiveChecklistTemplates'},
    'preDiveChecklistTemplateItems': {
      'templateId': 'preDiveChecklistTemplates',
    },
  };

  /// Name-carrying columns, in the order the app prefers them. Several tables
  /// name themselves through a column of their own (a tank's `tankName`, a
  /// connected account's `label`), so the generic names are tried first and
  /// the table-specific ones after.
  static const _nameFields = <String>[
    'name',
    'title',
    'commonName',
    'displayName',
    'label',
    'tankName',
    'presetName',
    'templateName',
    'sourceFileName',
    'caption',
    'originalFilename',
  ];

  /// Date-carrying columns (Unix millis) for entities that are dated, not
  /// named.
  static const _timestampFields = <String>[
    'diveDateTime',
    'startDateTime',
    'startDate',
  ];

  /// Every entity type a foreign key can point at. Exposed so the dialog's
  /// label table can prove it covers the whole set rather than silently
  /// falling back to a humanized entity name for a target added later.
  static Set<String> get targetTypes => {
    ..._defaultTargets.values,
    for (final columns in _targetOverrides.values) ...columns.values,
  };

  /// The entity type [field] on an [entityType] record points at, or null when
  /// the column is not a foreign key.
  static String? targetTypeFor(String entityType, String field) =>
      _targetOverrides[entityType]?[field] ?? _defaultTargets[field];

  /// Resolves every foreign key in [data]. Null and non-string values are
  /// skipped, so a nullable reference that is unset produces no entry.
  Future<List<ConflictReference>> resolve(
    String entityType,
    Map<String, dynamic> data,
  ) async {
    final references = <ConflictReference>[];
    for (final entry in data.entries) {
      final target = targetTypeFor(entityType, entry.key);
      if (target == null) continue;
      final id = entry.value;
      if (id is! String || id.isEmpty) continue;
      references.add(await _resolveOne(entry.key, target, id));
    }
    return List.unmodifiable(references);
  }

  Future<ConflictReference> _resolveOne(
    String field,
    String targetType,
    String recordId,
  ) async {
    final row = await _fetch(targetType, recordId);
    if (row == null) {
      return ConflictReference(
        field: field,
        targetType: targetType,
        recordId: recordId,
        exists: false,
      );
    }
    return ConflictReference(
      field: field,
      targetType: targetType,
      recordId: recordId,
      name: _nameOf(row) ?? await _borrowedName(row),
      timestamp: _timestampOf(row),
    );
  }

  /// An unnamed dive is displayed by its site everywhere else in the app, and
  /// a sighting is only ever known by its species. Borrow those names here
  /// too. Exactly one hop: the borrowed row's name is read directly and never
  /// resolved further.
  Future<String?> _borrowedName(Map<String, dynamic> row) async {
    for (final borrow in const [
      (field: 'siteId', target: 'diveSites'),
      (field: 'speciesId', target: 'species'),
    ]) {
      final id = row[borrow.field];
      if (id is! String || id.isEmpty) continue;
      final parent = await _fetch(borrow.target, id);
      final name = parent == null ? null : _nameOf(parent);
      if (name != null) return name;
    }
    return null;
  }

  Future<Map<String, dynamic>?> _fetch(String targetType, String id) async {
    final key = '$targetType|$id';
    if (_rows.containsKey(key)) return _rows[key];
    return _rows[key] = await _serializer.fetchRecord(targetType, id);
  }

  static String? _nameOf(Map<String, dynamic> row) {
    for (final field in _nameFields) {
      final value = row[field];
      if (value is String && value.isNotEmpty) return value;
    }
    return null;
  }

  static DateTime? _timestampOf(Map<String, dynamic> row) {
    for (final field in _timestampFields) {
      final value = row[field];
      if (value is int) return DateTime.fromMillisecondsSinceEpoch(value);
    }
    return null;
  }
}
