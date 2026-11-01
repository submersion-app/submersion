import 'package:submersion/core/constants/enums.dart';
import 'package:submersion/features/dive_log/presentation/widgets/environment_enum_display.dart';
import 'package:submersion/features/dive_sites/data/repositories/site_repository_impl.dart';
import 'package:submersion/features/dive_sites/domain/constants/site_field.dart';
import 'package:submersion/features/dive_sites/domain/entities/dive_site.dart';
import 'package:submersion/features/dive_sites/presentation/site_difficulty_display.dart';
import 'package:submersion/features/table_editor/domain/column_factories.dart';
import 'package:submersion/features/table_editor/domain/table_draft.dart';
import 'package:submersion/features/table_editor/domain/table_editor_column.dart';
import 'package:submersion/features/table_editor/domain/table_editor_entity.dart';
import 'package:submersion/l10n/arb/app_localizations.dart';
import 'package:submersion/shared/constants/entity_field.dart';

typedef SiteEditorColumn = TableEditorColumn<SiteWithCount, SiteField>;

/// The sites tab (#3422). A site the profile may not edit in its library
/// saves only notes and rating, so every other cell of it is read-only here
/// rather than reported as saved and silently kept. Latitude and longitude
/// are two columns over one `GeoPoint`, reconciled as a pair.
class SiteTableEditorEntity
    extends TableEditorEntity<SiteWithCount, SiteField> {
  final SiteRepository _repo;
  final String? actingDiverId;

  /// Whether the profile may edit each library site on the sheet, resolved
  /// once so a cell's editability stays synchronous.
  final Map<String, bool> editableLibrarySites;

  @override
  final List<SiteEditorColumn> columns;

  SiteTableEditorEntity({
    required SiteRepository repo,
    required this.editableLibrarySites,
    this.actingDiverId,
  }) : _repo = repo,
       columns = _columns(editableLibrarySites);

  @override
  EntityFieldAdapter<SiteWithCount, SiteField> get adapter =>
      SiteFieldAdapter.instance;

  @override
  SiteField fieldFromName(String name) => adapter.fieldFromName(name);

  @override
  String idOf(SiteWithCount entity) => entity.site.id;

  @override
  SiteField get keyField => SiteField.siteName;

  @override
  List<Set<String>> get linkedFields => [
    {SiteField.latitude.name, SiteField.longitude.name},
  ];

  @override
  int? numberOf(SiteWithCount entity) => null;

  @override
  String? nameOf(SiteWithCount entity) => entity.site.name;

  static bool _isCoordinate(TableDraft d) =>
      d.fieldName == SiteField.latitude.name ||
      d.fieldName == SiteField.longitude.name;

  @override
  List<TableDraft> reconcile(SiteWithCount entity, List<TableDraft> drafts) {
    TableDraft? find(SiteField f) {
      for (final d in drafts) {
        if (d.fieldName == f.name) return d;
      }
      return null;
    }

    final lat = find(SiteField.latitude);
    final lon = find(SiteField.longitude);
    if (lat == null && lon == null) return drafts;
    final location = entity.site.location;
    if (location == null) {
      // Both halves must arrive before a position exists.
      final complete = lat?.value != null && lon?.value != null;
      return [
        for (final d in drafts)
          if (!_isCoordinate(d))
            d
          else if (complete && d.flag == TableDraftFlag.pairIncomplete)
            d.copyWith(clearFlag: true)
          else if (!complete && d.flag == null)
            d.copyWith(flag: TableDraftFlag.pairIncomplete)
          else
            d,
      ];
    }
    // A typed half beside a cleared half means the diver is typing the
    // position back: the cleared half returns to its stored value.
    final typed =
        (lat != null && lat.value != null) ||
        (lon != null && lon.value != null);
    if (typed) {
      return [
        for (final d in drafts)
          if (_isCoordinate(d) && d.value == null)
            d.copyWith(
              value: d.fieldName == SiteField.latitude.name
                  ? location.latitude
                  : location.longitude,
            )
          else
            d,
      ];
    }
    // Clearing either half clears the position, so the other half follows.
    final clearing =
        (lat != null && lat.value == null) ||
        (lon != null && lon.value == null);
    if (!clearing) return drafts;
    final out = [...drafts];
    if (lat == null) {
      out.add(_clearDraft(entity, SiteField.latitude, location.latitude));
    }
    if (lon == null) {
      out.add(_clearDraft(entity, SiteField.longitude, location.longitude));
    }
    return out;
  }

  TableDraft _clearDraft(SiteWithCount e, SiteField f, double current) =>
      TableDraft(
        entityId: e.site.id,
        fieldName: f.name,
        original: current,
        value: null,
      );

  @override
  Future<List<SiteWithCount>> reload(List<String> ids) async => [
    for (final id in ids)
      if (await _repo.getSiteById(id) case final site?)
        SiteWithDiveCount(site: site, diveCount: 0),
  ];

  @override
  Future<void> save(
    Map<String, List<TableDraft>> draftsByEntity,
    Map<String, SiteWithCount> fresh,
  ) async {
    for (final entry in draftsByEntity.entries) {
      final current = fresh[entry.key]?.site;
      if (current == null) continue;
      final values = <SiteField, Object?>{
        for (final d in entry.value) fieldFromName(d.fieldName): d.value,
      };
      await _repo.updateSite(
        _withValues(current, values),
        actingDiverId: actingDiverId,
      );
    }
  }

  @override
  List<String> summaryNotes(List<TableDraft> drafts, AppLocalizations l10n) => [
    if (drafts.any((d) => _isCoordinate(d) && d.value == null))
      l10n.tableEditor_summary_pairClear,
  ];

  /// A copy of [s] with [v]'s values, built through the constructor because
  /// `copyWith` cannot clear a nullable field.
  static DiveSite _withValues(DiveSite s, Map<SiteField, Object?> v) {
    T pick<T>(SiteField f, T current) => v.containsKey(f) ? v[f] as T : current;
    List<EntryMethod> methods(SiteField f, List<EntryMethod> current) {
      if (!v.containsKey(f)) return current;
      final names = (v[f] as List?)?.cast<String>() ?? const [];
      return [
        for (final n in names)
          EntryMethod.values.firstWhere((m) => m.name == n),
      ];
    }

    final lat = pick<double?>(SiteField.latitude, s.location?.latitude);
    final lon = pick<double?>(SiteField.longitude, s.location?.longitude);
    final waterType = pick<String?>(SiteField.waterType, s.waterType?.name);
    final difficulty = pick<String?>(SiteField.difficulty, s.difficulty?.name);
    return DiveSite(
      id: s.id,
      diverId: s.diverId,
      name: pick<String>(SiteField.siteName, s.name),
      description: s.description,
      location: lat != null && lon != null ? GeoPoint(lat, lon) : null,
      minDepth: pick<double?>(SiteField.minDepth, s.minDepth),
      maxDepth: pick<double?>(SiteField.maxDepth, s.maxDepth),
      difficulty: difficulty == null
          ? null
          : SiteDifficulty.values.firstWhere((d) => d.name == difficulty),
      waterType: waterType == null
          ? null
          : WaterType.values.firstWhere((w) => w.name == waterType),
      country: pick<String?>(SiteField.country, s.country),
      region: pick<String?>(SiteField.region, s.region),
      city: pick<String?>(SiteField.city, s.city),
      island: pick<String?>(SiteField.island, s.island),
      bodyOfWater: pick<String?>(SiteField.bodyOfWater, s.bodyOfWater),
      photoIds: s.photoIds,
      rating: pick<double?>(SiteField.rating, s.rating),
      notes: pick<String?>(SiteField.notes, s.notes) ?? '',
      hazards: pick<String?>(SiteField.hazards, s.hazards),
      accessNotes: s.accessNotes,
      mooringNumber: pick<String?>(SiteField.mooringNumber, s.mooringNumber),
      parkingInfo: s.parkingInfo,
      altitude: pick<double?>(SiteField.altitude, s.altitude),
      entryMethods: methods(SiteField.entryType, s.entryMethods),
      exitMethods: methods(SiteField.exitMethod, s.exitMethods),
      isShared: s.isShared,
      sharedLibraryId: s.sharedLibraryId,
    );
  }
}

List<SiteEditorColumn> _columns(Map<String, bool> editableLibrarySites) {
  bool mayEdit(SiteWithCount e) =>
      !e.site.isLibrarySite || (editableLibrarySites[e.site.id] ?? false);
  String? reason(SiteWithCount e, AppLocalizations l) =>
      mayEdit(e) ? null : l.tableEditor_libraryReadOnly;

  SiteEditorColumn text(SiteField f, String? Function(DiveSite) get) =>
      textColumn(
        f,
        (e) => get(e.site),
        isEditable: mayEdit,
        readOnlyReason: reason,
      );
  SiteEditorColumn depth(SiteField f, double? Function(DiveSite) get) =>
      numberColumn(
        f,
        (e) => get(e.site),
        toDisplay: (u, v) => u.convertDepth(v),
        toStored: (u, v) => u.depthToMeters(v),
        symbol: (u) => u.depthSymbol,
        min: 0,
        isEditable: mayEdit,
        readOnlyReason: reason,
      );

  return [
    textColumn(
      SiteField.siteName,
      (e) => e.site.name,
      required: true,
      isEditable: mayEdit,
      readOnlyReason: reason,
    ),
    text(SiteField.country, (s) => s.country),
    text(SiteField.region, (s) => s.region),
    text(SiteField.city, (s) => s.city),
    text(SiteField.island, (s) => s.island),
    text(SiteField.bodyOfWater, (s) => s.bodyOfWater),
    degreesColumn(
      SiteField.latitude,
      (e) => e.site.location?.latitude,
      limit: 90,
      isEditable: mayEdit,
      readOnlyReason: reason,
    ),
    degreesColumn(
      SiteField.longitude,
      (e) => e.site.location?.longitude,
      limit: 180,
      isEditable: mayEdit,
      readOnlyReason: reason,
    ),
    depth(SiteField.maxDepth, (s) => s.maxDepth),
    depth(SiteField.minDepth, (s) => s.minDepth),
    numberColumn(
      SiteField.altitude,
      (e) => e.site.altitude,
      toDisplay: (u, v) => u.convertAltitude(v),
      toStored: (u, v) => u.altitudeToMeters(v),
      symbol: (u) => u.altitudeSymbol,
      isEditable: mayEdit,
      readOnlyReason: reason,
    ),
    choiceColumn(
      SiteField.waterType,
      (e) => e.site.waterType,
      WaterType.values,
      (v, l) => v.localizedName(l),
      isEditable: mayEdit,
      readOnlyReason: reason,
    ),
    choiceColumn(
      SiteField.difficulty,
      (e) => e.site.difficulty,
      SiteDifficulty.values,
      (v, l) => v.localizedName(l),
      isEditable: mayEdit,
      readOnlyReason: reason,
    ),
    multiChoiceColumn(
      SiteField.entryType,
      (e) => e.site.entryMethods,
      EntryMethod.values,
      (v, l) => v.localizedName(l),
      isEditable: mayEdit,
      readOnlyReason: reason,
    ),
    multiChoiceColumn(
      SiteField.exitMethod,
      (e) => e.site.exitMethods,
      EntryMethod.values,
      (v, l) => v.localizedName(l),
      isEditable: mayEdit,
      readOnlyReason: reason,
    ),
    text(SiteField.mooringNumber, (s) => s.mooringNumber),
    text(SiteField.hazards, (s) => s.hazards),
    // Private to the profile, so a library site keeps them editable.
    plainNumberColumn(SiteField.rating, (e) => e.site.rating, min: 0, max: 5),
    textColumn(
      SiteField.notes,
      (e) => e.site.notes.isEmpty ? null : e.site.notes,
    ),
  ];
}
