import 'package:submersion/features/universal_import/data/models/import_enums.dart';
import 'package:submersion/features/universal_import/data/parsers/dan_dl7_import_parser.dart';
import 'package:submersion/features/universal_import/data/parsers/fit_import_parser.dart';
import 'package:submersion/features/universal_import/data/parsers/import_parser.dart';
import 'package:submersion/features/universal_import/data/parsers/macdive_sqlite_parser.dart';
import 'package:submersion/features/universal_import/data/parsers/macdive_xml_parser.dart';
import 'package:submersion/features/universal_import/data/parsers/placeholder_parser.dart';
import 'package:submersion/features/universal_import/data/parsers/ratio_xml_parser.dart';
import 'package:submersion/features/universal_import/data/parsers/shearwater_cloud_parser.dart';
import 'package:submersion/features/universal_import/data/parsers/submersion_csv/submersion_equipment_csv_parser.dart';
import 'package:submersion/features/universal_import/data/parsers/submersion_csv/submersion_sites_csv_parser.dart';
import 'package:submersion/features/universal_import/data/parsers/subsurface_xml_parser.dart';
import 'package:submersion/features/universal_import/data/parsers/uddf_import_parser.dart';

/// Parser for a self-describing format. Generic CSV needs per-file mapping
/// state and stays in the notifier's `_parserFor`; Submersion's own CSV
/// exports are self-describing and are routed here (#1813).
ImportParser parserForFormat(ImportFormat format) {
  return switch (format) {
    ImportFormat.uddf => UddfImportParser(),
    ImportFormat.macdiveXml => const MacDiveXmlParser(),
    ImportFormat.macdiveSqlite => const MacDiveSqliteParser(),
    ImportFormat.subsurfaceXml => SubsurfaceXmlParser(),
    ImportFormat.danDl7 => const DanDl7Parser(),
    ImportFormat.fit => const FitImportParser(),
    ImportFormat.shearwaterDb => ShearwaterCloudParser(),
    ImportFormat.ratioXml => const RatioXmlParser(),
    ImportFormat.submersionSitesCsv => const SubmersionSitesCsvParser(),
    ImportFormat.submersionEquipmentCsv => const SubmersionEquipmentCsvParser(),
    _ => const PlaceholderParser(),
  };
}
