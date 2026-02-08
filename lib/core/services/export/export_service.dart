import 'package:submersion/core/constants/units.dart';
import 'package:submersion/core/services/export/csv/csv_export_service.dart';
import 'package:submersion/core/services/export/csv/csv_import_service.dart';
import 'package:submersion/core/services/export/excel/excel_export_service.dart';
import 'package:submersion/core/services/export/kml/kml_export_service.dart';
import 'package:submersion/core/services/export/models/export_service_record.dart';
import 'package:submersion/core/services/export/models/uddf_import_result.dart';
import 'package:submersion/core/services/export/pdf/pdf_course_export_service.dart';
import 'package:submersion/core/services/export/pdf/pdf_export_service.dart';
import 'package:submersion/core/services/export/shared/file_export_utils.dart'
    as file_utils;
import 'package:submersion/core/services/export/uddf/uddf_export_service.dart';
import 'package:submersion/core/services/export/uddf/uddf_full_export_service.dart';
import 'package:submersion/core/services/export/uddf/uddf_full_import_service.dart';
import 'package:submersion/core/services/export/uddf/uddf_import_service.dart';
import 'package:submersion/features/buddies/domain/entities/buddy.dart';
import 'package:submersion/features/certifications/domain/entities/certification.dart';
import 'package:submersion/features/courses/domain/entities/course.dart';
import 'package:submersion/features/dive_centers/domain/entities/dive_center.dart';
import 'package:submersion/features/dive_log/domain/entities/dive.dart';
import 'package:submersion/features/dive_log/domain/entities/dive_computer.dart';
import 'package:submersion/features/dive_log/domain/entities/dive_weight.dart';
import 'package:submersion/features/dive_log/domain/entities/gas_switch.dart';
import 'package:submersion/features/dive_log/domain/entities/profile_event.dart';
import 'package:submersion/features/dive_sites/domain/entities/dive_site.dart';
import 'package:submersion/features/dive_types/domain/entities/dive_type_entity.dart';
import 'package:submersion/features/divers/domain/entities/diver.dart';
import 'package:submersion/features/equipment/domain/entities/equipment_item.dart';
import 'package:submersion/features/equipment/domain/entities/equipment_set.dart';
import 'package:submersion/features/marine_life/domain/entities/species.dart';
import 'package:submersion/features/tags/domain/entities/tag.dart';
import 'package:submersion/features/trips/domain/entities/trip.dart';

export 'package:submersion/core/services/export/models/export_service_record.dart';
export 'package:submersion/core/services/export/models/uddf_import_result.dart';

/// Facade for all export/import operations.
///
/// Delegates to focused sub-services while preserving a single entry point
/// for consumers. This is the only singleton -- sub-services are plain classes.
class ExportService {
  static final _instance = ExportService._internal();
  factory ExportService() => _instance;
  ExportService._internal();

  final _csv = CsvExportService();
  final _csvImport = CsvImportService();
  final _pdf = PdfExportService();
  final _pdfCourse = PdfCourseExportService();
  final _excel = ExcelExportService();
  final _kml = KmlExportService();
  final _uddf = UddfExportService();
  final _uddfFull = UddfFullExportService();
  final _uddfImport = UddfImportService();
  final _uddfFullImport = UddfFullImportService();

  // ==================== CSV Export ====================

  Future<String> exportDivesToCsv(List<Dive> dives) =>
      _csv.exportDivesToCsv(dives);

  Future<String> exportSitesToCsv(List<DiveSite> sites) =>
      _csv.exportSitesToCsv(sites);

  Future<String> exportEquipmentToCsv(List<EquipmentItem> equipment) =>
      _csv.exportEquipmentToCsv(equipment);

  Future<String> exportTripsToCsv(List<Trip> trips) =>
      _csv.exportTripsToCsv(trips);

  String generateDivesCsvContent(List<Dive> dives) =>
      _csv.generateDivesCsvContent(dives);

  String generateSitesCsvContent(List<DiveSite> sites) =>
      _csv.generateSitesCsvContent(sites);

  String generateEquipmentCsvContent(List<EquipmentItem> equipment) =>
      _csv.generateEquipmentCsvContent(equipment);

  Future<String?> saveDivesCsvToFile(List<Dive> dives) =>
      _csv.saveDivesCsvToFile(dives);

  Future<String?> saveSitesCsvToFile(List<DiveSite> sites) =>
      _csv.saveSitesCsvToFile(sites);

  Future<String?> saveEquipmentCsvToFile(List<EquipmentItem> equipment) =>
      _csv.saveEquipmentCsvToFile(equipment);

  // ==================== CSV Import ====================

  Future<List<Map<String, dynamic>>> importDivesFromCsv(String csvContent) =>
      _csvImport.importDivesFromCsv(csvContent);

  // ==================== PDF Export ====================

  Future<String> exportTripToPdf(
    Trip trip,
    List<Dive> dives, {
    TripWithStats? stats,
  }) => _pdf.exportTripToPdf(trip, dives, stats: stats);

  Future<({List<int> bytes, String fileName})> generateDivePdfBytes(
    List<Dive> dives, {
    String title = 'Dive Logbook',
    List<Sighting>? allSightings,
  }) => _pdf.generateDivePdfBytes(
    dives,
    title: title,
    allSightings: allSightings,
  );

  Future<String> exportDivesToPdf(
    List<Dive> dives, {
    String title = 'Dive Logbook',
    List<Sighting>? allSightings,
  }) => _pdf.exportDivesToPdf(dives, title: title, allSightings: allSightings);

  Future<String?> saveDivesToPdfFile(
    List<Dive> dives, {
    String title = 'Dive Logbook',
    List<Sighting>? allSightings,
  }) =>
      _pdf.saveDivesToPdfFile(dives, title: title, allSightings: allSightings);

  // ==================== PDF Course Export ====================

  Future<String> exportCourseTrainingLogToPdf(
    Course course,
    List<Dive> trainingDives,
  ) => _pdfCourse.exportCourseTrainingLogToPdf(course, trainingDives);

  // ==================== Excel Export ====================

  Future<String> exportToExcel({
    required List<Dive> dives,
    required List<DiveSite> sites,
    required List<EquipmentItem> equipment,
    required DepthUnit depthUnit,
    required TemperatureUnit temperatureUnit,
    required PressureUnit pressureUnit,
    required VolumeUnit volumeUnit,
    required DateFormatPreference dateFormat,
  }) => _excel.exportToExcel(
    dives: dives,
    sites: sites,
    equipment: equipment,
    depthUnit: depthUnit,
    temperatureUnit: temperatureUnit,
    pressureUnit: pressureUnit,
    volumeUnit: volumeUnit,
    dateFormat: dateFormat,
  );

  Future<List<int>> generateExcelBytes({
    required List<Dive> dives,
    required List<DiveSite> sites,
    required List<EquipmentItem> equipment,
    required DepthUnit depthUnit,
    required TemperatureUnit temperatureUnit,
    required PressureUnit pressureUnit,
    required VolumeUnit volumeUnit,
    required DateFormatPreference dateFormat,
  }) => _excel.generateExcelBytes(
    dives: dives,
    sites: sites,
    equipment: equipment,
    depthUnit: depthUnit,
    temperatureUnit: temperatureUnit,
    pressureUnit: pressureUnit,
    volumeUnit: volumeUnit,
    dateFormat: dateFormat,
  );

  Future<String?> saveExcelToFile({
    required List<Dive> dives,
    required List<DiveSite> sites,
    required List<EquipmentItem> equipment,
    required DepthUnit depthUnit,
    required TemperatureUnit temperatureUnit,
    required PressureUnit pressureUnit,
    required VolumeUnit volumeUnit,
    required DateFormatPreference dateFormat,
  }) => _excel.saveExcelToFile(
    dives: dives,
    sites: sites,
    equipment: equipment,
    depthUnit: depthUnit,
    temperatureUnit: temperatureUnit,
    pressureUnit: pressureUnit,
    volumeUnit: volumeUnit,
    dateFormat: dateFormat,
  );

  // ==================== KML Export ====================

  Future<(String, int)> exportToKml({
    required List<DiveSite> sites,
    required List<Dive> dives,
    required DepthUnit depthUnit,
    required DateFormatPreference dateFormat,
  }) => _kml.exportToKml(
    sites: sites,
    dives: dives,
    depthUnit: depthUnit,
    dateFormat: dateFormat,
  );

  Future<(String, int)> generateKmlContent({
    required List<DiveSite> sites,
    required List<Dive> dives,
    required DepthUnit depthUnit,
    required DateFormatPreference dateFormat,
  }) => _kml.generateKmlContent(
    sites: sites,
    dives: dives,
    depthUnit: depthUnit,
    dateFormat: dateFormat,
  );

  Future<(String?, int)> saveKmlToFile({
    required List<DiveSite> sites,
    required List<Dive> dives,
    required DepthUnit depthUnit,
    required DateFormatPreference dateFormat,
  }) => _kml.saveKmlToFile(
    sites: sites,
    dives: dives,
    depthUnit: depthUnit,
    dateFormat: dateFormat,
  );

  // ==================== UDDF Export ====================

  Future<String> exportDivesToUddf(List<Dive> dives, {List<DiveSite>? sites}) =>
      _uddf.exportDivesToUddf(dives, sites: sites);

  Future<String> exportAllDataToUddf({
    required List<Dive> dives,
    List<DiveSite>? sites,
    List<EquipmentItem>? equipment,
    List<Buddy>? buddies,
    List<Certification>? certifications,
    List<DiveCenter>? diveCenters,
    List<Species>? species,
    List<ServiceRecord>? serviceRecords,
    Map<String, String>? settings,
    Map<String, List<BuddyWithRole>>? diveBuddies,
    Diver? owner,
    List<Trip>? trips,
    List<Tag>? tags,
    Map<String, List<Tag>>? diveTags,
    List<DiveTypeEntity>? customDiveTypes,
    List<DiveComputer>? diveComputers,
    Map<String, List<ProfileEvent>>? diveProfileEvents,
    Map<String, List<DiveWeight>>? diveWeights,
    List<EquipmentSet>? equipmentSets,
    List<Course>? courses,
    Map<String, List<GasSwitchWithTank>>? diveGasSwitches,
  }) => _uddfFull.exportAllDataToUddf(
    dives: dives,
    sites: sites,
    equipment: equipment,
    buddies: buddies,
    certifications: certifications,
    diveCenters: diveCenters,
    species: species,
    serviceRecords: serviceRecords,
    settings: settings,
    diveBuddies: diveBuddies,
    owner: owner,
    trips: trips,
    tags: tags,
    diveTags: diveTags,
    customDiveTypes: customDiveTypes,
    diveComputers: diveComputers,
    diveProfileEvents: diveProfileEvents,
    diveWeights: diveWeights,
    equipmentSets: equipmentSets,
    courses: courses,
    diveGasSwitches: diveGasSwitches,
  );

  Future<String?> saveAllDataToUddfFile({
    required List<Dive> dives,
    List<DiveSite>? sites,
    List<EquipmentItem>? equipment,
    List<Buddy>? buddies,
    List<Certification>? certifications,
    List<DiveCenter>? diveCenters,
    List<Species>? species,
    List<ServiceRecord>? serviceRecords,
    Map<String, String>? settings,
    Map<String, List<BuddyWithRole>>? diveBuddies,
    Diver? owner,
    List<Trip>? trips,
    List<Tag>? tags,
    Map<String, List<Tag>>? diveTags,
    List<DiveTypeEntity>? customDiveTypes,
    List<DiveComputer>? diveComputers,
    Map<String, List<ProfileEvent>>? diveProfileEvents,
    Map<String, List<DiveWeight>>? diveWeights,
    List<EquipmentSet>? equipmentSets,
    List<Course>? courses,
    Map<String, List<GasSwitchWithTank>>? diveGasSwitches,
  }) => _uddfFull.saveAllDataToUddfFile(
    dives: dives,
    sites: sites,
    equipment: equipment,
    buddies: buddies,
    certifications: certifications,
    diveCenters: diveCenters,
    species: species,
    serviceRecords: serviceRecords,
    settings: settings,
    diveBuddies: diveBuddies,
    owner: owner,
    trips: trips,
    tags: tags,
    diveTags: diveTags,
    customDiveTypes: customDiveTypes,
    diveComputers: diveComputers,
    diveProfileEvents: diveProfileEvents,
    diveWeights: diveWeights,
    equipmentSets: equipmentSets,
    courses: courses,
    diveGasSwitches: diveGasSwitches,
  );

  // ==================== UDDF Import ====================

  Future<Map<String, List<Map<String, dynamic>>>> importDivesFromUddf(
    String uddfContent,
  ) => _uddfImport.importDivesFromUddf(uddfContent);

  Future<UddfImportResult> importAllDataFromUddf(String uddfContent) =>
      _uddfFullImport.importAllDataFromUddf(uddfContent);

  // ==================== File Utilities ====================

  Future<String> getExportFilePath(String fileName) =>
      file_utils.getExportFilePath(fileName);

  Future<String> exportImageAsPng(List<int> pngBytes, String fileName) =>
      file_utils.exportImageAsPng(pngBytes, fileName);

  Future<String> saveImageToPhotos(List<int> pngBytes, String fileName) =>
      file_utils.saveImageToPhotos(pngBytes, fileName);

  Future<String?> saveImageToFile(List<int> pngBytes, String fileName) =>
      file_utils.saveImageToFile(pngBytes, fileName);

  Future<String> sharePdfBytes(List<int> pdfBytes, String fileName) =>
      file_utils.sharePdfBytes(pdfBytes, fileName);

  Future<String?> savePdfToFile(List<int> pdfBytes, String fileName) =>
      file_utils.savePdfToFile(pdfBytes, fileName);
}
