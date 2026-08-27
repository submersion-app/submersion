import 'dart:io';

import 'package:file_picker/file_picker.dart';
import 'package:submersion/core/providers/provider.dart';
import 'package:intl/intl.dart';
import 'package:path_provider/path_provider.dart';
import 'package:submersion/features/settings/presentation/providers/settings_providers.dart';
import 'package:submersion/core/constants/pdf_templates.dart';
import 'package:submersion/core/services/database_service.dart';
import 'package:submersion/core/services/export/excel/maintenance_excel_export_service.dart';
import 'package:submersion/core/services/export/export_service.dart';
import 'package:submersion/core/services/pdf_templates/pdf_date_formatter.dart';
import 'package:submersion/core/services/pdf_templates/pdf_fonts.dart';
import 'package:submersion/core/services/pdf_templates/pdf_template_factory.dart';
import 'package:submersion/features/signatures/data/services/signature_storage_service.dart';
import 'package:submersion/features/signatures/domain/entities/signature.dart';
import 'package:submersion/features/dive_log/presentation/providers/dive_providers.dart';
import 'package:submersion/features/dive_log/presentation/providers/dive_computer_providers.dart';
import 'package:submersion/features/dive_sites/presentation/providers/site_providers.dart';
import 'package:submersion/features/equipment/presentation/providers/equipment_providers.dart';
import 'package:submersion/features/equipment/presentation/providers/equipment_set_providers.dart';
import 'package:submersion/features/buddies/presentation/providers/buddy_providers.dart';
import 'package:submersion/features/buddies/domain/entities/buddy.dart';
import 'package:submersion/features/certifications/presentation/providers/certification_providers.dart';
import 'package:submersion/features/tags/domain/entities/tag.dart';
import 'package:submersion/features/dive_centers/presentation/providers/dive_center_providers.dart';
import 'package:submersion/features/divers/presentation/providers/diver_providers.dart';
import 'package:submersion/features/marine_life/presentation/providers/species_providers.dart';
import 'package:submersion/features/trips/presentation/providers/trip_providers.dart';
import 'package:submersion/features/tags/presentation/providers/tag_providers.dart';
import 'package:submersion/features/dive_types/presentation/providers/dive_type_providers.dart';
import 'package:submersion/features/dive_roles/presentation/providers/dive_role_providers.dart';
import 'package:submersion/features/certifications/domain/entities/certification.dart';
import 'package:submersion/features/courses/presentation/providers/course_providers.dart';
import 'package:submersion/features/dive_log/domain/entities/dive.dart'
    show Dive, TankPressurePoint;
import 'package:submersion/features/dive_log/domain/entities/dive_weight.dart';
import 'package:submersion/features/dive_log/domain/entities/gas_switch.dart';
import 'package:submersion/features/dive_log/domain/entities/profile_event.dart';
import 'package:submersion/features/dive_log/domain/services/profile_event_mapper.dart';
import 'package:submersion/features/dive_log/data/repositories/tank_pressure_repository.dart';
import 'package:submersion/features/pre_dive/presentation/providers/pre_dive_providers.dart';
import 'package:submersion/core/services/export/shared/file_export_utils.dart';
import 'package:submersion/l10n/arb/app_localizations.dart';
import 'package:submersion/l10n/l10n_extension.dart';

/// Load per-tank pressure data for a list of dives.
///
/// Returns a map keyed by dive ID, where each value is a map of
/// tank ID to pressure point list.
Future<Map<String, Map<String, List<TankPressurePoint>>>>
loadTankPressuresForDives(
  TankPressureRepository repository,
  List<Dive> dives,
) async {
  final result = <String, Map<String, List<TankPressurePoint>>>{};
  for (final dive in dives) {
    final pressures = await repository.getTankPressuresForDive(dive.id);
    if (pressures.isNotEmpty) {
      result[dive.id] = pressures;
    }
  }
  return result;
}

/// Export service provider
final exportServiceProvider = Provider<ExportService>((ref) {
  return ExportService();
});

/// Export state for tracking export operations
enum ExportStatus { idle, exporting, success, restoreComplete, error }

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

  /// Localizations for the status messages this notifier publishes.
  ///
  /// A provider has no BuildContext, so the persisted locale setting is
  /// resolved through the same helper SyncNotifier uses. Read (not cached) so
  /// a locale change is picked up by the next operation.
  AppLocalizations get _l10n => l10nForLocaleTag(_ref.read(localeProvider));

  Future<void> exportDivesToCsv() async {
    state = state.copyWith(
      status: ExportStatus.exporting,
      message: _l10n.settings_export_progress_divesCsv,
    );
    try {
      final dives = await _ref.read(divesProvider.future);
      if (dives.isEmpty) {
        state = state.copyWith(
          status: ExportStatus.error,
          message: _l10n.settings_export_empty_dives,
        );
        return;
      }
      final path = await _exportService.exportDivesToCsv(dives);
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

  Future<void> exportSitesToCsv() async {
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
      final path = await _exportService.exportSitesToCsv(sites);
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

  Future<void> exportEquipmentToCsv() async {
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
      final path = await _exportService.exportEquipmentToCsv(equipment);
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
      final dives = await _ref.read(divesProvider.future);
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
    final signatureService = SignatureStorageService();
    final diveSignatures = <String, List<Signature>>{};
    for (final dive in dives) {
      final sigs = await signatureService.getAllSignaturesForDive(dive.id);
      if (sigs.isNotEmpty) {
        diveSignatures[dive.id] = sigs;
      }
    }

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

    return builder.buildPdf(
      dives: dives,
      pageSize: exportOptions.pageSize,
      dates: PdfDateFormatter(
        dateFormat: settings.dateFormat,
        timeFormat: settings.timeFormat,
      ),
      title: _l10n.settings_export_pdfDocumentTitle,
      diveSignatures: diveSignatures.isNotEmpty ? diveSignatures : null,
      certifications: certifications,
      diver: diver,
    );
  }

  Future<void> exportDivesToUddf() async {
    state = state.copyWith(
      status: ExportStatus.exporting,
      message: _l10n.settings_export_progress_uddf,
    );
    try {
      final dives = await _ref.read(divesProvider.future);
      if (dives.isEmpty) {
        state = state.copyWith(
          status: ExportStatus.error,
          message: _l10n.settings_export_empty_dives,
        );
        return;
      }

      // Collect all data for comprehensive export
      state = state.copyWith(
        message: _l10n.settings_export_progress_collectingData,
      );
      final sites = await _ref.read(sitesProvider.future);
      final equipment = await _ref.read(allEquipmentProvider.future);
      final buddies = await _ref.read(allBuddiesProvider.future);
      final certifications = await _ref.read(allCertificationsProvider.future);
      final diveCenters = await _ref.read(allDiveCentersProvider.future);
      final species = await _ref.read(allSpeciesProvider.future);

      // Collect new comprehensive data
      final currentDiver = await _ref.read(currentDiverProvider.future);
      final trips = await _ref.read(allTripsProvider.future);
      final tags = await _ref.read(tagsProvider.future);
      final customDiveTypes = await _ref.read(diveTypesProvider.future);
      final customDiveRoles = (await _ref.read(
        allDiveRolesProvider.future,
      )).where((r) => !r.isBuiltIn).toList();
      final diveComputers = await _ref.read(allDiveComputersProvider.future);
      final equipmentSets = await _ref.read(equipmentSetsProvider.future);

      // Fetch courses
      final courses = await _ref.read(allCoursesProvider.future);

      // Fetch service records for all equipment, mapping domain to export DTO
      final serviceRecordRepo = _ref.read(serviceRecordRepositoryProvider);
      final List<ServiceRecord> allServiceRecords = [];
      for (final item in equipment) {
        final records = await serviceRecordRepo.getRecordsForEquipment(item.id);
        allServiceRecords.addAll(
          records.map(
            (r) => ServiceRecord(
              id: r.id,
              equipmentId: r.equipmentId,
              serviceCategory: r.serviceCategory,
              serviceDate: r.serviceDate,
              provider: r.provider,
              cost: r.cost,
              currency: r.currency,
              nextServiceDue: r.nextServiceDue,
              notes: r.notes,
            ),
          ),
        );
      }

      // Fetch dive buddies, tags, gas switches, and profile events per dive
      final buddyRepository = _ref.read(buddyRepositoryProvider);
      final tagRepository = _ref.read(tagRepositoryProvider);
      final diveRepository = _ref.read(diveRepositoryProvider);
      final diveComputerRepository = _ref.read(diveComputerRepositoryProvider);
      final Map<String, List<BuddyWithRole>> diveBuddies = {};
      final Map<String, List<Tag>> diveTags = {};
      final Map<String, List<DiveWeight>> diveWeights = {};
      final Map<String, List<GasSwitchWithTank>> diveGasSwitches = {};
      final Map<String, List<ProfileEvent>> diveProfileEvents = {};
      for (final dive in dives) {
        final buddiesForDive = await buddyRepository.getBuddiesForDive(dive.id);
        if (buddiesForDive.isNotEmpty) {
          diveBuddies[dive.id] = buddiesForDive;
        }
        final tagsForDive = await tagRepository.getTagsForDive(dive.id);
        if (tagsForDive.isNotEmpty) {
          diveTags[dive.id] = tagsForDive;
        }
        // Weights are already loaded on Dive entities
        if (dive.weights.isNotEmpty) {
          diveWeights[dive.id] = dive.weights;
        }
        // Gas switches per dive
        final switches = await diveRepository.getGasSwitchesForDive(dive.id);
        if (switches.isNotEmpty) {
          diveGasSwitches[dive.id] = switches;
        }
        // Profile events per dive (map Drift row to domain entity)
        final eventRows = await diveComputerRepository.getEventsForDive(
          dive.id,
        );
        if (eventRows.isNotEmpty) {
          diveProfileEvents[dive.id] = eventRows
              .map(mapDiveProfileEventToProfileEvent)
              .toList();
        }
      }

      // Load per-tank pressure data for each dive
      final diveTankPressures = await loadTankPressuresForDives(
        _ref.read(tankPressureRepositoryProvider),
        dives,
      );

      state = state.copyWith(message: _l10n.settings_export_progress_uddf);
      final path = await _exportService.exportAllDataToUddf(
        dives: dives,
        sites: sites,
        equipment: equipment,
        buddies: buddies,
        certifications: certifications,
        diveCenters: diveCenters,
        species: species,
        diveBuddies: diveBuddies,
        owner: currentDiver,
        trips: trips,
        tags: tags,
        diveTags: diveTags,
        customDiveTypes: customDiveTypes,
        customDiveRoles: customDiveRoles,
        diveComputers: diveComputers,
        equipmentSets: equipmentSets,
        serviceRecords: allServiceRecords,
        courses: courses,
        diveWeights: diveWeights,
        diveGasSwitches: diveGasSwitches,
        diveProfileEvents: diveProfileEvents,
        diveTankPressures: diveTankPressures,
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
      final dives = await _ref.read(divesProvider.future);
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
        depthUnit: settings.depthUnit,
        temperatureUnit: settings.temperatureUnit,
        pressureUnit: settings.pressureUnit,
        volumeUnit: settings.volumeUnit,
        dateFormat: settings.dateFormat,
        preDiveSessions: preDiveSessions,
        preDiveItemsBySession: preDiveItems,
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
      final dives = await _ref.read(divesProvider.future);
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
        depthUnit: settings.depthUnit,
        temperatureUnit: settings.temperatureUnit,
        pressureUnit: settings.pressureUnit,
        volumeUnit: settings.volumeUnit,
        dateFormat: settings.dateFormat,
        preDiveSessions: preDiveSessions,
        preDiveItemsBySession: preDiveItems,
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
    final repository = _ref.read(serviceRecordRepositoryProvider);

    final rows = <MaintenanceLogRow>[];
    for (final item in equipment) {
      final records = await repository.getRecordsForEquipment(item.id);
      for (final record in records) {
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
  Future<void> saveDivesCsvToFile() async {
    state = state.copyWith(
      status: ExportStatus.exporting,
      message: _l10n.settings_export_progress_preparingDivesCsv,
    );
    try {
      final dives = await _ref.read(divesProvider.future);
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
      final path = await _exportService.saveDivesCsvToFile(dives);

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
  Future<void> saveSitesCsvToFile() async {
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
      final path = await _exportService.saveSitesCsvToFile(sites);

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
  Future<void> saveEquipmentCsvToFile() async {
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
      final path = await _exportService.saveEquipmentCsvToFile(equipment);

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
  Future<void> saveUddfToFile() async {
    state = state.copyWith(
      status: ExportStatus.exporting,
      message: _l10n.settings_export_progress_preparingUddf,
    );
    try {
      final dives = await _ref.read(divesProvider.future);
      if (dives.isEmpty) {
        state = state.copyWith(
          status: ExportStatus.error,
          message: _l10n.settings_export_empty_dives,
        );
        return;
      }

      // Collect all data for comprehensive export
      state = state.copyWith(
        message: _l10n.settings_export_progress_collectingData,
      );
      final sites = await _ref.read(sitesProvider.future);
      final equipment = await _ref.read(allEquipmentProvider.future);
      final buddies = await _ref.read(allBuddiesProvider.future);
      final certifications = await _ref.read(allCertificationsProvider.future);
      final diveCenters = await _ref.read(allDiveCentersProvider.future);
      final species = await _ref.read(allSpeciesProvider.future);
      final currentDiver = await _ref.read(currentDiverProvider.future);
      final trips = await _ref.read(allTripsProvider.future);
      final tags = await _ref.read(tagsProvider.future);
      final customDiveTypes = await _ref.read(diveTypesProvider.future);
      final customDiveRoles = (await _ref.read(
        allDiveRolesProvider.future,
      )).where((r) => !r.isBuiltIn).toList();
      final diveComputers = await _ref.read(allDiveComputersProvider.future);
      final equipmentSets = await _ref.read(equipmentSetsProvider.future);
      final courses = await _ref.read(allCoursesProvider.future);

      // Fetch service records for all equipment
      final serviceRecordRepo = _ref.read(serviceRecordRepositoryProvider);
      final List<ServiceRecord> allServiceRecords = [];
      for (final item in equipment) {
        final records = await serviceRecordRepo.getRecordsForEquipment(item.id);
        allServiceRecords.addAll(
          records.map(
            (r) => ServiceRecord(
              id: r.id,
              equipmentId: r.equipmentId,
              serviceCategory: r.serviceCategory,
              serviceDate: r.serviceDate,
              provider: r.provider,
              cost: r.cost,
              currency: r.currency,
              nextServiceDue: r.nextServiceDue,
              notes: r.notes,
            ),
          ),
        );
      }

      // Fetch per-dive relationships
      final buddyRepository = _ref.read(buddyRepositoryProvider);
      final tagRepository = _ref.read(tagRepositoryProvider);
      final diveRepository = _ref.read(diveRepositoryProvider);
      final diveComputerRepository = _ref.read(diveComputerRepositoryProvider);
      final Map<String, List<BuddyWithRole>> diveBuddies = {};
      final Map<String, List<Tag>> diveTags = {};
      final Map<String, List<DiveWeight>> diveWeights = {};
      final Map<String, List<GasSwitchWithTank>> diveGasSwitches = {};
      final Map<String, List<ProfileEvent>> diveProfileEvents = {};
      for (final dive in dives) {
        final buddiesForDive = await buddyRepository.getBuddiesForDive(dive.id);
        if (buddiesForDive.isNotEmpty) {
          diveBuddies[dive.id] = buddiesForDive;
        }
        final tagsForDive = await tagRepository.getTagsForDive(dive.id);
        if (tagsForDive.isNotEmpty) {
          diveTags[dive.id] = tagsForDive;
        }
        if (dive.weights.isNotEmpty) {
          diveWeights[dive.id] = dive.weights;
        }
        final switches = await diveRepository.getGasSwitchesForDive(dive.id);
        if (switches.isNotEmpty) {
          diveGasSwitches[dive.id] = switches;
        }
        final eventRows = await diveComputerRepository.getEventsForDive(
          dive.id,
        );
        if (eventRows.isNotEmpty) {
          diveProfileEvents[dive.id] = eventRows
              .map(mapDiveProfileEventToProfileEvent)
              .toList();
        }
      }

      // Load per-tank pressure data for each dive
      final diveTankPressures = await loadTankPressuresForDives(
        _ref.read(tankPressureRepositoryProvider),
        dives,
      );

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
        diveBuddies: diveBuddies,
        owner: currentDiver,
        trips: trips,
        tags: tags,
        diveTags: diveTags,
        customDiveTypes: customDiveTypes,
        customDiveRoles: customDiveRoles,
        diveComputers: diveComputers,
        equipmentSets: equipmentSets,
        serviceRecords: allServiceRecords,
        courses: courses,
        diveWeights: diveWeights,
        diveGasSwitches: diveGasSwitches,
        diveProfileEvents: diveProfileEvents,
        diveTankPressures: diveTankPressures,
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
      final dives = await _ref.read(divesProvider.future);
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

  Future<void> createBackup() async {
    state = state.copyWith(
      status: ExportStatus.exporting,
      message: _l10n.backup_backingUp,
    );
    try {
      final dateFormat = DateFormat('yyyy-MM-dd_HHmmss');
      final timestamp = dateFormat.format(DateTime.now());
      final fileName = 'submersion_backup_$timestamp.db';

      // Create temporary backup first
      final directory = await getApplicationDocumentsDirectory();
      final tempBackupPath = '${directory.path}/$fileName';
      await DatabaseService.instance.backup(tempBackupPath);

      // Let user choose where to save the file
      final savePath = await FilePicker.saveFile(
        dialogTitle: _l10n.settings_export_saveBackupDialogTitle,
        fileName: fileName,
        type: FileType.any,
        bytes: await File(tempBackupPath).readAsBytes(),
        mimeType: 'application/vnd.sqlite3',
      );

      if (savePath == null) {
        // User cancelled - clean up temp file
        await File(tempBackupPath).delete();
        state = state.copyWith(
          status: ExportStatus.idle,
          message: _l10n.settings_export_cancelled_backup,
        );
        return;
      }

      // file_picker 12 writes the bytes itself on every platform, so the
      // former non-Android manual write is gone.
      await File(tempBackupPath).delete();

      state = state.copyWith(
        status: ExportStatus.success,
        message: _l10n.settings_export_saved_backup,
        filePath: savedFileLocation(savePath),
      );
    } catch (e) {
      state = state.copyWith(
        status: ExportStatus.error,
        message: _l10n.settings_export_backupFailed('$e'),
      );
    }
  }

  Future<void> restoreBackup() async {
    state = state.copyWith(
      status: ExportStatus.exporting,
      message: _l10n.settings_export_progress_selectingBackup,
    );
    try {
      // Use FileType.any on iOS/macOS since custom extensions don't work reliably
      final useAnyType = Platform.isIOS || Platform.isMacOS;
      final picked = await FilePicker.pickFile(
        type: useAnyType ? FileType.any : FileType.custom,
        allowedExtensions: useAnyType ? null : ['db'],
      );

      if (picked == null) {
        state = state.copyWith(
          status: ExportStatus.idle,
          message: _l10n.settings_export_cancelled_restore,
        );
        return;
      }

      final filePath = picked.path;
      if (filePath == null) {
        state = state.copyWith(
          status: ExportStatus.error,
          message: _l10n.settings_export_fileUnreadable,
        );
        return;
      }

      // On iOS/macOS, verify file extension manually
      final extension = filePath.split('.').last.toLowerCase();
      if (extension != 'db') {
        state = state.copyWith(
          status: ExportStatus.error,
          message: _l10n.settings_export_notADbFile,
        );
        return;
      }

      state = state.copyWith(
        message: _l10n.settings_export_progress_restoringBackup,
      );
      await DatabaseService.instance.restore(filePath);

      state = state.copyWith(
        status: ExportStatus.restoreComplete,
        message: _l10n.settings_export_restoreComplete,
      );
    } catch (e) {
      state = state.copyWith(
        status: ExportStatus.error,
        message: _l10n.settings_export_restoreFailed('$e'),
      );
    }
  }
}

final exportNotifierProvider =
    StateNotifierProvider<ExportNotifier, ExportState>((ref) {
      final exportService = ref.watch(exportServiceProvider);
      return ExportNotifier(exportService, ref);
    });
