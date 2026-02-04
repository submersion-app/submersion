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
import 'package:submersion/core/services/export_service.dart';
import 'package:submersion/core/services/pdf_templates/pdf_fonts.dart';
import 'package:submersion/core/services/pdf_templates/pdf_template_factory.dart';
import 'package:submersion/features/signatures/data/services/signature_storage_service.dart';
import 'package:submersion/features/signatures/domain/entities/signature.dart';
import 'package:submersion/core/services/location_service.dart';
import 'package:submersion/features/dive_log/domain/entities/dive.dart';
import 'package:submersion/features/dive_log/presentation/providers/dive_providers.dart';
import 'package:submersion/features/dive_log/presentation/providers/dive_computer_providers.dart';
import 'package:submersion/features/dive_sites/domain/entities/dive_site.dart';
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
import 'package:submersion/features/trips/domain/entities/trip.dart';
import 'package:submersion/features/dive_centers/domain/entities/dive_center.dart';
import 'package:submersion/features/certifications/domain/entities/certification.dart';
import 'package:submersion/features/equipment/domain/entities/equipment_item.dart';
import 'package:submersion/features/equipment/domain/entities/equipment_set.dart';
import 'package:submersion/features/dive_types/domain/entities/dive_type_entity.dart';

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

      // Fetch dive buddies and tags for each dive
      final buddyRepository = _ref.read(buddyRepositoryProvider);
      final tagRepository = _ref.read(tagRepositoryProvider);
      final Map<String, List<BuddyWithRole>> diveBuddies = {};
      final Map<String, List<Tag>> diveTags = {};
      for (final dive in dives) {
        final buddiesForDive = await buddyRepository.getBuddiesForDive(dive.id);
        if (buddiesForDive.isNotEmpty) {
          diveBuddies[dive.id] = buddiesForDive;
        }
        final tagsForDive = await tagRepository.getTagsForDive(dive.id);
        if (tagsForDive.isNotEmpty) {
          diveTags[dive.id] = tagsForDive;
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

  Future<void> importDivesFromUddf() async {
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
        allowedExtensions: useAnyType ? null : ['uddf', 'xml'],
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
      if (!['uddf', 'xml'].contains(extension)) {
        state = state.copyWith(
          status: ExportStatus.error,
          message: 'Please select a UDDF or XML file',
        );
        return;
      }

      final file = File(filePath);
      final uddfContent = await file.readAsString();

      state = state.copyWith(
        message: 'Parsing UDDF data...',
        importPhase: ImportPhase.parsing,
        currentItem: 0,
        totalItems: 0,
      );

      // Allow UI to update and show progress dialog before heavy parsing
      await Future<void>.delayed(const Duration(milliseconds: 50));

      // Use comprehensive import that parses all data types
      final importResult = await _exportService.importAllDataFromUddf(
        uddfContent,
      );

      const uuid = Uuid();
      final now = DateTime.now();

      // Track import counts for summary
      var tripsImported = 0;
      var equipmentImported = 0;
      var equipmentSetsImported = 0;
      var buddiesImported = 0;
      var diveCentersImported = 0;
      var certificationsImported = 0;
      var customDiveTypesImported = 0;
      var tagsImported = 0;
      var sitesImported = 0;
      var divesImported = 0;

      // Build ID mappings for cross-references
      final tripIdMapping = <String, String>{}; // UDDF trip ID -> new trip ID
      final equipmentIdMapping =
          <String, String>{}; // UDDF equipment ID -> new equipment ID
      final buddyIdMapping =
          <String, String>{}; // UDDF buddy ID -> new buddy ID
      final diveCenterIdMapping =
          <String, String>{}; // UDDF center ID -> new center ID
      final tagIdMapping = <String, String>{}; // UDDF tag ID -> new tag ID
      final siteIdMapping =
          <String, DiveSite>{}; // UDDF site ID -> new DiveSite

      // Helper to yield to UI thread periodically
      // Uses a small delay to ensure the UI actually has time to repaint
      Future<void> yieldToUI() async {
        await Future<void>.delayed(const Duration(milliseconds: 16));
      }

      // Track when we last yielded to avoid excessive delays
      var lastYieldTime = DateTime.now();
      const yieldInterval = Duration(milliseconds: 100);

      // Helper to yield if enough time has passed (for high-frequency updates)
      Future<void> maybeYieldToUI() async {
        final now = DateTime.now();
        if (now.difference(lastYieldTime) >= yieldInterval) {
          await yieldToUI();
          lastYieldTime = now;
        }
      }

      // 1. Import Trips
      if (importResult.trips.isNotEmpty) {
        state = state.copyWith(
          message: 'Importing trips...',
          importPhase: ImportPhase.trips,
          currentItem: 0,
          totalItems: importResult.trips.length,
        );
        await yieldToUI();
        final tripRepository = _ref.read(tripRepositoryProvider);

        for (final tripData in importResult.trips) {
          final tripName = tripData['name'] as String?;
          if (tripName == null || tripName.isEmpty) {
            state = state.copyWith(currentItem: state.currentItem + 1);
            continue;
          }

          final uddfId = tripData['uddfId'] as String?;
          final newId = uuid.v4();

          final trip = Trip(
            id: newId,
            diverId: currentDiver.id,
            name: tripName,
            startDate: tripData['startDate'] as DateTime? ?? now,
            endDate: tripData['endDate'] as DateTime? ?? now,
            location: tripData['location'] as String?,
            resortName: tripData['resortName'] as String?,
            liveaboardName: tripData['liveaboardName'] as String?,
            notes: tripData['notes'] as String? ?? '',
            createdAt: now,
            updatedAt: now,
          );

          await tripRepository.createTrip(trip);

          if (uddfId != null) {
            tripIdMapping[uddfId] = newId;
          }
          tripsImported++;
          state = state.copyWith(currentItem: state.currentItem + 1);
          await maybeYieldToUI();
        }
      }

      // 2. Import Equipment
      if (importResult.equipment.isNotEmpty) {
        state = state.copyWith(
          message: 'Importing equipment...',
          importPhase: ImportPhase.equipment,
          currentItem: 0,
          totalItems: importResult.equipment.length,
        );
        await yieldToUI();
        final equipmentRepository = _ref.read(equipmentRepositoryProvider);

        for (final equipData in importResult.equipment) {
          final equipName = equipData['name'] as String?;
          if (equipName == null || equipName.isEmpty) {
            state = state.copyWith(currentItem: state.currentItem + 1);
            continue;
          }

          final uddfId = equipData['uddfId'] as String?;
          final newId = uuid.v4();

          // Parse equipment type - may already be enum or string
          EquipmentType equipType;
          final typeValue = equipData['type'];
          if (typeValue is EquipmentType) {
            equipType = typeValue;
          } else if (typeValue is String) {
            equipType =
                _parseEnumValue(typeValue, EquipmentType.values) ??
                EquipmentType.other;
          } else {
            equipType = EquipmentType.other;
          }

          // Parse equipment status - may already be enum or string
          EquipmentStatus equipStatus;
          final statusValue = equipData['status'];
          if (statusValue is EquipmentStatus) {
            equipStatus = statusValue;
          } else if (statusValue is String) {
            equipStatus =
                _parseEnumValue(statusValue, EquipmentStatus.values) ??
                EquipmentStatus.active;
          } else {
            equipStatus = EquipmentStatus.active;
          }

          final item = EquipmentItem(
            id: newId,
            diverId: currentDiver.id,
            name: equipName,
            type: equipType,
            brand: equipData['brand'] as String?,
            model: equipData['model'] as String?,
            serialNumber: equipData['serialNumber'] as String?,
            size: equipData['size'] as String?,
            status: equipStatus,
            purchaseDate: equipData['purchaseDate'] as DateTime?,
            purchasePrice: equipData['purchasePrice'] as double?,
            purchaseCurrency: equipData['purchaseCurrency'] as String? ?? 'USD',
            lastServiceDate: equipData['lastServiceDate'] as DateTime?,
            serviceIntervalDays: equipData['serviceIntervalDays'] as int?,
            notes: equipData['notes'] as String? ?? '',
            isActive: equipData['isActive'] as bool? ?? true,
          );

          await equipmentRepository.createEquipment(item);

          if (uddfId != null) {
            equipmentIdMapping[uddfId] = newId;
          }
          equipmentImported++;
          state = state.copyWith(currentItem: state.currentItem + 1);
          await maybeYieldToUI();
        }
      }

      // 3. Import Buddies
      if (importResult.buddies.isNotEmpty) {
        state = state.copyWith(
          message: 'Importing buddies...',
          importPhase: ImportPhase.buddies,
          currentItem: 0,
          totalItems: importResult.buddies.length,
        );
        await yieldToUI();
        final buddyRepository = _ref.read(buddyRepositoryProvider);

        for (final buddyData in importResult.buddies) {
          final buddyName = buddyData['name'] as String?;
          if (buddyName == null || buddyName.isEmpty) {
            state = state.copyWith(currentItem: state.currentItem + 1);
            continue;
          }

          final uddfId = buddyData['uddfId'] as String?;
          final newId = uuid.v4();

          final buddy = Buddy(
            id: newId,
            diverId: currentDiver.id,
            name: buddyName,
            email: buddyData['email'] as String?,
            phone: buddyData['phone'] as String?,
            certificationLevel:
                buddyData['certificationLevel'] as CertificationLevel?,
            certificationAgency:
                buddyData['certificationAgency'] as CertificationAgency?,
            notes: buddyData['notes'] as String? ?? '',
            createdAt: now,
            updatedAt: now,
          );

          await buddyRepository.createBuddy(buddy);

          if (uddfId != null) {
            buddyIdMapping[uddfId] = newId;
          }
          buddiesImported++;
          state = state.copyWith(currentItem: state.currentItem + 1);
          await maybeYieldToUI();
        }
      }

      // 4. Import Dive Centers
      if (importResult.diveCenters.isNotEmpty) {
        state = state.copyWith(
          message: 'Importing dive centers...',
          importPhase: ImportPhase.diveCenters,
          currentItem: 0,
          totalItems: importResult.diveCenters.length,
        );
        await yieldToUI();
        final diveCenterRepository = _ref.read(diveCenterRepositoryProvider);

        for (final centerData in importResult.diveCenters) {
          final centerName = centerData['name'] as String?;
          if (centerName == null || centerName.isEmpty) {
            state = state.copyWith(currentItem: state.currentItem + 1);
            continue;
          }

          final uddfId = centerData['uddfId'] as String?;
          final newId = uuid.v4();

          // Parse affiliations - may already be List<String> or String
          List<String> affiliations = [];
          final affiliationsValue = centerData['affiliations'];
          if (affiliationsValue is List) {
            affiliations = affiliationsValue
                .cast<String>()
                .where((s) => s.isNotEmpty)
                .toList();
          } else if (affiliationsValue is String &&
              affiliationsValue.isNotEmpty) {
            affiliations = affiliationsValue
                .split(',')
                .map((s) => s.trim())
                .where((s) => s.isNotEmpty)
                .toList();
          }

          final center = DiveCenter(
            id: newId,
            diverId: currentDiver.id,
            name: centerName,
            city:
                centerData['location']
                    as String?, // Legacy UDDF uses location for city
            latitude: centerData['latitude'] as double?,
            longitude: centerData['longitude'] as double?,
            country: centerData['country'] as String?,
            phone: centerData['phone'] as String?,
            email: centerData['email'] as String?,
            website: centerData['website'] as String?,
            affiliations: affiliations,
            rating: centerData['rating'] as double?,
            notes: centerData['notes'] as String? ?? '',
            createdAt: now,
            updatedAt: now,
          );

          await diveCenterRepository.createDiveCenter(center);

          if (uddfId != null) {
            diveCenterIdMapping[uddfId] = newId;
          }
          diveCentersImported++;
          state = state.copyWith(currentItem: state.currentItem + 1);
          await maybeYieldToUI();
        }
      }

      // 5. Import Certifications
      if (importResult.certifications.isNotEmpty) {
        state = state.copyWith(
          message: 'Importing certifications...',
          importPhase: ImportPhase.certifications,
          currentItem: 0,
          totalItems: importResult.certifications.length,
        );
        await yieldToUI();
        final certificationRepository = _ref.read(
          certificationRepositoryProvider,
        );

        for (final certData in importResult.certifications) {
          final certName = certData['name'] as String?;
          if (certName == null || certName.isEmpty) {
            state = state.copyWith(currentItem: state.currentItem + 1);
            continue;
          }

          final newId = uuid.v4();

          // Parse agency - may already be enum or string
          CertificationAgency agency;
          final agencyValue = certData['agency'];
          if (agencyValue is CertificationAgency) {
            agency = agencyValue;
          } else if (agencyValue is String) {
            agency =
                _parseEnumValue(agencyValue, CertificationAgency.values) ??
                CertificationAgency.padi;
          } else {
            agency = CertificationAgency.padi;
          }

          // Parse level - may already be enum or string
          CertificationLevel? level;
          final levelValue = certData['level'];
          if (levelValue is CertificationLevel) {
            level = levelValue;
          } else if (levelValue is String) {
            level = _parseEnumValue(levelValue, CertificationLevel.values);
          }

          final certification = Certification(
            id: newId,
            diverId: currentDiver.id,
            name: certName,
            agency: agency,
            level: level,
            cardNumber: certData['cardNumber'] as String?,
            issueDate: certData['issueDate'] as DateTime?,
            expiryDate: certData['expiryDate'] as DateTime?,
            instructorName: certData['instructorName'] as String?,
            instructorNumber: certData['instructorNumber'] as String?,
            notes: certData['notes'] as String? ?? '',
            createdAt: now,
            updatedAt: now,
          );

          await certificationRepository.createCertification(certification);
          certificationsImported++;
          state = state.copyWith(currentItem: state.currentItem + 1);
          await maybeYieldToUI();
        }
      }

      // 6. Import Tags
      if (importResult.tags.isNotEmpty) {
        state = state.copyWith(
          message: 'Importing tags...',
          importPhase: ImportPhase.tags,
          currentItem: 0,
          totalItems: importResult.tags.length,
        );
        await yieldToUI();
        final tagRepository = _ref.read(tagRepositoryProvider);

        for (final tagData in importResult.tags) {
          final tagName = tagData['name'] as String?;
          if (tagName == null || tagName.isEmpty) {
            state = state.copyWith(currentItem: state.currentItem + 1);
            continue;
          }

          final uddfId = tagData['uddfId'] as String?;
          final newId = uuid.v4();

          final tag = Tag(
            id: newId,
            diverId: currentDiver.id,
            name: tagName,
            colorHex: tagData['color'] as String?,
            createdAt: now,
            updatedAt: now,
          );

          await tagRepository.createTag(tag);

          if (uddfId != null) {
            tagIdMapping[uddfId] = newId;
          }
          tagsImported++;
          state = state.copyWith(currentItem: state.currentItem + 1);
          await maybeYieldToUI();
        }
      }

      // 7. Import Custom Dive Types (only non-built-in types)
      if (importResult.customDiveTypes.isNotEmpty) {
        state = state.copyWith(
          message: 'Importing dive types...',
          importPhase: ImportPhase.diveTypes,
          currentItem: 0,
          totalItems: importResult.customDiveTypes.length,
        );
        await yieldToUI();
        final diveTypeRepository = _ref.read(diveTypeRepositoryProvider);

        for (final typeData in importResult.customDiveTypes) {
          final typeName = typeData['name'] as String?;
          final isBuiltIn = typeData['isBuiltIn'] as bool? ?? false;

          // Skip built-in types - they should already exist
          if (isBuiltIn || typeName == null || typeName.isEmpty) {
            state = state.copyWith(currentItem: state.currentItem + 1);
            continue;
          }

          final typeId =
              typeData['id'] as String? ??
              DiveTypeEntity.generateSlug(typeName);

          final diveType = DiveTypeEntity(
            id: typeId,
            diverId: currentDiver.id,
            name: typeName,
            isBuiltIn: false,
            sortOrder: typeData['sortOrder'] as int? ?? 100,
            createdAt: now,
            updatedAt: now,
          );

          try {
            await diveTypeRepository.createDiveType(diveType);
            customDiveTypesImported++;
          } catch (e) {
            // Ignore duplicates - dive type might already exist
          }
          state = state.copyWith(currentItem: state.currentItem + 1);
          await maybeYieldToUI();
        }
      }

      // 8. Import Dive Sites
      if (importResult.sites.isNotEmpty) {
        state = state.copyWith(
          message: 'Importing dive sites...',
          importPhase: ImportPhase.sites,
          currentItem: 0,
          totalItems: importResult.sites.length,
        );
        await yieldToUI();
        final siteNotifier = _ref.read(siteListNotifierProvider.notifier);

        for (final siteData in importResult.sites) {
          final siteName = siteData['name'] as String?;
          if (siteName == null || siteName.isEmpty) {
            state = state.copyWith(currentItem: state.currentItem + 1);
            continue;
          }

          final uddfId = siteData['uddfId'] as String?;
          final lat = siteData['latitude'] as double?;
          final lon = siteData['longitude'] as double?;

          // Get country/region from UDDF data
          String? country = siteData['country'] as String?;
          String? region = siteData['region'] as String?;

          // Auto-lookup country/region if coordinates exist but fields are empty
          if (lat != null &&
              lon != null &&
              (country == null || region == null)) {
            try {
              final geocodeResult = await LocationService.instance
                  .reverseGeocode(lat, lon);
              if (country == null && geocodeResult.country != null) {
                country = geocodeResult.country;
              }
              if (region == null && geocodeResult.region != null) {
                region = geocodeResult.region;
              }
            } catch (e) {
              // Geocoding is best-effort, don't block import on failure
            }
          }

          final newSite = DiveSite(
            id: uuid.v4(),
            diverId: currentDiver.id,
            name: siteName,
            description: siteData['description'] as String? ?? '',
            location: (lat != null && lon != null) ? GeoPoint(lat, lon) : null,
            maxDepth: siteData['maxDepth'] as double?,
            country: country,
            region: region,
            rating: siteData['rating'] as double?,
            notes: siteData['notes'] as String? ?? '',
          );

          final createdSite = await siteNotifier.addSite(newSite);

          if (uddfId != null) {
            siteIdMapping[uddfId] = createdSite;
          }
          sitesImported++;
          state = state.copyWith(currentItem: state.currentItem + 1);
          await maybeYieldToUI();
        }
      }

      // 9. Import Equipment Sets (after equipment, so we can map IDs)
      if (importResult.equipmentSets.isNotEmpty) {
        state = state.copyWith(
          message: 'Importing equipment sets...',
          importPhase: ImportPhase.equipmentSets,
          currentItem: 0,
          totalItems: importResult.equipmentSets.length,
        );
        await yieldToUI();
        final equipmentSetRepository = _ref.read(
          equipmentSetRepositoryProvider,
        );

        for (final setData in importResult.equipmentSets) {
          final setName = setData['name'] as String?;
          if (setName == null || setName.isEmpty) {
            state = state.copyWith(currentItem: state.currentItem + 1);
            continue;
          }

          final newId = uuid.v4();

          // Map equipment item references to new IDs
          // Parser stores as 'equipmentRefs' with values like 'equip_<uuid>'
          final itemRefsValue = setData['equipmentRefs'];
          final itemRefs = itemRefsValue is List
              ? itemRefsValue.whereType<String>().toList()
              : <String>[];
          final mappedItemIds = <String>[];
          for (final oldRef in itemRefs) {
            final newItemId = equipmentIdMapping[oldRef];
            if (newItemId != null) {
              mappedItemIds.add(newItemId);
            }
          }

          final equipmentSet = EquipmentSet(
            id: newId,
            diverId: currentDiver.id,
            name: setName,
            description: setData['description'] as String? ?? '',
            equipmentIds: mappedItemIds,
            createdAt: now,
            updatedAt: now,
          );

          await equipmentSetRepository.createSet(equipmentSet);
          equipmentSetsImported++;
          state = state.copyWith(currentItem: state.currentItem + 1);
          await maybeYieldToUI();
        }
      }

      // 10. Import Dives (after sites, trips, buddies, dive centers so we can link them)
      if (importResult.dives.isNotEmpty) {
        state = state.copyWith(
          message: 'Importing dives...',
          importPhase: ImportPhase.dives,
          currentItem: 0,
          totalItems: importResult.dives.length,
        );
        await yieldToUI();
        final diveNotifier = _ref.read(diveListNotifierProvider.notifier);
        final buddyRepository = _ref.read(buddyRepositoryProvider);
        final tagRepository = _ref.read(tagRepositoryProvider);
        final diveCenterRepository = _ref.read(diveCenterRepositoryProvider);
        final equipmentRepository = _ref.read(equipmentRepositoryProvider);

        for (var i = 0; i < importResult.dives.length; i++) {
          final diveData = importResult.dives[i];
          // Build profile points if present
          final profileData =
              diveData['profile'] as List<Map<String, dynamic>>?;
          final profile =
              profileData
                  ?.map(
                    (p) => DiveProfilePoint(
                      timestamp: p['timestamp'] as int? ?? 0,
                      depth: p['depth'] as double? ?? 0.0,
                      temperature: p['temperature'] as double?,
                      pressure: p['pressure'] as double?,
                    ),
                  )
                  .toList() ??
              [];

          // Build tanks from parsed tank data
          List<DiveTank> tanks = [];
          final tanksData = diveData['tanks'] as List<Map<String, dynamic>>?;
          if (tanksData != null && tanksData.isNotEmpty) {
            tanks = tanksData.map((t) {
              // Parse material - may be enum or string
              TankMaterial? material;
              final materialValue = t['material'];
              if (materialValue is TankMaterial) {
                material = materialValue;
              } else if (materialValue is String) {
                material = _parseEnumValue(materialValue, TankMaterial.values);
              }

              // Parse role - may be enum or string
              TankRole role;
              final roleValue = t['role'];
              if (roleValue is TankRole) {
                role = roleValue;
              } else if (roleValue is String) {
                role =
                    _parseEnumValue(roleValue, TankRole.values) ??
                    TankRole.backGas;
              } else {
                role = TankRole.backGas;
              }

              return DiveTank(
                id: uuid.v4(),
                volume: t['volume'] as double?,
                startPressure: t['startPressure'] as int?,
                endPressure: t['endPressure'] as int?,
                workingPressure: t['workingPressure'] as int?,
                gasMix: t['gasMix'] as GasMix? ?? const GasMix(),
                material: material,
                role: role,
                order: t['order'] as int? ?? 0,
              );
            }).toList();
          } else {
            // Fall back to gas mix from samples
            final gasMix = diveData['gasMix'] as GasMix?;
            if (gasMix != null) {
              tanks = [DiveTank(id: uuid.v4(), gasMix: gasMix)];
            }
          }

          // Link to imported site
          DiveSite? linkedSite;
          final siteDataMap = diveData['site'] as Map<String, dynamic>?;
          if (siteDataMap != null) {
            final uddfSiteId = siteDataMap['uddfId'] as String?;
            if (uddfSiteId != null && siteIdMapping.containsKey(uddfSiteId)) {
              linkedSite = siteIdMapping[uddfSiteId];
            }
          }

          // Link to imported trip
          String? linkedTripId;
          final tripRef = diveData['tripRef'] as String?;
          if (tripRef != null && tripIdMapping.containsKey(tripRef)) {
            linkedTripId = tripIdMapping[tripRef];
          }

          // Link to imported dive center
          DiveCenter? linkedDiveCenter;
          final diveCenterRef = diveData['diveCenterRef'] as String?;
          if (diveCenterRef != null &&
              diveCenterIdMapping.containsKey(diveCenterRef)) {
            final newCenterId = diveCenterIdMapping[diveCenterRef]!;
            linkedDiveCenter = await diveCenterRepository.getDiveCenterById(
              newCenterId,
            );
          }

          // Link to imported equipment
          final linkedEquipment = <EquipmentItem>[];
          final equipmentRefsRaw = diveData['equipmentRefs'];
          if (equipmentRefsRaw != null) {
            final equipmentRefs = equipmentRefsRaw is List
                ? equipmentRefsRaw.whereType<String>().toList()
                : <String>[];
            for (final oldRef in equipmentRefs) {
              final newEquipmentId = equipmentIdMapping[oldRef];
              if (newEquipmentId != null) {
                final equipment = await equipmentRepository.getEquipmentById(
                  newEquipmentId,
                );
                if (equipment != null) {
                  linkedEquipment.add(equipment);
                }
              }
            }
          }

          // Parse dive type
          final diveTypeId = diveData['diveType'] as String? ?? 'recreational';

          // Include weight used in notes if available
          var notes = diveData['notes'] as String? ?? '';
          final weightUsed = diveData['weightUsed'] as double?;
          if (weightUsed != null && weightUsed > 0) {
            if (notes.isNotEmpty) notes += '\n';
            notes += 'Weight used: ${weightUsed.toStringAsFixed(1)} kg';
          }

          final diveId = uuid.v4();
          final dateTime = diveData['dateTime'] as DateTime? ?? now;
          final runtime = diveData['runtime'] as Duration?;
          final entryTime = dateTime;
          final exitTime = runtime != null ? dateTime.add(runtime) : null;

          // Parse marine life sightings
          final sightingsData =
              diveData['sightings'] as List<Map<String, dynamic>>?;
          final sightings = <MarineSighting>[];
          if (sightingsData != null) {
            for (final sightingData in sightingsData) {
              final speciesRef = sightingData['speciesRef'] as String?;
              if (speciesRef != null && speciesRef.isNotEmpty) {
                // Extract species name from ref (e.g., 'species_green_sea_turtle' -> 'Green Sea Turtle')
                String speciesName = speciesRef;
                if (speciesRef.startsWith('species_')) {
                  speciesName = speciesRef
                      .substring(8) // Remove 'species_' prefix
                      .split('_')
                      .map(
                        (word) => word.isNotEmpty
                            ? word[0].toUpperCase() + word.substring(1)
                            : word,
                      )
                      .join(' ');
                }
                sightings.add(
                  MarineSighting(
                    id: uuid.v4(),
                    speciesId: speciesRef,
                    speciesName: speciesName,
                    count: sightingData['count'] as int? ?? 1,
                    notes: sightingData['notes'] as String? ?? '',
                  ),
                );
              }
            }
          }

          // Create initial dive object assigned to the current diver
          var dive = Dive(
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
            buddy: diveData['buddy'] as String?,
            diveMaster: diveData['diveMaster'] as String?,
            rating: diveData['rating'] as int?,
            notes: notes,
            visibility: diveData['visibility'] as Visibility?,
            diveTypeId: diveTypeId,
            profile: profile,
            tanks: tanks,
            site: linkedSite,
            tripId: linkedTripId,
            diveCenter: linkedDiveCenter,
            equipment: linkedEquipment,
            sightings: sightings,
            // Dive condition fields
            currentDirection: diveData['currentDirection'] as CurrentDirection?,
            currentStrength: diveData['currentStrength'] as CurrentStrength?,
            swellHeight: diveData['swellHeight'] as double?,
            entryMethod: diveData['entryMethod'] as EntryMethod?,
            exitMethod: diveData['exitMethod'] as EntryMethod?,
            waterType: diveData['waterType'] as WaterType?,
            altitude: diveData['altitude'] as double?,
          );

          // Auto-calculate bottom time from profile if not set and profile exists
          if (dive.duration == null && dive.profile.isNotEmpty) {
            final calculatedDuration = dive.calculateBottomTimeFromProfile();
            if (calculatedDuration != null) {
              dive = dive.copyWith(duration: calculatedDuration);
            }
          }

          await diveNotifier.addDive(dive);

          // Store per-tank pressure data if profile has pressure information
          if (profileData != null && tanks.isNotEmpty) {
            final tankPressureRepo = _ref.read(tankPressureRepositoryProvider);
            final pressuresByTank =
                <String, List<({int timestamp, double pressure})>>{};

            for (final p in profileData) {
              final timestamp = p['timestamp'] as int? ?? 0;

              // Check for multi-tank pressure data first (new format)
              final allTankPressures =
                  p['allTankPressures'] as List<Map<String, dynamic>>?;
              if (allTankPressures != null && allTankPressures.isNotEmpty) {
                // Process all tank pressures from this waypoint
                for (final tp in allTankPressures) {
                  final pressure = tp['pressure'] as double?;
                  final tankIdx = tp['tankIndex'] as int? ?? 0;
                  if (pressure != null &&
                      tankIdx >= 0 &&
                      tankIdx < tanks.length) {
                    final tankId = tanks[tankIdx].id;
                    pressuresByTank.putIfAbsent(tankId, () => []).add((
                      timestamp: timestamp,
                      pressure: pressure,
                    ));
                  }
                }
              } else {
                // Fall back to legacy single pressure field
                final pressure = p['pressure'] as double?;
                // Default to tank 0 if no tankIndex is specified
                final tankIdx = (p['tankIndex'] as int?) ?? 0;

                if (pressure != null &&
                    tankIdx >= 0 &&
                    tankIdx < tanks.length) {
                  final tankId = tanks[tankIdx].id;
                  pressuresByTank.putIfAbsent(tankId, () => []).add((
                    timestamp: timestamp,
                    pressure: pressure,
                  ));
                }
              }
            }

            if (pressuresByTank.isNotEmpty) {
              await tankPressureRepo.insertTankPressures(
                diveId,
                pressuresByTank,
              );
            }
          }

          // Link buddies to the dive
          final buddyRefsValue = diveData['buddyRefs'];
          final buddyRefs = buddyRefsValue is List
              ? buddyRefsValue.whereType<String>().toList()
              : <String>[];
          for (final buddyRef in buddyRefs) {
            final newBuddyId = buddyIdMapping[buddyRef];
            if (newBuddyId != null) {
              await buddyRepository.addBuddyToDive(
                diveId,
                newBuddyId,
                BuddyRole.buddy,
              );
            }
          }

          // Handle inline buddy names that weren't in the diver section
          // Create buddy entities for them and link to dive
          final unmatchedNamesValue = diveData['unmatchedBuddyNames'];
          final unmatchedNames = unmatchedNamesValue is List
              ? unmatchedNamesValue.whereType<String>().toList()
              : <String>[];
          for (final buddyName in unmatchedNames) {
            // Use findOrCreateByName to either find existing or create new buddy
            final buddy = await buddyRepository.findOrCreateByName(buddyName);
            await buddyRepository.addBuddyToDive(
              diveId,
              buddy.id,
              BuddyRole.buddy,
            );
            buddiesImported++;
          }

          // Link tags to the dive
          final tagRefsValue = diveData['tagRefs'];
          final tagRefs = tagRefsValue is List
              ? tagRefsValue.whereType<String>().toList()
              : <String>[];
          for (final tagRef in tagRefs) {
            final newTagId = tagIdMapping[tagRef];
            if (newTagId != null) {
              await tagRepository.addTagToDive(diveId, newTagId);
            }
          }

          divesImported++;
          state = state.copyWith(currentItem: state.currentItem + 1);
          await maybeYieldToUI();
        }
      }

      // Set complete phase
      state = state.copyWith(
        importPhase: ImportPhase.complete,
        message: 'Finalizing...',
      );

      // Invalidate all relevant providers to refresh data
      _ref.invalidate(sitesProvider);
      _ref.invalidate(sitesWithCountsProvider);
      _ref.invalidate(siteListNotifierProvider);
      _ref.invalidate(allBuddiesProvider);
      _ref.invalidate(allEquipmentProvider);
      _ref.invalidate(activeEquipmentProvider);
      _ref.invalidate(retiredEquipmentProvider);
      _ref.invalidate(serviceDueEquipmentProvider);
      // Invalidate all equipment status filters including "All" (null)
      _ref.invalidate(equipmentByStatusProvider(null));
      for (final status in EquipmentStatus.values) {
        _ref.invalidate(equipmentByStatusProvider(status));
      }
      _ref.invalidate(equipmentListNotifierProvider);
      _ref.invalidate(equipmentSetsProvider);
      _ref.invalidate(allTripsProvider);
      _ref.invalidate(allDiveCentersProvider);
      _ref.invalidate(allCertificationsProvider);
      _ref.invalidate(diveTypesProvider);
      _ref.invalidate(tagsProvider);
      _ref.invalidate(diveListNotifierProvider);

      // Build summary message
      final parts = <String>[];
      if (divesImported > 0) parts.add('$divesImported dives');
      if (sitesImported > 0) parts.add('$sitesImported sites');
      if (tripsImported > 0) parts.add('$tripsImported trips');
      if (equipmentImported > 0) parts.add('$equipmentImported equipment');
      if (equipmentSetsImported > 0) {
        parts.add('$equipmentSetsImported equipment sets');
      }
      if (buddiesImported > 0) parts.add('$buddiesImported buddies');
      if (diveCentersImported > 0) {
        parts.add('$diveCentersImported dive centers');
      }
      if (certificationsImported > 0) {
        parts.add('$certificationsImported certifications');
      }
      if (customDiveTypesImported > 0) {
        parts.add('$customDiveTypesImported custom dive types');
      }
      if (tagsImported > 0) parts.add('$tagsImported tags');

      final summary = parts.isEmpty
          ? 'No data imported'
          : 'Imported ${parts.join(', ')}';

      state = state.copyWith(status: ExportStatus.success, message: summary);
    } catch (e) {
      state = state.copyWith(
        status: ExportStatus.error,
        message: 'Import failed: $e',
      );
    }
  }

  /// Parse an enum value from a string
  T? _parseEnumValue<T extends Enum>(String value, List<T> values) {
    final lowerValue = value.toLowerCase();
    for (final enumValue in values) {
      if (enumValue.name.toLowerCase() == lowerValue) {
        return enumValue;
      }
    }
    return null;
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
