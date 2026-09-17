import 'package:submersion/core/providers/provider.dart';
import 'package:submersion/core/services/export/excel/observations_excel_export_service.dart';
import 'package:submersion/features/equipment/domain/entities/equipment_observation.dart';
import 'package:submersion/features/equipment/domain/entities/equipment_item.dart';
import 'package:submersion/features/equipment/presentation/providers/equipment_arrangement_provider.dart';
import 'package:intl/intl.dart';
import 'package:submersion/features/equipment/presentation/providers/equipment_observation_providers.dart';
import 'package:submersion/features/settings/presentation/providers/settings_providers.dart';
import 'package:submersion/core/constants/pdf_templates.dart';
import 'package:submersion/core/services/export/excel/maintenance_excel_export_service.dart';
import 'package:submersion/core/services/export/csv/codec/csv_export_units.dart';
import 'package:submersion/core/services/export/export_service.dart';
import 'package:submersion/core/services/export/uddf/uddf_dive_relations.dart';
import 'package:submersion/core/services/export/uddf/uddf_export_profiles.dart';
import 'package:submersion/core/services/export/uddf/uddf_equipment_tag_source.dart';
import 'package:submersion/core/services/export/uddf/uddf_site_classification_source.dart';
import 'package:submersion/core/services/export/uddf/uddf_source_fetch.dart';
import 'package:submersion/core/services/export/pdf/diver_photo_loader.dart';
import 'package:submersion/core/services/pdf_templates/pdf_date_formatter.dart';
import 'package:submersion/core/services/pdf_templates/pdf_profile_series.dart';
import 'package:submersion/core/utils/unit_formatter.dart';
import 'package:submersion/core/services/pdf_templates/pdf_fonts.dart';
import 'package:submersion/core/services/pdf_templates/pdf_template_factory.dart';
import 'package:submersion/features/signatures/data/services/signature_storage_service.dart';
import 'package:submersion/features/dive_log/data/repositories/series_id_chunks.dart';
import 'package:submersion/features/dive_log/presentation/providers/dive_providers.dart';
import 'package:submersion/features/dive_log/presentation/providers/dive_computer_providers.dart';
import 'package:submersion/features/dive_sites/presentation/providers/site_providers.dart';
import 'package:submersion/features/equipment/presentation/providers/equipment_component_providers.dart';
import 'package:submersion/features/equipment/presentation/providers/equipment_providers.dart';
import 'package:submersion/features/equipment/presentation/providers/equipment_tag_providers.dart';
import 'package:submersion/features/equipment/presentation/providers/equipment_set_providers.dart';
import 'package:submersion/features/buddies/presentation/providers/buddy_providers.dart';
import 'package:submersion/features/certifications/presentation/providers/certification_providers.dart';
import 'package:submersion/features/dive_centers/presentation/providers/dive_center_providers.dart';
import 'package:submersion/features/divers/presentation/providers/diver_providers.dart';
import 'package:submersion/features/marine_life/presentation/providers/species_providers.dart';
import 'package:submersion/features/trips/presentation/providers/trip_providers.dart';
import 'package:submersion/features/tags/presentation/providers/tag_providers.dart';
import 'package:submersion/features/dive_types/domain/entities/dive_type_entity.dart';
import 'package:submersion/features/dive_types/presentation/providers/dive_type_providers.dart';
import 'package:submersion/features/site_types/presentation/providers/site_type_providers.dart';
import 'package:submersion/features/dive_roles/presentation/providers/dive_role_providers.dart';
import 'package:submersion/features/certifications/domain/entities/certification.dart';
import 'package:submersion/features/courses/presentation/providers/course_providers.dart';
import 'package:submersion/features/dive_log/domain/entities/dive.dart'
    show Dive;
import 'package:submersion/features/pre_dive/presentation/providers/pre_dive_providers.dart';
import 'package:submersion/l10n/arb/app_localizations.dart';
import 'package:submersion/l10n/l10n_extension.dart';

/// Export service provider
final exportServiceProvider = Provider<ExportService>((ref) {
  return ExportService();
});

/// Export state for tracking export operations
enum ExportStatus { idle, exporting, success, error }

/// Import phases for progress tracking
enum ImportPhase {
  parsing,
  trips,
  equipment,
  equipmentSets,
  buddies,
  diveCenters,
  certifications,
  diveTypes,
  tags,
  sites,
  dives,
  complete,
}

class ExportState {
  final ExportStatus status;
  final String? message;
  final String? filePath;

  /// Current import phase (for progress dialog)
  final ImportPhase? importPhase;

  /// Current item being processed (1-based for display)
  final int currentItem;

  /// Total items to process in current phase
  final int totalItems;

  const ExportState({
    this.status = ExportStatus.idle,
    this.message,
    this.filePath,
    this.importPhase,
    this.currentItem = 0,
    this.totalItems = 0,
  });

  /// Whether an import is actively in progress with progress tracking
  bool get isImporting =>
      status == ExportStatus.exporting && importPhase != null;

  /// Progress ratio for the current phase (0.0 to 1.0)
  double get progress => totalItems > 0 ? currentItem / totalItems : 0.0;

  ExportState copyWith({
    ExportStatus? status,
    String? message,
    String? filePath,
    ImportPhase? importPhase,
    int? currentItem,
    int? totalItems,
  }) {
    return ExportState(
      status: status ?? this.status,
      message: message ?? this.message,
      filePath: filePath ?? this.filePath,
      importPhase: importPhase ?? this.importPhase,
      currentItem: currentItem ?? this.currentItem,
      totalItems: totalItems ?? this.totalItems,
    );
  }

  /// Reset progress tracking (call when starting a new operation)
  ExportState resetProgress() {
    return ExportState(
      status: status,
      message: message,
      filePath: filePath,
      importPhase: null,
      currentItem: 0,
      totalItems: 0,
    );
  }
}

/// Export notifier for managing export operations
class ExportNotifier extends StateNotifier<ExportState> {
  final ExportService _exportService;
  final Ref _ref;

  ExportNotifier(this._exportService, this._ref) : super(const ExportState());

  /// Each assembly's part names in template order, for the Components
  /// column of the equipment CSV and the Excel sheet (issue #1487).
  Future<Map<String, List<String>>> _componentNamesFor(
    List<EquipmentItem> equipment,
  ) async {
    final rows = await _ref
        .read(equipmentComponentRepositoryProvider)
        .getAllComponents();
    return ComponentsIndex.fromRows(
      rows,
    ).namesByParent({for (final e in equipment) e.id: e});
  }

  /// Each exported item's tag names, by name, for the Tags column of the
  /// equipment CSV (issue #1942). One query for every item.
  Future<Map<String, List<String>>> _equipmentTagNamesFor(
    List<EquipmentItem> equipment,
  ) async {
    final byItem = await _ref
        .read(equipmentTagRepositoryProvider)
        .getTagsByEquipment();
    return {
      for (final item in equipment)
        if (byItem[item.id] case final tags? when tags.isNotEmpty)
          item.id: [for (final tag in tags) tag.name],
    };
  }

  /// The diver's dive types by id, so the CSV, Excel and PDF exports name each
  /// type as the diver did rather than rebuilding a name from its id (#1834).
  Future<Map<String, DiveTypeEntity>> _diveTypesById() =>
      diveTypesByIdOrEmpty(_ref.read(diveTypesByIdProvider.future));

  /// Localizations for the status messages this notifier publishes.
  ///
  /// A provider has no BuildContext, so the persisted locale setting is
  /// resolved through the same helper SyncNotifier uses. Read (not cached) so
  /// a locale change is picked up by the next operation.
  AppLocalizations get _l10n => l10nForLocaleTag(_ref.read(localeProvider));

  /// Units for a CSV export: the diver's settings for My units, or the
  /// historical metric format.
  CsvExportUnits _csvUnits(CsvUnitMode mode) =>
      CsvExportUnits.forMode(mode, _ref.read(settingsProvider));

  Future<void> exportDivesToCsv({
    CsvUnitMode unitMode = CsvUnitMode.metric,
  }) async {
    state = state.copyWith(
      status: ExportStatus.exporting,
      message: _l10n.settings_export_progress_divesCsv,
    );
    try {
      final dives = await _validatedDiverDives();
      if (dives.isEmpty) {
        state = state.copyWith(
          status: ExportStatus.error,
          message: _l10n.settings_export_empty_dives,
        );
        return;
      }
      final path = await _exportService.exportDivesToCsv(
        dives,
        units: _csvUnits(unitMode),
        diveTypesById: await _diveTypesById(),
      );
      state = state.copyWith(
        status: ExportStatus.success,
        message: _l10n.settings_export_success_dives,
        filePath: path,
      );
    } catch (e) {
      state = state.copyWith(
        status: ExportStatus.error,
        message: _l10n.settings_data_export_failed('$e'),
      );
    }
  }

  Future<void> exportSitesToCsv({
    CsvUnitMode unitMode = CsvUnitMode.metric,
  }) async {
    state = state.copyWith(
      status: ExportStatus.exporting,
      message: _l10n.settings_export_progress_sitesCsv,
    );
    try {
      final sites = _ref.read(sitesProvider).value ?? [];
      if (sites.isEmpty) {
        state = state.copyWith(
          status: ExportStatus.error,
          message: _l10n.settings_export_empty_sites,
        );
        return;
      }
      final path = await _exportService.exportSitesToCsv(
        sites,
        units: _csvUnits(unitMode),
      );
      state = state.copyWith(
        status: ExportStatus.success,
        message: _l10n.settings_export_success_sites,
        filePath: path,
      );
    } catch (e) {
      state = state.copyWith(
        status: ExportStatus.error,
        message: _l10n.settings_data_export_failed('$e'),
      );
    }
  }

  Future<void> exportEquipmentToCsv({
    CsvUnitMode unitMode = CsvUnitMode.metric,
  }) async {
    state = state.copyWith(
      status: ExportStatus.exporting,
      message: _l10n.settings_export_progress_equipmentCsv,
    );
    try {
      final equipment = _ref.read(allEquipmentProvider).value ?? [];
      if (equipment.isEmpty) {
        state = state.copyWith(
          status: ExportStatus.error,
          message: _l10n.settings_export_empty_equipment,
        );
        return;
      }
      final path = await _exportService.exportEquipmentToCsv(
        equipment,
        componentNames: await _componentNamesFor(equipment),
        tagNames: await _equipmentTagNamesFor(equipment),
        units: _csvUnits(unitMode),
      );
      state = state.copyWith(
        status: ExportStatus.success,
        message: _l10n.settings_export_success_equipment,
        filePath: path,
      );
    } catch (e) {
      state = state.copyWith(
        status: ExportStatus.error,
        message: _l10n.settings_data_export_failed('$e'),
      );
    }
  }

  /// The active diver's gear check-ins. The export's equipment and dives
  /// are scoped to that diver, and a shared item can carry another diver's
  /// check-in, so an unscoped read would put it in this diver's file.
  Future<List<EquipmentObservation>> _diverObservations() async {
    final diverId = await _ref.read(validatedCurrentDiverIdProvider.future);
    return _ref
        .read(equipmentObservationRepositoryProvider)
        .getAll(diverId: diverId);
  }

  /// [_validatedDiverDives] with each dive's recorded profile, for the full
  /// UDDF backup. The dive list leaves profiles out, and the backup writes its
  /// samples and tank pressures from them (issue #1874); the workbook draws no
  /// profile, so it keeps the lean list.
  Future<List<Dive>> _validatedDiverDivesWithProfiles() async {
    final dives = await _validatedDiverDives();
    state = state.copyWith(
      message: _l10n.settings_export_progress_loadingProfiles,
    );
    return attachMergedProfiles(_ref.read(diveRepositoryProvider), dives);
  }

  /// The active diver's dives for the full UDDF export and the workbook,
  /// through the validated diver id like their gear and check-ins. [divesProvider] follows the raw
  /// id, so a stale one (a restore, or a sync that removed the diver) found
  /// no dives and aborted the export as empty, and any dive list scoped
  /// apart from the check-ins could leave a check-in's dive out of the file.
  ///
  /// The dives CSV and the PDF logbook read it too: they print linked buddy
  /// names (#1861), and [divesProvider] only refreshes on `dives` table
  /// writes, so a buddy renamed since the list was cached exported under its
  /// old name. An export is one-shot, so a fresh read costs nothing extra.
  Future<List<Dive>> _validatedDiverDives() async {
    final diverId = await _ref.read(validatedCurrentDiverIdProvider.future);
    return _ref.read(diveRepositoryProvider).getAllDives(diverId: diverId);
  }

  /// The per-dive relations both full UDDF exports write, one batched read
  /// per relation (issue #1867).
  Future<UddfDiveRelations> _uddfDiveRelations(List<Dive> dives) =>
      loadUddfDiveRelations(
        buddyRepository: _ref.read(buddyRepositoryProvider),
        tagRepository: _ref.read(tagRepositoryProvider),
        diveRepository: _ref.read(diveRepositoryProvider),
        diveComputerRepository: _ref.read(diveComputerRepositoryProvider),
        tankPressureRepository: _ref.read(tankPressureRepositoryProvider),
        dives: dives,
      );

  /// Every gear check-in flattened for the Excel sheet and the CSV file:
  /// the item name and type, the dive number when the check-in is on a
  /// dive the export knows, and the observation itself (condition 3a).
  Future<List<ObservationExportRow>> _observationRows(
    List<EquipmentItem> equipment,
    List<Dive> dives,
  ) async {
    final observations = await _diverObservations();
    final itemsById = {for (final e in equipment) e.id: e};
    final numberByDive = <String, int?>{
      for (final d in dives) d.id: d.diveNumber,
    };
    // [dives] follows the raw diver id and the check-ins the validated one,
    // so a stale raw id leaves the check-ins' dives out of the list. Look
    // those up by id so each row keeps its dive number.
    final missing = {
      for (final o in observations)
        if (o.diveId case final id? when !numberByDive.containsKey(id)) id,
    };
    if (missing.isNotEmpty) {
      final found = await _ref
          .read(diveRepositoryProvider)
          .getSummariesByIds(missing.toList());
      for (final s in found) {
        numberByDive[s.id] = s.diveNumber;
      }
    }
    return [
      for (final o in observations)
        if (itemsById[o.equipmentId] case final item?)
          (
            equipmentName: item.name,
            equipmentType: item.type.displayName,
            diveNumber: o.diveId == null ? null : numberByDive[o.diveId],
            observation: o,
          ),
    ];
  }

  Future<void> exportObservationsToCsv() async {
    state = state.copyWith(
      status: ExportStatus.exporting,
      message: _l10n.settings_export_progress_observationsCsv,
    );
    try {
      final equipment = await _ref.read(allEquipmentProvider.future);
      final dives = await _ref.read(divesProvider.future);
      final rows = await _observationRows(equipment, dives);
      if (rows.isEmpty) {
        state = state.copyWith(
          status: ExportStatus.error,
          message: _l10n.settings_export_empty_observations,
        );
        return;
      }
      final path = await _exportService.exportObservationsToCsv(rows);
      state = state.copyWith(
        status: ExportStatus.success,
        message: _l10n.settings_export_success_observations,
        filePath: path,
      );
    } catch (e) {
      state = state.copyWith(
        status: ExportStatus.error,
        message: _l10n.settings_data_export_failed('$e'),
      );
    }
  }

  /// Save gear check-ins CSV to a user-selected location.
  Future<void> saveObservationsCsvToFile() async {
    state = state.copyWith(
      status: ExportStatus.exporting,
      message: _l10n.settings_export_progress_preparingObservationsCsv,
    );
    try {
      final equipment = await _ref.read(allEquipmentProvider.future);
      final dives = await _ref.read(divesProvider.future);
      final rows = await _observationRows(equipment, dives);
      if (rows.isEmpty) {
        state = state.copyWith(
          status: ExportStatus.error,
          message: _l10n.settings_export_empty_observations,
        );
        return;
      }

      state = state.copyWith(
        message: _l10n.settings_export_progress_chooseLocation,
      );
      final path = await _exportService.saveObservationsCsvToFile(
        rows,
        dialogTitle: _l10n.settings_export_saveObservationsCsvDialogTitle,
      );

      if (path == null) {
        state = state.copyWith(
          status: ExportStatus.idle,
          message: _l10n.settings_export_cancelled_save,
        );
        return;
      }

      state = state.copyWith(
        status: ExportStatus.success,
        message: _l10n.settings_export_saved_observationsCsv,
        filePath: path,
      );
    } catch (e) {
      state = state.copyWith(
        status: ExportStatus.error,
        message: _l10n.settings_export_saveFailed('$e'),
      );
    }
  }

  /// Export dives to PDF with the specified options.
  ///
  /// Uses the template system to generate PDFs in different styles.
  /// If [options] is null, uses the default Detailed template.
  Future<void> exportDivesToPdf([PdfExportOptions? options]) async {
    final exportOptions = options ?? const PdfExportOptions();

    state = state.copyWith(
      status: ExportStatus.exporting,
      message: _l10n.settings_export_progress_pdf,
    );
    try {
      final dives = await _validatedDiverDives();
      if (dives.isEmpty) {
        state = state.copyWith(
          status: ExportStatus.error,
          message: _l10n.settings_export_empty_dives,
        );
        return;
      }

      final pdfBytes = await _buildLogbookPdfBytes(exportOptions, dives);

      // Save and share the PDF
      final path = await _exportService.sharePdfBytes(
        pdfBytes,
        'dive_logbook_${exportOptions.template.name}_${DateFormat('yyyy-MM-dd').format(DateTime.now())}.pdf',
      );

      state = state.copyWith(
        status: ExportStatus.success,
        message: _l10n.settings_export_success_pdf,
        filePath: path,
      );
    } catch (e) {
      state = state.copyWith(
        status: ExportStatus.error,
        message: _l10n.settings_data_export_failed('$e'),
      );
    }
  }

  /// Build logbook PDF bytes honoring [exportOptions] (template, page size,
  /// certification cards, diver personalization). Shared by the share and
  /// save-to-file paths so both respect the selected detail level (#644).
  Future<List<int>> _buildLogbookPdfBytes(
    PdfExportOptions exportOptions,
    List<Dive> dives,
  ) async {
    // Load signatures for all dives
    state = state.copyWith(
      message: _l10n.settings_export_progress_loadingSignatures,
    );
    final diveSignatures = await SignatureStorageService()
        .getSignaturesForDives([for (final dive in dives) dive.id]);

    // Load certifications if requested
    List<Certification>? certifications;
    if (exportOptions.includeCertificationCards) {
      state = state.copyWith(
        message: _l10n.settings_export_progress_loadingCertifications,
      );
      certifications = await _ref.read(allCertificationsProvider.future);
    }

    // Get current diver for personalization
    final diver = await _ref.read(currentDiverProvider.future);
    final diverPhoto = await _ref.read(diverPhotoLoaderProvider)(
      diver?.photoPath,
    );

    // Depth profiles, for the templates that chart them. getAllDives skips
    // profile hydration for performance, so they are loaded here, in one
    // batched query, and thinned before any template sees them.
    Map<String, PdfProfileSeries>? profiles;
    if (exportOptions.template == PdfTemplate.detailed) {
      state = state.copyWith(
        message: _l10n.settings_export_progress_loadingProfiles,
      );
      // Chunked and thinned as we go. Loading every dive's raw samples first
      // and downsampling afterwards would hold the whole logbook's sample set
      // in memory at once, which is exactly what the thinning exists to avoid.
      const chunkSize = 50;
      final repository = _ref.read(diveRepositoryProvider);
      final ids = dives.map((d) => d.id).toList();
      final thinned = <String, PdfProfileSeries>{};

      for (final chunk in seriesIdChunks(ids, size: chunkSize)) {
        final raw = await repository.getMergedProfilesForDives(chunk);
        for (final entry in raw.entries) {
          thinned[entry.key] = PdfProfileSeries.downsampled(entry.value);
        }
      }
      profiles = thinned;
    }

    // Initialize fonts for proper Unicode support
    state = state.copyWith(
      message: _l10n.settings_export_progress_loadingFonts,
    );
    await PdfFonts.instance.initialize();

    // Get the appropriate template builder
    state = state.copyWith(
      message: _l10n.settings_export_progress_templatePdf(
        exportOptions.template.displayName,
      ),
    );
    final factory = PdfTemplateFactory();
    final builder = factory.getBuilder(exportOptions.template);

    // The logbook is a document the diver prints or shares, so its dates and
    // times follow the diver's preferences (#964); the file name stays ISO.
    final settings = _ref.read(settingsProvider);

    // The arrangement notifier starts at the defaults and adopts the stored
    // value asynchronously, so reading it straight away would export the
    // defaults over a saved preference whenever nothing in the session had
    // instantiated it yet. Awaiting the first load is what the sibling path
    // in PdfExportService gets by reading the repository directly.
    await _ref.read(equipmentArrangementNotifierProvider.notifier).loaded;

    return builder.buildPdf(
      dives: dives,
      // The logbook is a document a human reads, so gear follows the diver's
      // arrangement (#1486, #1576).
      gearArrangement: _ref.read(equipmentArrangementProvider),
      pageSize: exportOptions.pageSize,
      dates: PdfDateFormatter(
        dateFormat: settings.dateFormat,
        timeFormat: settings.timeFormat,
      ),
      units: UnitFormatter(settings),
      title: _l10n.settings_export_pdfDocumentTitle,
      diveSignatures: diveSignatures.isNotEmpty ? diveSignatures : null,
      certifications: certifications,
      diver: diver,
      profiles: profiles,
      diverPhoto: diverPhoto,
      includeVerificationAreas: exportOptions.includeVerificationAreas,
      diveTypesById: await _diveTypesById(),
    );
  }

  Future<void> exportDivesToUddf([UddfExportOptions? options]) async {
    final exportOptions = options ?? const UddfExportOptions();
    state = state.copyWith(
      status: ExportStatus.exporting,
      message: _l10n.settings_export_progress_uddf,
    );
    try {
      final dives = await _validatedDiverDivesWithProfiles();

      // Collect all data for comprehensive export
      state = state.copyWith(
        message: _l10n.settings_export_progress_collectingData,
      );
      final sites = await _ref.read(sitesProvider.future);
      final equipment = await _ref.read(allEquipmentProvider.future);
      // A library can hold gear, sites and bench check-ins before any dive;
      // the full export carries those too (the builder takes an empty dive
      // list). Only a library with none of them is refused, as the workbook
      // does.
      if (dives.isEmpty && sites.isEmpty && equipment.isEmpty) {
        state = state.copyWith(
          status: ExportStatus.error,
          message: _l10n.settings_export_empty_data,
        );
        return;
      }
      final buddies = await _ref.read(allBuddiesProvider.future);
      final certifications = await _ref.read(allCertificationsProvider.future);
      final diveCenters = await _ref.read(allDiveCentersProvider.future);
      final species = await _ref.read(allSpeciesProvider.future);

      // Collect new comprehensive data
      final currentDiver = await _ref.read(currentDiverProvider.future);
      final trips = await _ref.read(allTripsProvider.future);
      final tags = await _ref.read(tagsProvider.future);
      final customDiveTypes = await _ref.read(diveTypesProvider.future);
      // Site types and site tags (issue #1765). The definitions are the
      // diver's own vocabulary plus whatever the exported sites reference,
      // resolved by id: a shared site can carry another profile's custom
      // type or tag, and a reference without its definition is dropped on
      // import.
      final siteClassification = await loadSiteClassificationForExport(
        _ref.read(siteClassificationRepositoryProvider),
        _ref.read(siteTypeRepositoryProvider),
        [for (final s in sites) s.id],
      );
      final customSiteTypes = mergeById(
        [
          for (final type in await _ref.read(siteTypesProvider.future))
            if (!type.isBuiltIn) type,
        ],
        siteClassification.customSiteTypes,
        (type) => type.id,
      );
      // Equipment tags (issue #1942): each item's tag ids and the tags they
      // name, resolved by id like the site tags above.
      final equipmentTags = await loadEquipmentTagsForExport(
        _ref.read(equipmentTagRepositoryProvider),
        [for (final e in equipment) e.id],
      );
      final customDiveRoles = (await _ref.read(
        allDiveRolesProvider.future,
      )).where((r) => !r.isBuiltIn).toList();
      final diveComputers = await _ref.read(allDiveComputersProvider.future);
      final equipmentSets = await _ref.read(equipmentSetsProvider.future);
      // Assembly templates ride with the equipment (issue #1487).
      final components = await _ref
          .read(equipmentComponentRepositoryProvider)
          .getAllComponents();

      // Fetch courses
      final courses = await _ref.read(allCoursesProvider.future);

      final allServiceRecords = await loadUddfServiceRecords(
        _ref.read(serviceRecordRepositoryProvider),
        equipment,
      );
      final relations = await _uddfDiveRelations(dives);

      state = state.copyWith(message: _l10n.settings_export_progress_uddf);
      final path = await _exportService.exportAllDataToUddf(
        dives: dives,
        sites: sites,
        equipment: equipment,
        buddies: buddies,
        certifications: certifications,
        diveCenters: diveCenters,
        species: species,
        diveBuddies: relations.diveBuddies,
        owner: currentDiver,
        trips: trips,
        tags: mergeById(
          mergeById(tags, siteClassification.siteTags, (tag) => tag.id),
          equipmentTags.tags,
          (tag) => tag.id,
        ),
        diveTags: relations.diveTags,
        customDiveTypes: customDiveTypes,
        customSiteTypes: customSiteTypes,
        siteTypeIdsBySite: siteClassification.typeIdsBySite,
        siteTagIdsBySite: siteClassification.tagIdsBySite,
        equipmentTagIdsByItem: equipmentTags.tagIdsByItem,
        customDiveRoles: customDiveRoles,
        diveComputers: diveComputers,
        equipmentSets: equipmentSets,
        components: components,
        serviceRecords: allServiceRecords,
        observations: await _diverObservations(),
        courses: courses,
        diveWeights: relations.diveWeights,
        diveGasSwitches: relations.diveGasSwitches,
        diveProfileEvents: relations.diveProfileEvents,
        diveTankPressures: relations.diveTankPressures,
        dataSources: await _ref.read(uddfSourceFetchProvider)(
          dives.map((d) => d.id).toList(growable: false),
          exportOptions,
        ),
        options: exportOptions,
      );
      state = state.copyWith(
        status: ExportStatus.success,
        message: _l10n.settings_export_success_uddf,
        filePath: path,
      );
    } catch (e) {
      state = state.copyWith(
        status: ExportStatus.error,
        message: _l10n.settings_data_export_failed('$e'),
      );
    }
  }

  /// Export all data to Excel format with multiple sheets.
  ///
  /// Creates an Excel workbook with sheets for dives, sites, equipment,
  /// and statistics. All measurements are converted to user's unit preferences.
  Future<void> exportToExcel() async {
    state = state.copyWith(
      status: ExportStatus.exporting,
      message: _l10n.settings_export_progress_excel,
    );
    try {
      // Validated, like its check-ins sheet (see _validatedDiverDives).
      final dives = await _validatedDiverDives();
      final sites = await _ref.read(sitesProvider.future);
      final equipment = await _ref.read(allEquipmentProvider.future);
      // Checklist runs ride along in the workbook. Fetched in bulk: one query
      // for the runs, one for every item across them.
      final preDiveSessions = await _ref.read(preDiveSessionsProvider.future);
      final preDiveItems = await _ref
          .read(preDiveSessionRepositoryProvider)
          .getItemsForSessions([for (final s in preDiveSessions) s.id]);

      if (dives.isEmpty && sites.isEmpty && equipment.isEmpty) {
        state = state.copyWith(
          status: ExportStatus.error,
          message: _l10n.settings_export_empty_data,
        );
        return;
      }

      // Get user's unit preferences
      final settings = _ref.read(settingsProvider);

      state = state.copyWith(
        message: _l10n.settings_export_progress_buildingExcel,
      );
      final path = await _exportService.exportToExcel(
        dives: dives,
        sites: sites,
        equipment: equipment,
        componentNames: await _componentNamesFor(equipment),
        depthUnit: settings.depthUnit,
        temperatureUnit: settings.temperatureUnit,
        pressureUnit: settings.pressureUnit,
        volumeUnit: settings.volumeUnit,
        dateFormat: settings.dateFormat,
        preDiveSessions: preDiveSessions,
        preDiveItemsBySession: preDiveItems,
        observationRows: await _observationRows(equipment, dives),
        diveTypesById: await _diveTypesById(),
      );

      state = state.copyWith(
        status: ExportStatus.success,
        message: _l10n.settings_export_success_excel,
        filePath: path,
      );
    } catch (e) {
      state = state.copyWith(
        status: ExportStatus.error,
        message: _l10n.settings_data_export_failed('$e'),
      );
    }
  }

  /// Export dive sites to KML format for Google Earth.
  ///
  /// Creates a KML file with placemarks for each dive site with GPS
  /// coordinates. Each placemark includes site details and dive history.
  Future<void> exportToKml() async {
    state = state.copyWith(
      status: ExportStatus.exporting,
      message: _l10n.settings_export_progress_kml,
    );
    try {
      final sites = await _ref.read(sitesProvider.future);
      final dives = await _ref.read(divesProvider.future);

      if (sites.isEmpty) {
        state = state.copyWith(
          status: ExportStatus.error,
          message: _l10n.settings_export_empty_diveSites,
        );
        return;
      }

      // Get user's unit preferences
      final settings = _ref.read(settingsProvider);

      state = state.copyWith(
        message: _l10n.settings_export_progress_buildingKml,
      );
      final (path, skippedCount) = await _exportService.exportToKml(
        sites: sites,
        dives: dives,
        depthUnit: settings.depthUnit,
        dateFormat: settings.dateFormat,
      );

      state = state.copyWith(
        status: ExportStatus.success,
        message: _l10n.settings_export_success_kml(skippedCount),
        filePath: path,
      );
    } catch (e) {
      state = state.copyWith(
        status: ExportStatus.error,
        message: _l10n.settings_data_export_failed('$e'),
      );
    }
  }

  /// Save Excel file to a user-selected location.
  ///
  /// Opens a file picker dialog allowing the user to choose where to save.
  Future<void> saveExcelToFile() async {
    state = state.copyWith(
      status: ExportStatus.exporting,
      message: _l10n.settings_export_progress_preparingExcel,
    );
    try {
      // Validated, like its check-ins sheet (see _validatedDiverDives).
      final dives = await _validatedDiverDives();
      final sites = await _ref.read(sitesProvider.future);
      final equipment = await _ref.read(allEquipmentProvider.future);
      // Checklist runs ride along in the workbook. Fetched in bulk: one query
      // for the runs, one for every item across them.
      final preDiveSessions = await _ref.read(preDiveSessionsProvider.future);
      final preDiveItems = await _ref
          .read(preDiveSessionRepositoryProvider)
          .getItemsForSessions([for (final s in preDiveSessions) s.id]);

      if (dives.isEmpty && sites.isEmpty && equipment.isEmpty) {
        state = state.copyWith(
          status: ExportStatus.error,
          message: _l10n.settings_export_empty_data,
        );
        return;
      }

      // Get user's unit preferences
      final settings = _ref.read(settingsProvider);

      state = state.copyWith(
        message: _l10n.settings_export_progress_chooseLocation,
      );
      final path = await _exportService.saveExcelToFile(
        dives: dives,
        sites: sites,
        equipment: equipment,
        componentNames: await _componentNamesFor(equipment),
        depthUnit: settings.depthUnit,
        temperatureUnit: settings.temperatureUnit,
        pressureUnit: settings.pressureUnit,
        volumeUnit: settings.volumeUnit,
        dateFormat: settings.dateFormat,
        preDiveSessions: preDiveSessions,
        preDiveItemsBySession: preDiveItems,
        observationRows: await _observationRows(equipment, dives),
        diveTypesById: await _diveTypesById(),
      );

      if (path == null) {
        state = state.copyWith(
          status: ExportStatus.idle,
          message: _l10n.settings_export_cancelled_save,
        );
        return;
      }

      state = state.copyWith(
        status: ExportStatus.success,
        message: _l10n.settings_export_saved_excel,
        filePath: path,
      );
    } catch (e) {
      state = state.copyWith(
        status: ExportStatus.error,
        message: _l10n.settings_export_saveFailed('$e'),
      );
    }
  }

  /// Flattens every equipment item's service history into log rows.
  ///
  /// Resolved here rather than inside the export service so that service
  /// stays a pure sheet builder with no repository dependencies.
  Future<List<MaintenanceLogRow>> _buildMaintenanceRows() async {
    final equipment = await _ref.read(allEquipmentProvider.future);
    final kinds = await _ref.read(serviceKindsProvider.future);
    final kindsById = {for (final k in kinds) k.id: k};
    final recordsByItem = await _ref
        .read(serviceRecordRepositoryProvider)
        .getRecordsForEquipmentIds([for (final item in equipment) item.id]);

    final rows = <MaintenanceLogRow>[];
    for (final item in equipment) {
      for (final record in recordsByItem[item.id] ?? const []) {
        rows.add((
          equipmentName: item.name,
          equipmentType: item.type.displayName,
          // Blank when the record is not tied to a clock.
          serviceTypeName: kindsById[record.serviceKindId]?.name ?? '',
          serviceCategory: record.serviceCategory,
          record: record,
        ));
      }
    }
    return rows;
  }

  /// Export the maintenance log for all equipment and share it.
  Future<void> exportMaintenanceLog() async {
    state = state.copyWith(
      status: ExportStatus.exporting,
      message: _l10n.settings_export_progress_maintenance,
    );
    try {
      final rows = await _buildMaintenanceRows();
      if (rows.isEmpty) {
        state = state.copyWith(
          status: ExportStatus.error,
          message: _l10n.settings_export_empty_data,
        );
        return;
      }
      final settings = _ref.read(settingsProvider);
      final path = await _exportService.exportMaintenanceLog(
        rows: rows,
        dateFormat: settings.dateFormat,
      );
      state = state.copyWith(
        status: ExportStatus.success,
        message: _l10n.settings_export_success_maintenance,
        filePath: path,
      );
    } catch (e) {
      state = state.copyWith(
        status: ExportStatus.error,
        message: _l10n.settings_data_export_failed('$e'),
      );
    }
  }

  /// Save the maintenance log to a user-selected location.
  Future<void> saveMaintenanceLogToFile() async {
    state = state.copyWith(
      status: ExportStatus.exporting,
      message: _l10n.settings_export_progress_maintenance,
    );
    try {
      final rows = await _buildMaintenanceRows();
      if (rows.isEmpty) {
        state = state.copyWith(
          status: ExportStatus.error,
          message: _l10n.settings_export_empty_data,
        );
        return;
      }
      final settings = _ref.read(settingsProvider);
      state = state.copyWith(
        message: _l10n.settings_export_progress_chooseLocation,
      );
      final path = await _exportService.saveMaintenanceLogToFile(
        rows: rows,
        dateFormat: settings.dateFormat,
      );
      // null means the diver cancelled the save panel, which is a no-op and
      // must never be reported as success.
      if (path == null) {
        state = state.copyWith(
          status: ExportStatus.idle,
          message: _l10n.settings_export_cancelled_save,
        );
        return;
      }
      state = state.copyWith(
        status: ExportStatus.success,
        message: _l10n.settings_export_saved_maintenance,
        filePath: path,
      );
    } catch (e) {
      state = state.copyWith(
        status: ExportStatus.error,
        message: _l10n.settings_export_saveFailed('$e'),
      );
    }
  }

  /// Save KML file to a user-selected location.
  ///
  /// Opens a file picker dialog allowing the user to choose where to save.
  Future<void> saveKmlToFile() async {
    state = state.copyWith(
      status: ExportStatus.exporting,
      message: _l10n.settings_export_progress_preparingKml,
    );
    try {
      final sites = await _ref.read(sitesProvider.future);
      final dives = await _ref.read(divesProvider.future);

      if (sites.isEmpty) {
        state = state.copyWith(
          status: ExportStatus.error,
          message: _l10n.settings_export_empty_diveSites,
        );
        return;
      }

      // Get user's unit preferences
      final settings = _ref.read(settingsProvider);

      state = state.copyWith(
        message: _l10n.settings_export_progress_chooseLocation,
      );
      final (path, skippedCount) = await _exportService.saveKmlToFile(
        sites: sites,
        dives: dives,
        depthUnit: settings.depthUnit,
        dateFormat: settings.dateFormat,
      );

      if (path == null) {
        state = state.copyWith(
          status: ExportStatus.idle,
          message: _l10n.settings_export_cancelled_save,
        );
        return;
      }

      state = state.copyWith(
        status: ExportStatus.success,
        message: _l10n.settings_export_saved_kml(skippedCount),
        filePath: path,
      );
    } catch (e) {
      state = state.copyWith(
        status: ExportStatus.error,
        message: _l10n.settings_export_saveFailed('$e'),
      );
    }
  }

  // ==================== CSV SAVE TO FILE ====================

  /// Save dives CSV to a user-selected location.
  Future<void> saveDivesCsvToFile({
    CsvUnitMode unitMode = CsvUnitMode.metric,
  }) async {
    state = state.copyWith(
      status: ExportStatus.exporting,
      message: _l10n.settings_export_progress_preparingDivesCsv,
    );
    try {
      final dives = await _validatedDiverDives();
      if (dives.isEmpty) {
        state = state.copyWith(
          status: ExportStatus.error,
          message: _l10n.settings_export_empty_dives,
        );
        return;
      }

      state = state.copyWith(
        message: _l10n.settings_export_progress_chooseLocation,
      );
      final path = await _exportService.saveDivesCsvToFile(
        dives,
        dialogTitle: _l10n.settings_export_saveDivesCsvDialogTitle,
        units: _csvUnits(unitMode),
        diveTypesById: await _diveTypesById(),
      );

      if (path == null) {
        state = state.copyWith(
          status: ExportStatus.idle,
          message: _l10n.settings_export_cancelled_save,
        );
        return;
      }

      state = state.copyWith(
        status: ExportStatus.success,
        message: _l10n.settings_export_saved_divesCsv,
        filePath: path,
      );
    } catch (e) {
      state = state.copyWith(
        status: ExportStatus.error,
        message: _l10n.settings_export_saveFailed('$e'),
      );
    }
  }

  /// Save sites CSV to a user-selected location.
  Future<void> saveSitesCsvToFile({
    CsvUnitMode unitMode = CsvUnitMode.metric,
  }) async {
    state = state.copyWith(
      status: ExportStatus.exporting,
      message: _l10n.settings_export_progress_preparingSitesCsv,
    );
    try {
      final sites = _ref.read(sitesProvider).value ?? [];
      if (sites.isEmpty) {
        state = state.copyWith(
          status: ExportStatus.error,
          message: _l10n.settings_export_empty_sites,
        );
        return;
      }

      state = state.copyWith(
        message: _l10n.settings_export_progress_chooseLocation,
      );
      final path = await _exportService.saveSitesCsvToFile(
        sites,
        dialogTitle: _l10n.settings_export_saveSitesCsvDialogTitle,
        units: _csvUnits(unitMode),
      );

      if (path == null) {
        state = state.copyWith(
          status: ExportStatus.idle,
          message: _l10n.settings_export_cancelled_save,
        );
        return;
      }

      state = state.copyWith(
        status: ExportStatus.success,
        message: _l10n.settings_export_saved_sitesCsv,
        filePath: path,
      );
    } catch (e) {
      state = state.copyWith(
        status: ExportStatus.error,
        message: _l10n.settings_export_saveFailed('$e'),
      );
    }
  }

  /// Save equipment CSV to a user-selected location.
  Future<void> saveEquipmentCsvToFile({
    CsvUnitMode unitMode = CsvUnitMode.metric,
  }) async {
    state = state.copyWith(
      status: ExportStatus.exporting,
      message: _l10n.settings_export_progress_preparingEquipmentCsv,
    );
    try {
      final equipment = _ref.read(allEquipmentProvider).value ?? [];
      if (equipment.isEmpty) {
        state = state.copyWith(
          status: ExportStatus.error,
          message: _l10n.settings_export_empty_equipment,
        );
        return;
      }

      state = state.copyWith(
        message: _l10n.settings_export_progress_chooseLocation,
      );
      final path = await _exportService.saveEquipmentCsvToFile(
        equipment,
        componentNames: await _componentNamesFor(equipment),
        tagNames: await _equipmentTagNamesFor(equipment),
        dialogTitle: _l10n.settings_export_saveEquipmentCsvDialogTitle,
        units: _csvUnits(unitMode),
      );

      if (path == null) {
        state = state.copyWith(
          status: ExportStatus.idle,
          message: _l10n.settings_export_cancelled_save,
        );
        return;
      }

      state = state.copyWith(
        status: ExportStatus.success,
        message: _l10n.settings_export_saved_equipmentCsv,
        filePath: path,
      );
    } catch (e) {
      state = state.copyWith(
        status: ExportStatus.error,
        message: _l10n.settings_export_saveFailed('$e'),
      );
    }
  }

  // ==================== UDDF SAVE TO FILE ====================

  /// Save comprehensive UDDF to a user-selected location.
  /// Collects all data (same as share) so the export round-trips correctly.
  Future<void> saveUddfToFile([UddfExportOptions? options]) async {
    final exportOptions = options ?? const UddfExportOptions();
    state = state.copyWith(
      status: ExportStatus.exporting,
      message: _l10n.settings_export_progress_preparingUddf,
    );
    try {
      final dives = await _validatedDiverDivesWithProfiles();

      // Collect all data for comprehensive export
      state = state.copyWith(
        message: _l10n.settings_export_progress_collectingData,
      );
      final sites = await _ref.read(sitesProvider.future);
      final equipment = await _ref.read(allEquipmentProvider.future);
      // A library can hold gear, sites and bench check-ins before any dive;
      // the full export carries those too (the builder takes an empty dive
      // list). Only a library with none of them is refused, as the workbook
      // does.
      if (dives.isEmpty && sites.isEmpty && equipment.isEmpty) {
        state = state.copyWith(
          status: ExportStatus.error,
          message: _l10n.settings_export_empty_data,
        );
        return;
      }
      final buddies = await _ref.read(allBuddiesProvider.future);
      final certifications = await _ref.read(allCertificationsProvider.future);
      final diveCenters = await _ref.read(allDiveCentersProvider.future);
      final species = await _ref.read(allSpeciesProvider.future);
      final currentDiver = await _ref.read(currentDiverProvider.future);
      final trips = await _ref.read(allTripsProvider.future);
      final tags = await _ref.read(tagsProvider.future);
      final customDiveTypes = await _ref.read(diveTypesProvider.future);
      // Site types and site tags (issue #1765). The definitions are the
      // diver's own vocabulary plus whatever the exported sites reference,
      // resolved by id: a shared site can carry another profile's custom
      // type or tag, and a reference without its definition is dropped on
      // import.
      final siteClassification = await loadSiteClassificationForExport(
        _ref.read(siteClassificationRepositoryProvider),
        _ref.read(siteTypeRepositoryProvider),
        [for (final s in sites) s.id],
      );
      final customSiteTypes = mergeById(
        [
          for (final type in await _ref.read(siteTypesProvider.future))
            if (!type.isBuiltIn) type,
        ],
        siteClassification.customSiteTypes,
        (type) => type.id,
      );
      // Equipment tags (issue #1942): each item's tag ids and the tags they
      // name, resolved by id like the site tags above.
      final equipmentTags = await loadEquipmentTagsForExport(
        _ref.read(equipmentTagRepositoryProvider),
        [for (final e in equipment) e.id],
      );
      final customDiveRoles = (await _ref.read(
        allDiveRolesProvider.future,
      )).where((r) => !r.isBuiltIn).toList();
      final diveComputers = await _ref.read(allDiveComputersProvider.future);
      final equipmentSets = await _ref.read(equipmentSetsProvider.future);
      // Assembly templates ride with the equipment (issue #1487).
      final components = await _ref
          .read(equipmentComponentRepositoryProvider)
          .getAllComponents();
      final courses = await _ref.read(allCoursesProvider.future);

      final allServiceRecords = await loadUddfServiceRecords(
        _ref.read(serviceRecordRepositoryProvider),
        equipment,
      );
      final relations = await _uddfDiveRelations(dives);

      state = state.copyWith(
        message: _l10n.settings_export_progress_chooseLocation,
      );
      final path = await _exportService.saveAllDataToUddfFile(
        dives: dives,
        sites: sites,
        equipment: equipment,
        buddies: buddies,
        certifications: certifications,
        diveCenters: diveCenters,
        species: species,
        diveBuddies: relations.diveBuddies,
        owner: currentDiver,
        trips: trips,
        tags: mergeById(
          mergeById(tags, siteClassification.siteTags, (tag) => tag.id),
          equipmentTags.tags,
          (tag) => tag.id,
        ),
        diveTags: relations.diveTags,
        customDiveTypes: customDiveTypes,
        customSiteTypes: customSiteTypes,
        siteTypeIdsBySite: siteClassification.typeIdsBySite,
        siteTagIdsBySite: siteClassification.tagIdsBySite,
        equipmentTagIdsByItem: equipmentTags.tagIdsByItem,
        customDiveRoles: customDiveRoles,
        diveComputers: diveComputers,
        equipmentSets: equipmentSets,
        components: components,
        serviceRecords: allServiceRecords,
        observations: await _diverObservations(),
        courses: courses,
        diveWeights: relations.diveWeights,
        diveGasSwitches: relations.diveGasSwitches,
        diveProfileEvents: relations.diveProfileEvents,
        diveTankPressures: relations.diveTankPressures,
        dataSources: await _ref.read(uddfSourceFetchProvider)(
          dives.map((d) => d.id).toList(growable: false),
          exportOptions,
        ),
        options: exportOptions,
      );

      if (path == null) {
        state = state.copyWith(
          status: ExportStatus.idle,
          message: _l10n.settings_export_cancelled_save,
        );
        return;
      }

      state = state.copyWith(
        status: ExportStatus.success,
        message: _l10n.settings_export_saved_uddf,
        filePath: path,
      );
    } catch (e) {
      state = state.copyWith(
        status: ExportStatus.error,
        message: _l10n.settings_export_saveFailed('$e'),
      );
    }
  }

  // ==================== PDF SAVE TO FILE ====================

  /// Save PDF logbook to a user-selected location.
  Future<void> savePdfToFile(PdfExportOptions options) async {
    state = state.copyWith(
      status: ExportStatus.exporting,
      message: _l10n.settings_export_progress_preparingPdf,
    );
    try {
      final dives = await _validatedDiverDives();
      if (dives.isEmpty) {
        state = state.copyWith(
          status: ExportStatus.error,
          message: _l10n.settings_export_empty_dives,
        );
        return;
      }

      // Build with the SAME template-aware path as the share flow, so the
      // selected detail level, page size, and diver personalization are
      // honored (#644: options were previously dropped here and the legacy
      // single-layout builder produced identical PDFs for every level).
      final pdfBytes = await _buildLogbookPdfBytes(options, dives);

      state = state.copyWith(
        message: _l10n.settings_export_progress_chooseLocation,
      );
      final fileName =
          'dive_logbook_${options.template.name}_${DateFormat('yyyy-MM-dd').format(DateTime.now())}.pdf';
      final path = await _exportService.savePdfBytesToFile(pdfBytes, fileName);

      if (path == null) {
        state = state.copyWith(
          status: ExportStatus.idle,
          message: _l10n.settings_export_cancelled_save,
        );
        return;
      }

      state = state.copyWith(
        status: ExportStatus.success,
        message: _l10n.settings_export_saved_pdf,
        filePath: path,
      );
    } catch (e) {
      state = state.copyWith(
        status: ExportStatus.error,
        message: _l10n.settings_export_saveFailed('$e'),
      );
    }
  }

  void reset() {
    state = const ExportState();
  }
}

final exportNotifierProvider =
    StateNotifierProvider<ExportNotifier, ExportState>((ref) {
      final exportService = ref.watch(exportServiceProvider);
      return ExportNotifier(exportService, ref);
    });
