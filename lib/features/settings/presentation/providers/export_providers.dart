import 'dart:io';

import 'package:file_picker/file_picker.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';
import 'package:uuid/uuid.dart';

import '../../../../core/constants/enums.dart';
import '../../../../core/services/database_service.dart';
import '../../../../core/services/export_service.dart';
import '../../../dive_log/domain/entities/dive.dart';
import '../../../dive_log/presentation/providers/dive_providers.dart';
import '../../../dive_sites/domain/entities/dive_site.dart';
import '../../../dive_sites/presentation/providers/site_providers.dart';
import '../../../equipment/presentation/providers/equipment_providers.dart';
import '../../../buddies/presentation/providers/buddy_providers.dart';
import '../../../buddies/domain/entities/buddy.dart';
import '../../../certifications/presentation/providers/certification_providers.dart';
import '../../../dive_centers/presentation/providers/dive_center_providers.dart';
import '../../../marine_life/presentation/providers/species_providers.dart';

/// Export service provider
final exportServiceProvider = Provider<ExportService>((ref) {
  return ExportService();
});

/// Export state for tracking export operations
enum ExportStatus { idle, exporting, success, error }

class ExportState {
  final ExportStatus status;
  final String? message;
  final String? filePath;

  const ExportState({
    this.status = ExportStatus.idle,
    this.message,
    this.filePath,
  });

  ExportState copyWith({
    ExportStatus? status,
    String? message,
    String? filePath,
  }) {
    return ExportState(
      status: status ?? this.status,
      message: message ?? this.message,
      filePath: filePath ?? this.filePath,
    );
  }
}

/// Export notifier for managing export operations
class ExportNotifier extends StateNotifier<ExportState> {
  final ExportService _exportService;
  final Ref _ref;

  ExportNotifier(this._exportService, this._ref) : super(const ExportState());

  Future<void> exportDivesToCsv() async {
    state = state.copyWith(status: ExportStatus.exporting, message: 'Exporting dives to CSV...');
    try {
      final dives = _ref.read(diveListNotifierProvider).value ?? [];
      if (dives.isEmpty) {
        state = state.copyWith(status: ExportStatus.error, message: 'No dives to export');
        return;
      }
      final path = await _exportService.exportDivesToCsv(dives);
      state = state.copyWith(status: ExportStatus.success, message: 'Dives exported successfully', filePath: path);
    } catch (e) {
      state = state.copyWith(status: ExportStatus.error, message: 'Export failed: $e');
    }
  }

  Future<void> exportSitesToCsv() async {
    state = state.copyWith(status: ExportStatus.exporting, message: 'Exporting sites to CSV...');
    try {
      final sites = _ref.read(sitesProvider).value ?? [];
      if (sites.isEmpty) {
        state = state.copyWith(status: ExportStatus.error, message: 'No sites to export');
        return;
      }
      final path = await _exportService.exportSitesToCsv(sites);
      state = state.copyWith(status: ExportStatus.success, message: 'Sites exported successfully', filePath: path);
    } catch (e) {
      state = state.copyWith(status: ExportStatus.error, message: 'Export failed: $e');
    }
  }

  Future<void> exportEquipmentToCsv() async {
    state = state.copyWith(status: ExportStatus.exporting, message: 'Exporting equipment to CSV...');
    try {
      final equipment = _ref.read(allEquipmentProvider).value ?? [];
      if (equipment.isEmpty) {
        state = state.copyWith(status: ExportStatus.error, message: 'No equipment to export');
        return;
      }
      final path = await _exportService.exportEquipmentToCsv(equipment);
      state = state.copyWith(status: ExportStatus.success, message: 'Equipment exported successfully', filePath: path);
    } catch (e) {
      state = state.copyWith(status: ExportStatus.error, message: 'Export failed: $e');
    }
  }

  Future<void> exportDivesToPdf() async {
    state = state.copyWith(status: ExportStatus.exporting, message: 'Generating PDF logbook...');
    try {
      final dives = _ref.read(diveListNotifierProvider).value ?? [];
      if (dives.isEmpty) {
        state = state.copyWith(status: ExportStatus.error, message: 'No dives to export');
        return;
      }
      final path = await _exportService.exportDivesToPdf(dives);
      state = state.copyWith(status: ExportStatus.success, message: 'PDF logbook generated successfully', filePath: path);
    } catch (e) {
      state = state.copyWith(status: ExportStatus.error, message: 'Export failed: $e');
    }
  }

  Future<void> exportDivesToUddf() async {
    state = state.copyWith(status: ExportStatus.exporting, message: 'Generating UDDF file...');
    try {
      final dives = _ref.read(diveListNotifierProvider).value ?? [];
      if (dives.isEmpty) {
        state = state.copyWith(status: ExportStatus.error, message: 'No dives to export');
        return;
      }

      // Collect all data for comprehensive export
      state = state.copyWith(message: 'Collecting all data...');
      final sites = _ref.read(sitesProvider).value ?? [];
      final equipment = _ref.read(allEquipmentProvider).value ?? [];
      final buddies = await _ref.read(allBuddiesProvider.future);
      final certifications = await _ref.read(allCertificationsProvider.future);
      final diveCenters = await _ref.read(allDiveCentersProvider.future);
      final species = await _ref.read(allSpeciesProvider.future);

      // Fetch dive buddies for each dive
      final buddyRepository = _ref.read(buddyRepositoryProvider);
      final Map<String, List<BuddyWithRole>> diveBuddies = {};
      for (final dive in dives) {
        final buddiesForDive = await buddyRepository.getBuddiesForDive(dive.id);
        if (buddiesForDive.isNotEmpty) {
          diveBuddies[dive.id] = buddiesForDive;
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
      );
      state = state.copyWith(status: ExportStatus.success, message: 'UDDF file generated successfully', filePath: path);
    } catch (e) {
      state = state.copyWith(status: ExportStatus.error, message: 'Export failed: $e');
    }
  }

  void reset() {
    state = const ExportState();
  }

  Future<void> importDivesFromCsv() async {
    state = state.copyWith(status: ExportStatus.exporting, message: 'Selecting file...');
    try {
      // Use FileType.any on iOS/macOS since custom extensions don't work reliably
      final useAnyType = Platform.isIOS || Platform.isMacOS;
      final result = await FilePicker.platform.pickFiles(
        type: useAnyType ? FileType.any : FileType.custom,
        allowedExtensions: useAnyType ? null : ['csv'],
        allowMultiple: false,
      );

      if (result == null || result.files.isEmpty) {
        state = state.copyWith(status: ExportStatus.idle, message: 'Import cancelled');
        return;
      }

      state = state.copyWith(message: 'Reading file...');
      final filePath = result.files.first.path;
      if (filePath == null) {
        state = state.copyWith(status: ExportStatus.error, message: 'Could not access file');
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
        state = state.copyWith(status: ExportStatus.error, message: 'No dives found in CSV file');
        return;
      }

      state = state.copyWith(message: 'Importing ${parsedDives.length} dives...');
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
          // Keep legacy text for backwards compatibility display, but also link proper buddies
          buddy: buddyText,
          diveMaster: diveMasterText,
          rating: diveData['rating'] as int?,
          notes: diveData['notes'] as String? ?? '',
          visibility: diveData['visibility'] as Visibility?,
          diveTypeId: diveData['diveType'] as String? ?? 'recreational',
          tanks: _buildTanks(diveData, uuid),
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

      final buddyMessage = buddiesCreated > 0 ? ' and $buddiesCreated buddy associations' : '';
      state = state.copyWith(
        status: ExportStatus.success,
        message: 'Successfully imported $importedCount dives$buddyMessage',
      );
    } catch (e) {
      state = state.copyWith(status: ExportStatus.error, message: 'Import failed: $e');
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
      final existingNames = result.map((b) => b.buddy.name.toLowerCase()).toSet();
      
      final names = diveMasterText
          .split(RegExp(r'[,;]|\s+and\s+', caseSensitive: false))
          .map((n) => n.trim())
          .where((n) => n.isNotEmpty && !existingNames.contains(n.toLowerCase()))
          .toList();

      for (final name in names) {
        final buddy = await buddyRepository.findOrCreateByName(name);
        // Try to determine role from name or default to diveGuide
        final lowerName = name.toLowerCase();
        BuddyRole role;
        if (lowerName.contains('instructor')) {
          role = BuddyRole.instructor;
        } else if (lowerName.contains('divemaster') || lowerName.contains('dm')) {
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
  Future<void> _linkBuddiesToDive(String diveId, List<BuddyWithRole> buddies) async {
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
    state = state.copyWith(status: ExportStatus.exporting, message: 'Selecting file...');
    try {
      // Use FileType.any on iOS/macOS since custom extensions don't work reliably
      final useAnyType = Platform.isIOS || Platform.isMacOS;
      final result = await FilePicker.platform.pickFiles(
        type: useAnyType ? FileType.any : FileType.custom,
        allowedExtensions: useAnyType ? null : ['uddf', 'xml'],
        allowMultiple: false,
      );

      if (result == null || result.files.isEmpty) {
        state = state.copyWith(status: ExportStatus.idle, message: 'Import cancelled');
        return;
      }

      state = state.copyWith(message: 'Reading file...');
      final filePath = result.files.first.path;
      if (filePath == null) {
        state = state.copyWith(status: ExportStatus.error, message: 'Could not access file');
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

      state = state.copyWith(message: 'Parsing UDDF data...');
      final importData = await _exportService.importDivesFromUddf(uddfContent);
      final parsedDives = importData['dives'] ?? [];
      final parsedSites = importData['sites'] ?? [];

      if (parsedDives.isEmpty) {
        state = state.copyWith(status: ExportStatus.error, message: 'No dives found in UDDF file');
        return;
      }

      const uuid = Uuid();

      // Import dive sites first and build a mapping from UDDF ID to new site
      final siteMapping = <String, DiveSite>{}; // UDDF site ID -> created DiveSite
      if (parsedSites.isNotEmpty) {
        state = state.copyWith(message: 'Importing ${parsedSites.length} dive sites...');
        final siteNotifier = _ref.read(siteListNotifierProvider.notifier);

        for (final siteData in parsedSites) {
          final siteName = siteData['name'] as String?;
          if (siteName == null || siteName.isEmpty) continue;

          final uddfId = siteData['uddfId'] as String?;
          final lat = siteData['latitude'] as double?;
          final lon = siteData['longitude'] as double?;

          final newSite = DiveSite(
            id: uuid.v4(),
            name: siteName,
            description: siteData['description'] as String? ?? '',
            location: (lat != null && lon != null) ? GeoPoint(lat, lon) : null,
            maxDepth: siteData['maxDepth'] as double?,
            country: siteData['country'] as String?,
            region: siteData['region'] as String?,
          );

          final createdSite = await siteNotifier.addSite(newSite);

          // Map both the UDDF ID and site name for linking
          if (uddfId != null) {
            siteMapping[uddfId] = createdSite;
          }
        }
      }

      state = state.copyWith(message: 'Importing ${parsedDives.length} dives...');
      final diveNotifier = _ref.read(diveListNotifierProvider.notifier);

      var importedCount = 0;
      var buddiesCreated = 0;
      for (final diveData in parsedDives) {
        // Build profile points if present
        final profileData = diveData['profile'] as List<Map<String, dynamic>>?;
        final profile = profileData?.map((p) => DiveProfilePoint(
          timestamp: p['timestamp'] as int? ?? 0,
          depth: p['depth'] as double? ?? 0.0,
          temperature: p['temperature'] as double?,
          pressure: p['pressure'] as double?,
        ),).toList() ?? [];

        // Build tanks from parsed tank data or fall back to gas mix
        List<DiveTank> tanks = [];
        final tanksData = diveData['tanks'] as List<Map<String, dynamic>>?;
        if (tanksData != null && tanksData.isNotEmpty) {
          // Use the first tank with meaningful data
          final firstTankWithVolume = tanksData.firstWhere(
            (t) => t['volume'] != null,
            orElse: () => tanksData.first,
          );
          tanks = [
            DiveTank(
              id: uuid.v4(),
              volume: firstTankWithVolume['volume'] as double?,
              startPressure: firstTankWithVolume['startPressure'] as int?,
              endPressure: firstTankWithVolume['endPressure'] as int?,
              gasMix: firstTankWithVolume['gasMix'] as GasMix? ?? const GasMix(),
            ),
          ];
        } else {
          // Fall back to gas mix from samples
          final gasMix = diveData['gasMix'] as GasMix?;
          if (gasMix != null) {
            tanks = [
              DiveTank(
                id: uuid.v4(),
                gasMix: gasMix,
              ),
            ];
          }
        }

        // Link to imported site
        DiveSite? linkedSite;
        final siteDataMap = diveData['site'] as Map<String, dynamic>?;
        if (siteDataMap != null) {
          final uddfSiteId = siteDataMap['uddfId'] as String?;
          if (uddfSiteId != null && siteMapping.containsKey(uddfSiteId)) {
            linkedSite = siteMapping[uddfSiteId];
          }
        }

        // Include weight used in notes if available
        var notes = diveData['notes'] as String? ?? '';
        final weightUsed = diveData['weightUsed'] as double?;
        if (weightUsed != null && weightUsed > 0) {
          if (notes.isNotEmpty) notes += '\n';
          notes += 'Weight used: ${weightUsed.toStringAsFixed(1)} kg';
        }

        // Parse legacy buddy text fields into proper Buddy entities
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
          buddy: buddyText, // Keep legacy text for backwards compatibility
          diveMaster: diveMasterText, // Keep legacy text for backwards compatibility
          rating: diveData['rating'] as int?,
          notes: notes,
          visibility: diveData['visibility'] as Visibility?,
          diveTypeId: 'recreational',
          profile: profile,
          tanks: tanks,
          site: linkedSite,
        );

        await diveNotifier.addDive(dive);
        
        // Link buddy entities to the dive
        if (buddies.isNotEmpty) {
          await _linkBuddiesToDive(diveId, buddies);
          buddiesCreated += buddies.length;
        }
        
        importedCount++;
      }

      // Refresh sites and buddies providers
      _ref.invalidate(sitesProvider);
      _ref.invalidate(allBuddiesProvider);

      final buddyMessage = buddiesCreated > 0 ? ' and $buddiesCreated buddy associations' : '';
      state = state.copyWith(
        status: ExportStatus.success,
        message: 'Successfully imported $importedCount dives, ${siteMapping.length} sites$buddyMessage from UDDF',
      );
    } catch (e) {
      state = state.copyWith(status: ExportStatus.error, message: 'Import failed: $e');
    }
  }

  Future<void> createBackup() async {
    state = state.copyWith(status: ExportStatus.exporting, message: 'Creating backup...');
    try {
      final dateFormat = DateFormat('yyyy-MM-dd_HHmmss');
      final timestamp = dateFormat.format(DateTime.now());
      final fileName = 'submersion_backup_$timestamp.db';

      final directory = await getApplicationDocumentsDirectory();
      final backupPath = '${directory.path}/$fileName';

      await DatabaseService.instance.backup(backupPath);

      // Share the backup file
      await Share.shareXFiles(
        [XFile(backupPath, mimeType: 'application/octet-stream')],
        subject: 'Submersion Backup',
      );

      state = state.copyWith(
        status: ExportStatus.success,
        message: 'Backup created successfully',
        filePath: backupPath,
      );
    } catch (e) {
      state = state.copyWith(status: ExportStatus.error, message: 'Backup failed: $e');
    }
  }

  Future<void> restoreBackup() async {
    state = state.copyWith(status: ExportStatus.exporting, message: 'Selecting backup file...');
    try {
      // Use FileType.any on iOS/macOS since custom extensions don't work reliably
      final useAnyType = Platform.isIOS || Platform.isMacOS;
      final result = await FilePicker.platform.pickFiles(
        type: useAnyType ? FileType.any : FileType.custom,
        allowedExtensions: useAnyType ? null : ['db'],
        allowMultiple: false,
      );

      if (result == null || result.files.isEmpty) {
        state = state.copyWith(status: ExportStatus.idle, message: 'Restore cancelled');
        return;
      }

      final filePath = result.files.first.path;
      if (filePath == null) {
        state = state.copyWith(status: ExportStatus.error, message: 'Could not access file');
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
      _ref.invalidate(allEquipmentProvider);

      state = state.copyWith(
        status: ExportStatus.success,
        message: 'Backup restored successfully. Please restart the app.',
      );
    } catch (e) {
      state = state.copyWith(status: ExportStatus.error, message: 'Restore failed: $e');
    }
  }
}

final exportNotifierProvider = StateNotifierProvider<ExportNotifier, ExportState>((ref) {
  final exportService = ref.watch(exportServiceProvider);
  return ExportNotifier(exportService, ref);
});
