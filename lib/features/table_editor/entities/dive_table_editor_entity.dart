import 'package:submersion/core/constants/dive_field.dart';
import 'package:submersion/core/constants/enums.dart';
import 'package:submersion/core/constants/gas_model.dart';
import 'package:submersion/features/dive_log/data/repositories/dive_repository_impl.dart';
import 'package:submersion/features/dive_log/data/services/bulk_dive_edit_service.dart';
import 'package:submersion/features/dive_log/domain/bulk_edit/bulk_edit_field_set.dart';
import 'package:submersion/features/dive_log/domain/entities/bulk_edit_request.dart';
import 'package:submersion/features/dive_log/domain/entities/dive.dart';
import 'package:submersion/features/dive_log/presentation/table/dive_field_adapter.dart';
import 'package:submersion/features/table_editor/domain/table_draft.dart';
import 'package:submersion/features/table_editor/domain/table_editor_column.dart';
import 'package:submersion/features/table_editor/domain/table_editor_entity.dart';
import 'package:submersion/features/table_editor/entities/dive_table_editor_columns.dart';
import 'package:submersion/l10n/arb/app_localizations.dart';

/// The dive tab (#3422). Each dive's drafts become one [BulkEditRequest]
/// applied through [BulkDiveEditService], so sync marks, undo snapshots and
/// the site's snapped values all behave as bulk edit does.
class DiveTableEditorEntity extends TableEditorEntity<Dive, DiveField> {
  final DiveRepository _diveRepo;
  final BulkDiveEditService _bulk;

  /// The type a weight row created from an empty cell takes.
  final WeightType defaultWeightType;

  @override
  final DiveFieldAdapter adapter;

  @override
  final List<TableEditorColumn<Dive, DiveField>> columns;

  DiveTableEditorEntity({
    required DiveRepository diveRepo,
    required BulkDiveEditService bulk,
    required List<ChoiceOption> sites,
    required List<ChoiceOption> centers,
    required List<ChoiceOption> trips,
    List<ChoiceOption> computers = const [],
    this.defaultWeightType = WeightType.belt,
    GasModel gasModel = GasModel.real,
    String Function(String id)? diveTypeLabel,
  }) : _diveRepo = diveRepo,
       _bulk = bulk,
       adapter = DiveFieldAdapter(
         gasModel: gasModel,
         diveTypeLabel: diveTypeLabel,
       ),
       columns = diveEditorColumns(
         sites: sites,
         centers: centers,
         trips: trips,
         computers: computers,
       );

  @override
  DiveField fieldFromName(String name) => adapter.fieldFromName(name);

  @override
  String idOf(Dive entity) => entity.id;

  @override
  DiveField get keyField => DiveField.diveNumber;

  @override
  int? numberOf(Dive entity) => entity.diveNumber;

  @override
  String? nameOf(Dive entity) => null;

  /// A dive shows a scrubber only when it has a type, so a duration without
  /// one would save, report saved, and read back as nothing.
  @override
  List<TableDraft> reconcile(Dive entity, List<TableDraft> drafts) {
    TableDraft? find(DiveField f) {
      for (final d in drafts) {
        if (d.fieldName == f.name) return d;
      }
      return null;
    }

    final duration = find(DiveField.scrubberDuration);
    if (duration == null) return drafts;
    final type = find(DiveField.scrubberType);
    final hasType = type != null ? type.value != null : entity.scrubber != null;
    final waiting = duration.value != null && !hasType;
    return [
      for (final d in drafts)
        if (d != duration)
          d
        else if (waiting && d.flag == null)
          d.copyWith(flag: TableDraftFlag.needsScrubberType)
        else if (!waiting && d.flag == TableDraftFlag.needsScrubberType)
          d.copyWith(clearFlag: true)
        else
          d,
    ];
  }

  @override
  Future<List<Dive>> reload(List<String> ids) =>
      _diveRepo.getDivesByIdsWithoutSamples(ids);

  @override
  Future<void> save(
    Map<String, List<TableDraft>> draftsByEntity,
    Map<String, Dive> fresh,
  ) async {
    for (final entry in draftsByEntity.entries) {
      final values = <DiveField, Object?>{
        for (final d in entry.value) fieldFromName(d.fieldName): d.value,
      };
      final req = _requestFor(entry.key, values);
      if (req != null) await _bulk.apply(req);
    }
  }

  @override
  List<String> summaryNotes(List<TableDraft> drafts, AppLocalizations l10n) => [
    if (drafts.any((d) => d.fieldName == DiveField.siteName.name))
      l10n.tableEditor_summary_siteSnap,
  ];

  BulkEditRequest? _requestFor(String diveId, Map<DiveField, Object?> v) {
    final enabled = <BulkField>{for (final f in v.keys) ?_bulkFieldOf[f]};
    final ops = <BulkCollectionOp>[
      if (v.containsKey(DiveField.siteName))
        SiteOp(siteId: v[DiveField.siteName] as String?),
      if (v.containsKey(DiveField.totalWeight))
        WeightAmountOp(
          amountKg: v[DiveField.totalWeight] as double?,
          newRowType: defaultWeightType,
        ),
    ];
    if (enabled.isEmpty && ops.isEmpty) return null;
    final gas = v[DiveField.diluentGas] as GasMix?;
    final minutes = v[DiveField.surfaceInterval] as int?;
    final inputs = BulkScalarInputs(
      diveCenterId: v[DiveField.diveCenterName] as String?,
      diveOperator: v[DiveField.diveOperator] as String?,
      boatName: v[DiveField.boatName] as String?,
      boatCaptain: v[DiveField.boatCaptain] as String?,
      tripId: v[DiveField.tripName] as String?,
      rating: v[DiveField.ratingStars] as int?,
      isFavorite: v[DiveField.isFavorite] as bool?,
      excludedFromStats: v[DiveField.excludedFromStats] as bool?,
      excludedFromGasStats: v[DiveField.excludedFromGasStats] as bool?,
      waterType: v[DiveField.waterType] as String?,
      visibilityMeters: v[DiveField.visibility] as double?,
      currentDirection: v[DiveField.currentDirection] as String?,
      currentStrength: v[DiveField.currentStrength] as String?,
      swellHeight: v[DiveField.swellHeight] as double?,
      surfaceConditions: v[DiveField.surfaceConditions] as String?,
      entryMethod: v[DiveField.entryMethod] as String?,
      exitMethod: v[DiveField.exitMethod] as String?,
      altitude: v[DiveField.altitude] as double?,
      surfacePressure: v[DiveField.surfacePressure] as double?,
      surfaceIntervalSeconds: minutes == null ? null : minutes * 60,
      gradientFactorLow: v[DiveField.gradientFactorLow] as int?,
      gradientFactorHigh: v[DiveField.gradientFactorHigh] as int?,
      decoAlgorithm: v[DiveField.decoAlgorithm] as String?,
      decoConservatism: v[DiveField.decoConservatism] as int?,
      diveComputerModel: v[DiveField.diveComputerModel] as String?,
      windSpeed: v[DiveField.windSpeed] as double?,
      windDirection: v[DiveField.windDirection] as String?,
      cloudCover: v[DiveField.cloudCover] as String?,
      precipitation: v[DiveField.precipitation] as String?,
      humidity: v[DiveField.humidity] as double?,
      weatherDescription: v[DiveField.weatherDescription] as String?,
      diveMode: v[DiveField.diveMode] as String?,
      setpointLow: v[DiveField.setpointLow] as double?,
      setpointHigh: v[DiveField.setpointHigh] as double?,
      setpointDeco: v[DiveField.setpointDeco] as double?,
      diluentO2: gas?.o2,
      diluentHe: gas?.he,
      scrubberType: v[DiveField.scrubberType] as String?,
      scrubberDuration: v[DiveField.scrubberDuration] as int?,
      notes: v[DiveField.notes] as String?,
    );
    return BulkEditRequest(
      diveIds: [diveId],
      scalars: buildScalarCompanion(enabled, inputs),
      ops: ops,
    );
  }
}

/// Which bulk field each editable column writes. Site and weight ride ops,
/// so they map to nothing here.
const Map<DiveField, BulkField> _bulkFieldOf = {
  DiveField.diveCenterName: BulkField.diveCenter,
  DiveField.diveOperator: BulkField.diveOperator,
  DiveField.boatName: BulkField.boatName,
  DiveField.boatCaptain: BulkField.boatCaptain,
  DiveField.tripName: BulkField.trip,
  DiveField.ratingStars: BulkField.rating,
  DiveField.isFavorite: BulkField.isFavorite,
  DiveField.excludedFromStats: BulkField.excludedFromStats,
  DiveField.excludedFromGasStats: BulkField.excludedFromGasStats,
  DiveField.waterType: BulkField.waterType,
  DiveField.visibility: BulkField.visibility,
  DiveField.currentDirection: BulkField.currentDirection,
  DiveField.currentStrength: BulkField.currentStrength,
  DiveField.swellHeight: BulkField.swellHeight,
  DiveField.surfaceConditions: BulkField.surfaceConditions,
  DiveField.entryMethod: BulkField.entryMethod,
  DiveField.exitMethod: BulkField.exitMethod,
  DiveField.altitude: BulkField.altitude,
  DiveField.surfacePressure: BulkField.surfacePressure,
  DiveField.surfaceInterval: BulkField.surfaceInterval,
  DiveField.gradientFactorLow: BulkField.gradientFactorLow,
  DiveField.gradientFactorHigh: BulkField.gradientFactorHigh,
  DiveField.decoAlgorithm: BulkField.decoAlgorithm,
  DiveField.decoConservatism: BulkField.decoConservatism,
  DiveField.diveComputerModel: BulkField.diveComputerModel,
  DiveField.windSpeed: BulkField.windSpeed,
  DiveField.windDirection: BulkField.windDirection,
  DiveField.cloudCover: BulkField.cloudCover,
  DiveField.precipitation: BulkField.precipitation,
  DiveField.humidity: BulkField.humidity,
  DiveField.weatherDescription: BulkField.weatherDescription,
  DiveField.diveMode: BulkField.diveMode,
  DiveField.setpointLow: BulkField.setpointLow,
  DiveField.setpointHigh: BulkField.setpointHigh,
  DiveField.setpointDeco: BulkField.setpointDeco,
  DiveField.diluentGas: BulkField.diluentGas,
  DiveField.scrubberType: BulkField.scrubberType,
  DiveField.scrubberDuration: BulkField.scrubberDuration,
  DiveField.notes: BulkField.notes,
};
