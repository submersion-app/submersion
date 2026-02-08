import 'dart:io';

import 'package:file_picker/file_picker.dart';
import 'package:submersion/core/providers/provider.dart';
import 'package:intl/intl.dart';
import 'package:path_provider/path_provider.dart';
import 'package:uuid/uuid.dart';

import 'package:submersion/core/constants/enums.dart';
import 'package:submersion/features/settings/presentation/providers/settings_providers.dart';
import 'package:submersion/core/constants/pdf_templates.dart';
import 'package:submersion/core/services/database_service.dart';
import 'package:submersion/core/services/export/export_service.dart';
import 'package:submersion/core/services/pdf_templates/pdf_fonts.dart';
import 'package:submersion/core/services/pdf_templates/pdf_template_factory.dart';
import 'package:submersion/features/signatures/data/services/signature_storage_service.dart';
import 'package:submersion/features/signatures/domain/entities/signature.dart';
import 'package:submersion/features/dive_log/domain/entities/dive.dart';
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
import 'package:submersion/features/certifications/domain/entities/certification.dart';
import 'package:submersion/features/courses/presentation/providers/course_providers.dart';
import 'package:submersion/features/dive_log/domain/entities/dive_weight.dart';
import 'package:submersion/features/dive_log/domain/entities/gas_switch.dart';
import 'package:submersion/features/dive_log/domain/entities/profile_event.dart';

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

  Future<void> exportDivesToCsv() async {
    state = state.copyWith(
      status: ExportStatus.exporting,
      message: 'Exporting dives to CSV...',
    );
    try {
      final dives = _ref.read(diveListNotifierProvider).value ?? [];
      if (dives.isEmpty) {
        state = state.copyWith(
          status: ExportStatus.error,
          message: 'No dives to export',
        );
        return;
      }
      final path = await _exportService.exportDivesToCsv(dives);
      state = state.copyWith(
        status: ExportStatus.success,
        message: 'Dives exported successfully',
        filePath: path,
      );
    } catch (e) {
      state = state.copyWith(
        status: ExportStatus.error,
        message: 'Export failed: $e',
      );
    }
  }

  Future<void> exportSitesToCsv() async {
    state = state.copyWith(
      status: ExportStatus.exporting,
      message: 'Exporting sites to CSV...',
    );
    try {
      final sites = _ref.read(sitesProvider).value ?? [];
      if (sites.isEmpty) {
        state = state.copyWith(
          status: ExportStatus.error,
          message: 'No sites to export',
        );
        return;
      }
      final path = await _exportService.exportSitesToCsv(sites);
      state = state.copyWith(
        status: ExportStatus.success,
        message: 'Sites exported successfully',
        filePath: path,
      );
    } catch (e) {
      state = state.copyWith(
        status: ExportStatus.error,
        message: 'Export failed: $e',
      );
    }
  }

  Future<void> exportEquipmentToCsv() async {
    state = state.copyWith(
      status: ExportStatus.exporting,
      message: 'Exporting equipment to CSV...',
    );
    try {
      final equipment = _ref.read(allEquipmentProvider).value ?? [];
      if (equipment.isEmpty) {
        state = state.copyWith(
          status: ExportStatus.error,
          message: 'No equipment to export',
        );
        return;
      }
      final path = await _exportService.exportEquipmentToCsv(equipment);
      state = state.copyWith(
        status: ExportStatus.success,
        message: 'Equipment exported successfully',
        filePath: path,
      );
    } catch (e) {
      state = state.copyWith(
        status: ExportStatus.error,
        message: 'Export failed: $e',
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
      message: 'Generating PDF logbook...',
    );
    try {
      final dives = _ref.read(diveListNotifierProvider).value ?? [];
      if (dives.isEmpty) {
        state = state.copyWith(
          status: ExportStatus.error,
          message: 'No dives to export',
        );
        return;
      }

      // Load signatures for all dives
      state = state.copyWith(message: 'Loading signatures...');
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
        state = state.copyWith(message: 'Loading certifications...');
        certifications = await _ref.read(allCertificationsProvider.future);
      }

      // Get current diver for personalization
      final diver = await _ref.read(currentDiverProvider.future);

      // Initialize fonts for proper Unicode support
      state = state.copyWith(message: 'Loading fonts...');
      await PdfFonts.instance.initialize();

      // Get the appropriate template builder
      state = state.copyWith(
        message: 'Generating ${exportOptions.template.displayName} PDF...',
      );
      final factory = PdfTemplateFactory();
      final builder = factory.getBuilder(exportOptions.template);

      // Build the PDF
      final pdfBytes = await builder.buildPdf(
        dives: dives,
        pageSize: exportOptions.pageSize,
        title: 'Dive Logbook',
        diveSignatures: diveSignatures.isNotEmpty ? diveSignatures : null,
        certifications: certifications,
        diver: diver,
      );

      // Save and share the PDF
      final path = await _exportService.sharePdfBytes(
        pdfBytes,
        'dive_logbook_${exportOptions.template.name}_${DateFormat('yyyy-MM-dd').format(DateTime.now())}.pdf',
      );

      state = state.copyWith(
        status: ExportStatus.success,
        message: 'PDF logbook generated successfully',
        filePath: path,
      );
    } catch (e) {
      state = state.copyWith(
        status: ExportStatus.error,
        message: 'Export failed: $e',
      );
    }
  }

  Future<void> exportDivesToUddf() async {
    state = state.copyWith(
      status: ExportStatus.exporting,
      message: 'Generating UDDF file...',
    );
    try {
      final dives = _ref.read(diveListNotifierProvider).value ?? [];
      if (dives.isEmpty) {
        state = state.copyWith(
          status: ExportStatus.error,
          message: 'No dives to export',
        );
        return;
      }

      // Collect all data for comprehensive export
      state = state.copyWith(message: 'Collecting all data...');
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
              serviceType: r.serviceType,
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
              .map(
                (row) => ProfileEvent(
                  id: row.id,
                  diveId: row.diveId,
                  timestamp: row.timestamp,
                  eventType: ProfileEventType.values.firstWhere(
                    (e) => e.name == row.eventType,
                    orElse: () => ProfileEventType.note,
                  ),
                  severity: EventSeverity.values.firstWhere(
                    (e) => e.name == row.severity,
                    orElse: () => EventSeverity.info,
                  ),
                  description: row.description,
                  depth: row.depth,
                  value: row.value,
                  tankId: row.tankId,
                  createdAt: DateTime.fromMillisecondsSinceEpoch(
                    row.createdAt * 1000,
                  ),
                ),
              )
              .toList();
        }
      }

      state = state.copyWith(message: 'Generating UDDF file...');
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
        diveComputers: diveComputers,
        equipmentSets: equipmentSets,
        serviceRecords: allServiceRecords,
        courses: courses,
        diveWeights: diveWeights,
        diveGasSwitches: diveGasSwitches,
        diveProfileEvents: diveProfileEvents,
      );
      state = state.copyWith(
        status: ExportStatus.success,
        message: 'UDDF file generated successfully',
        filePath: path,
      );
    } catch (e) {
      state = state.copyWith(
        status: ExportStatus.error,
        message: 'Export failed: $e',
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
      message: 'Generating Excel file...',
    );
    try {
      final dives = _ref.read(diveListNotifierProvider).value ?? [];
      final sites = await _ref.read(sitesProvider.future);
      final equipment = await _ref.read(allEquipmentProvider.future);

      if (dives.isEmpty && sites.isEmpty && equipment.isEmpty) {
        state = state.copyWith(
          status: ExportStatus.error,
          message: 'No data to export',
        );
        return;
      }

      // Get user's unit preferences
      final settings = _ref.read(settingsProvider);

      state = state.copyWith(message: 'Building Excel workbook...');
      final path = await _exportService.exportToExcel(
        dives: dives,
        sites: sites,
        equipment: equipment,
        depthUnit: settings.depthUnit,
        temperatureUnit: settings.temperatureUnit,
        pressureUnit: settings.pressureUnit,
        volumeUnit: settings.volumeUnit,
        dateFormat: settings.dateFormat,
      );

      state = state.copyWith(
        status: ExportStatus.success,
        message: 'Excel file exported successfully',
        filePath: path,
      );
    } catch (e) {
      state = state.copyWith(
        status: ExportStatus.error,
        message: 'Export failed: $e',
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
      message: 'Generating KML file...',
    );
    try {
      final sites = await _ref.read(sitesProvider.future);
      final dives = _ref.read(diveListNotifierProvider).value ?? [];

      if (sites.isEmpty) {
        state = state.copyWith(
          status: ExportStatus.error,
          message: 'No dive sites to export',
        );
        return;
      }

      // Get user's unit preferences
      final settings = _ref.read(settingsProvider);

      state = state.copyWith(message: 'Building KML file...');
      final (path, skippedCount) = await _exportService.exportToKml(
        sites: sites,
        dives: dives,
        depthUnit: settings.depthUnit,
        dateFormat: settings.dateFormat,
      );

      final skippedMsg = skippedCount > 0
          ? ' ($skippedCount sites without coordinates skipped)'
          : '';
      state = state.copyWith(
        status: ExportStatus.success,
        message: 'KML file exported successfully$skippedMsg',
        filePath: path,
      );
    } catch (e) {
      state = state.copyWith(
        status: ExportStatus.error,
        message: 'Export failed: $e',
      );
    }
  }

  /// Save Excel file to a user-selected location.
  ///
  /// Opens a file picker dialog allowing the user to choose where to save.
  Future<void> saveExcelToFile() async {
    state = state.copyWith(
      status: ExportStatus.exporting,
      message: 'Preparing Excel file...',
    );
    try {
      final dives = _ref.read(diveListNotifierProvider).value ?? [];
      final sites = await _ref.read(sitesProvider.future);
      final equipment = await _ref.read(allEquipmentProvider.future);

      if (dives.isEmpty && sites.isEmpty && equipment.isEmpty) {
        state = state.copyWith(
          status: ExportStatus.error,
          message: 'No data to export',
        );
        return;
      }

      // Get user's unit preferences
      final settings = _ref.read(settingsProvider);

      state = state.copyWith(message: 'Choose save location...');
      final path = await _exportService.saveExcelToFile(
        dives: dives,
        sites: sites,
        equipment: equipment,
        depthUnit: settings.depthUnit,
        temperatureUnit: settings.temperatureUnit,
        pressureUnit: settings.pressureUnit,
        volumeUnit: settings.volumeUnit,
        dateFormat: settings.dateFormat,
      );

      if (path == null) {
        state = state.copyWith(
          status: ExportStatus.idle,
          message: 'Save cancelled',
        );
        return;
      }

      state = state.copyWith(
        status: ExportStatus.success,
        message: 'Excel file saved successfully',
        filePath: path,
      );
    } catch (e) {
      state = state.copyWith(
        status: ExportStatus.error,
        message: 'Save failed: $e',
      );
    }
  }

  /// Save KML file to a user-selected location.
  ///
  /// Opens a file picker dialog allowing the user to choose where to save.
  Future<void> saveKmlToFile() async {
    state = state.copyWith(
      status: ExportStatus.exporting,
      message: 'Preparing KML file...',
    );
    try {
      final sites = await _ref.read(sitesProvider.future);
      final dives = _ref.read(diveListNotifierProvider).value ?? [];

      if (sites.isEmpty) {
        state = state.copyWith(
          status: ExportStatus.error,
          message: 'No dive sites to export',
        );
        return;
      }

      // Get user's unit preferences
      final settings = _ref.read(settingsProvider);

      state = state.copyWith(message: 'Choose save location...');
      final (path, skippedCount) = await _exportService.saveKmlToFile(
        sites: sites,
        dives: dives,
        depthUnit: settings.depthUnit,
        dateFormat: settings.dateFormat,
      );

      if (path == null) {
        state = state.copyWith(
          status: ExportStatus.idle,
          message: 'Save cancelled',
        );
        return;
      }

      final skippedMsg = skippedCount > 0
          ? ' ($skippedCount sites without coordinates skipped)'
          : '';
      state = state.copyWith(
        status: ExportStatus.success,
        message: 'KML file saved successfully$skippedMsg',
        filePath: path,
      );
    } catch (e) {
      state = state.copyWith(
        status: ExportStatus.error,
        message: 'Save failed: $e',
      );
    }
  }

  // ==================== CSV SAVE TO FILE ====================

  /// Save dives CSV to a user-selected location.
  Future<void> saveDivesCsvToFile() async {
    state = state.copyWith(
      status: ExportStatus.exporting,
      message: 'Preparing dives CSV...',
    );
    try {
      final dives = _ref.read(diveListNotifierProvider).value ?? [];
      if (dives.isEmpty) {
        state = state.copyWith(
          status: ExportStatus.error,
          message: 'No dives to export',
        );
        return;
      }

      state = state.copyWith(message: 'Choose save location...');
      final path = await _exportService.saveDivesCsvToFile(dives);

      if (path == null) {
        state = state.copyWith(
          status: ExportStatus.idle,
          message: 'Save cancelled',
        );
        return;
      }

      state = state.copyWith(
        status: ExportStatus.success,
        message: 'Dives CSV saved successfully',
        filePath: path,
      );
    } catch (e) {
      state = state.copyWith(
        status: ExportStatus.error,
        message: 'Save failed: $e',
      );
    }
  }

  /// Save sites CSV to a user-selected location.
  Future<void> saveSitesCsvToFile() async {
    state = state.copyWith(
      status: ExportStatus.exporting,
      message: 'Preparing sites CSV...',
    );
    try {
      final sites = _ref.read(sitesProvider).value ?? [];
      if (sites.isEmpty) {
        state = state.copyWith(
          status: ExportStatus.error,
          message: 'No sites to export',
        );
        return;
      }

      state = state.copyWith(message: 'Choose save location...');
      final path = await _exportService.saveSitesCsvToFile(sites);

      if (path == null) {
        state = state.copyWith(
          status: ExportStatus.idle,
          message: 'Save cancelled',
        );
        return;
      }

      state = state.copyWith(
        status: ExportStatus.success,
        message: 'Sites CSV saved successfully',
        filePath: path,
      );
    } catch (e) {
      state = state.copyWith(
        status: ExportStatus.error,
        message: 'Save failed: $e',
      );
    }
  }

  /// Save equipment CSV to a user-selected location.
  Future<void> saveEquipmentCsvToFile() async {
    state = state.copyWith(
      status: ExportStatus.exporting,
      message: 'Preparing equipment CSV...',
    );
    try {
      final equipment = _ref.read(allEquipmentProvider).value ?? [];
      if (equipment.isEmpty) {
        state = state.copyWith(
          status: ExportStatus.error,
          message: 'No equipment to export',
        );
        return;
      }

      state = state.copyWith(message: 'Choose save location...');
      final path = await _exportService.saveEquipmentCsvToFile(equipment);

      if (path == null) {
        state = state.copyWith(
          status: ExportStatus.idle,
          message: 'Save cancelled',
        );
        return;
      }

      state = state.copyWith(
        status: ExportStatus.success,
        message: 'Equipment CSV saved successfully',
        filePath: path,
      );
    } catch (e) {
      state = state.copyWith(
        status: ExportStatus.error,
        message: 'Save failed: $e',
      );
    }
  }

  // ==================== UDDF SAVE TO FILE ====================

  /// Save UDDF to a user-selected location.
  Future<void> saveUddfToFile() async {
    state = state.copyWith(
      status: ExportStatus.exporting,
      message: 'Preparing UDDF file...',
    );
    try {
      final dives = _ref.read(diveListNotifierProvider).value ?? [];
      if (dives.isEmpty) {
        state = state.copyWith(
          status: ExportStatus.error,
          message: 'No dives to export',
        );
        return;
      }

      final sites = await _ref.read(sitesProvider.future);

      state = state.copyWith(message: 'Choose save location...');
      final path = await _exportService.saveUddfToFile(dives, sites: sites);

      if (path == null) {
        state = state.copyWith(
          status: ExportStatus.idle,
          message: 'Save cancelled',
        );
        return;
      }

      state = state.copyWith(
        status: ExportStatus.success,
        message: 'UDDF file saved successfully',
        filePath: path,
      );
    } catch (e) {
      state = state.copyWith(
        status: ExportStatus.error,
        message: 'Save failed: $e',
      );
    }
  }

  // ==================== PDF SAVE TO FILE ====================

  /// Save PDF logbook to a user-selected location.
  Future<void> savePdfToFile(PdfExportOptions options) async {
    state = state.copyWith(
      status: ExportStatus.exporting,
      message: 'Preparing PDF...',
    );
    try {
      final dives = _ref.read(diveListNotifierProvider).value ?? [];
      if (dives.isEmpty) {
        state = state.copyWith(
          status: ExportStatus.error,
          message: 'No dives to export',
        );
        return;
      }

      state = state.copyWith(message: 'Choose save location...');
      final path = await _exportService.saveDivesToPdfFile(
        dives,
        title: 'Dive Logbook',
      );

      if (path == null) {
        state = state.copyWith(
          status: ExportStatus.idle,
          message: 'Save cancelled',
        );
        return;
      }

      state = state.copyWith(
        status: ExportStatus.success,
        message: 'PDF saved successfully',
        filePath: path,
      );
    } catch (e) {
      state = state.copyWith(
        status: ExportStatus.error,
        message: 'Save failed: $e',
      );
    }
  }

  void reset() {
    state = const ExportState();
  }

  Future<void> importDivesFromCsv() async {
    state = state.copyWith(
      status: ExportStatus.exporting,
      message: 'Checking diver profile...',
    );
    try {
      // Verify an active diver profile exists before importing
      final currentDiver = await _ref.read(currentDiverProvider.future);
      if (currentDiver == null) {
        state = state.copyWith(
          status: ExportStatus.error,
          message: 'Please create a diver profile before importing dives',
        );
        return;
      }

      state = state.copyWith(message: 'Selecting file...');
      // Use FileType.any on iOS/macOS since custom extensions don't work reliably
      final useAnyType = Platform.isIOS || Platform.isMacOS;
      final result = await FilePicker.platform.pickFiles(
        type: useAnyType ? FileType.any : FileType.custom,
        allowedExtensions: useAnyType ? null : ['csv'],
        allowMultiple: false,
      );

      if (result == null || result.files.isEmpty) {
        state = state.copyWith(
          status: ExportStatus.idle,
          message: 'Import cancelled',
        );
        return;
      }

      state = state.copyWith(message: 'Reading file...');
      final filePath = result.files.first.path;
      if (filePath == null) {
        state = state.copyWith(
          status: ExportStatus.error,
          message: 'Could not access file',
        );
        return;
      }

      // On iOS/macOS, verify file extension manually
      final extension = filePath.split('.').last.toLowerCase();
      if (extension != 'csv') {
        state = state.copyWith(
          status: ExportStatus.error,
          message: 'Please select a CSV file',
        );
        return;
      }

      final file = File(filePath);
      final csvContent = await file.readAsString();

      state = state.copyWith(message: 'Parsing CSV data...');
      final parsedDives = await _exportService.importDivesFromCsv(csvContent);

      if (parsedDives.isEmpty) {
        state = state.copyWith(
          status: ExportStatus.error,
          message: 'No dives found in CSV file',
        );
        return;
      }

      state = state.copyWith(
        message: 'Importing ${parsedDives.length} dives...',
      );
      const uuid = Uuid();
      final diveNotifier = _ref.read(diveListNotifierProvider.notifier);

      var importedCount = 0;
      var buddiesCreated = 0;
      for (final diveData in parsedDives) {
        // Parse legacy buddy/divemaster text fields into proper Buddy entities
        final buddyText = diveData['buddy'] as String?;
        final diveMasterText = diveData['diveMaster'] as String?;
        final buddies = await _parseBuddiesFromLegacyText(
          buddyText: buddyText,
          diveMasterText: diveMasterText,
        );

        final diveId = uuid.v4();
        final dateTime = diveData['dateTime'] as DateTime? ?? DateTime.now();
        final runtime = diveData['runtime'] as Duration?;
        // Entry time is the dive start time, exit time is calculated from runtime
        final entryTime = dateTime;
        final exitTime = runtime != null ? dateTime.add(runtime) : null;

        final dive = Dive(
          id: diveId,
          diverId: currentDiver.id,
          diveNumber: diveData['diveNumber'] as int?,
          dateTime: dateTime,
          entryTime: entryTime,
          exitTime: exitTime,
          duration: diveData['duration'] as Duration?,
          runtime: runtime,
          maxDepth: diveData['maxDepth'] as double?,
          avgDepth: diveData['avgDepth'] as double?,
          waterTemp: diveData['waterTemp'] as double?,
          airTemp: diveData['airTemp'] as double?,
          surfacePressure: diveData['surfacePressure'] as double?,
          surfaceInterval: diveData['surfaceInterval'] as Duration?,
          gradientFactorLow: diveData['gradientFactorLow'] as int?,
          gradientFactorHigh: diveData['gradientFactorHigh'] as int?,
          diveComputerModel: diveData['diveComputerModel'] as String?,
          diveComputerSerial: diveData['diveComputerSerial'] as String?,
          // Keep legacy text for backwards compatibility display, but also link proper buddies
          buddy: buddyText,
          diveMaster: diveMasterText,
          rating: diveData['rating'] as int?,
          notes: diveData['notes'] as String? ?? '',
          visibility: diveData['visibility'] as Visibility?,
          diveTypeId: diveData['diveType'] as String? ?? 'recreational',
          tanks: _buildTanks(diveData, uuid),
          // Dive condition fields
          currentDirection: diveData['currentDirection'] as CurrentDirection?,
          currentStrength: diveData['currentStrength'] as CurrentStrength?,
          swellHeight: diveData['swellHeight'] as double?,
          entryMethod: diveData['entryMethod'] as EntryMethod?,
          exitMethod: diveData['exitMethod'] as EntryMethod?,
          waterType: diveData['waterType'] as WaterType?,
          altitude: diveData['altitude'] as double?,
        );

        await diveNotifier.addDive(dive);

        // Link buddy entities to the dive
        if (buddies.isNotEmpty) {
          await _linkBuddiesToDive(diveId, buddies);
          buddiesCreated += buddies.length;
        }

        importedCount++;
      }

      // Refresh buddies provider
      _ref.invalidate(allBuddiesProvider);

      final buddyMessage = buddiesCreated > 0
          ? ' and $buddiesCreated buddy associations'
          : '';
      state = state.copyWith(
        status: ExportStatus.success,
        message: 'Successfully imported $importedCount dives$buddyMessage',
      );
    } catch (e) {
      state = state.copyWith(
        status: ExportStatus.error,
        message: 'Import failed: $e',
      );
    }
  }

  List<DiveTank> _buildTanks(Map<String, dynamic> diveData, Uuid uuid) {
    final startPressure = diveData['startPressure'] as int?;
    final endPressure = diveData['endPressure'] as int?;
    final tankVolume = diveData['tankVolume'] as double?;
    final o2Percent = diveData['o2Percent'] as double?;

    if (startPressure == null && endPressure == null && tankVolume == null) {
      return [];
    }

    return [
      DiveTank(
        id: uuid.v4(),
        startPressure: startPressure,
        endPressure: endPressure,
        volume: tankVolume,
        gasMix: o2Percent != null ? GasMix(o2: o2Percent) : const GasMix(),
      ),
    ];
  }

  /// Parse plaintext buddy/divemaster/guide names and convert them to proper Buddy entities
  /// Returns a list of BuddyWithRole to be linked to the dive after creation
  Future<List<BuddyWithRole>> _parseBuddiesFromLegacyText({
    String? buddyText,
    String? diveMasterText,
  }) async {
    final buddyRepository = _ref.read(buddyRepositoryProvider);
    final result = <BuddyWithRole>[];

    // Parse buddy field - may contain multiple names separated by comma
    if (buddyText != null && buddyText.trim().isNotEmpty) {
      // Split by comma, semicolon, or " and "
      final names = buddyText
          .split(RegExp(r'[,;]|\s+and\s+', caseSensitive: false))
          .map((n) => n.trim())
          .where((n) => n.isNotEmpty)
          .toList();

      for (final name in names) {
        final buddy = await buddyRepository.findOrCreateByName(name);
        result.add(BuddyWithRole(buddy: buddy, role: BuddyRole.buddy));
      }
    }

    // Parse divemaster/guide field
    if (diveMasterText != null && diveMasterText.trim().isNotEmpty) {
      // Check if already added as buddy (avoid duplicates)
      final existingNames = result
          .map((b) => b.buddy.name.toLowerCase())
          .toSet();

      final names = diveMasterText
          .split(RegExp(r'[,;]|\s+and\s+', caseSensitive: false))
          .map((n) => n.trim())
          .where(
            (n) => n.isNotEmpty && !existingNames.contains(n.toLowerCase()),
          )
          .toList();

      for (final name in names) {
        final buddy = await buddyRepository.findOrCreateByName(name);
        // Try to determine role from name or default to diveGuide
        final lowerName = name.toLowerCase();
        BuddyRole role;
        if (lowerName.contains('instructor')) {
          role = BuddyRole.instructor;
        } else if (lowerName.contains('divemaster') ||
            lowerName.contains('dm')) {
          role = BuddyRole.diveMaster;
        } else {
          role = BuddyRole.diveGuide;
        }
        result.add(BuddyWithRole(buddy: buddy, role: role));
      }
    }

    return result;
  }

  /// Link buddies to a dive after the dive has been created
  Future<void> _linkBuddiesToDive(
    String diveId,
    List<BuddyWithRole> buddies,
  ) async {
    if (buddies.isEmpty) return;

    final buddyRepository = _ref.read(buddyRepositoryProvider);
    for (final buddyWithRole in buddies) {
      await buddyRepository.addBuddyToDive(
        diveId,
        buddyWithRole.buddy.id,
        buddyWithRole.role,
      );
    }
  }

  Future<void> createBackup() async {
    state = state.copyWith(
      status: ExportStatus.exporting,
      message: 'Creating backup...',
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
      final savePath = await FilePicker.platform.saveFile(
        dialogTitle: 'Save Backup',
        fileName: fileName,
        type: FileType.any,
        bytes: await File(tempBackupPath).readAsBytes(),
      );

      if (savePath == null) {
        // User cancelled - clean up temp file
        await File(tempBackupPath).delete();
        state = state.copyWith(
          status: ExportStatus.idle,
          message: 'Backup cancelled',
        );
        return;
      }

      // On non-Android platforms, FilePicker doesn't write the bytes automatically
      if (!Platform.isAndroid) {
        await File(
          savePath,
        ).writeAsBytes(await File(tempBackupPath).readAsBytes());
      }

      // Clean up temporary file
      await File(tempBackupPath).delete();

      state = state.copyWith(
        status: ExportStatus.success,
        message: 'Backup saved successfully',
        filePath: savePath,
      );
    } catch (e) {
      state = state.copyWith(
        status: ExportStatus.error,
        message: 'Backup failed: $e',
      );
    }
  }

  Future<void> restoreBackup() async {
    state = state.copyWith(
      status: ExportStatus.exporting,
      message: 'Selecting backup file...',
    );
    try {
      // Use FileType.any on iOS/macOS since custom extensions don't work reliably
      final useAnyType = Platform.isIOS || Platform.isMacOS;
      final result = await FilePicker.platform.pickFiles(
        type: useAnyType ? FileType.any : FileType.custom,
        allowedExtensions: useAnyType ? null : ['db'],
        allowMultiple: false,
      );

      if (result == null || result.files.isEmpty) {
        state = state.copyWith(
          status: ExportStatus.idle,
          message: 'Restore cancelled',
        );
        return;
      }

      final filePath = result.files.first.path;
      if (filePath == null) {
        state = state.copyWith(
          status: ExportStatus.error,
          message: 'Could not access file',
        );
        return;
      }

      // On iOS/macOS, verify file extension manually
      final extension = filePath.split('.').last.toLowerCase();
      if (extension != 'db') {
        state = state.copyWith(
          status: ExportStatus.error,
          message: 'Please select a .db backup file',
        );
        return;
      }

      state = state.copyWith(message: 'Restoring from backup...');
      await DatabaseService.instance.restore(filePath);

      // Invalidate all providers to refresh data
      _ref.invalidate(diveListNotifierProvider);
      _ref.invalidate(sitesProvider);
      _ref.invalidate(sitesWithCountsProvider);
      _ref.invalidate(siteListNotifierProvider);
      _ref.invalidate(allEquipmentProvider);

      state = state.copyWith(
        status: ExportStatus.success,
        message: 'Backup restored successfully. Please restart the app.',
      );
    } catch (e) {
      state = state.copyWith(
        status: ExportStatus.error,
        message: 'Restore failed: $e',
      );
    }
  }
}

final exportNotifierProvider =
    StateNotifierProvider<ExportNotifier, ExportState>((ref) {
      final exportService = ref.watch(exportServiceProvider);
      return ExportNotifier(exportService, ref);
    });
