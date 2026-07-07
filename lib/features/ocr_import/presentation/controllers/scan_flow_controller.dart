import 'dart:typed_data';

import 'package:submersion/features/dive_log/domain/entities/dive_prefill.dart';
import 'package:submersion/features/dive_sites/domain/entities/dive_site.dart';
import 'package:submersion/features/ocr_import/domain/models/parsed_dive_fields.dart';
import 'package:submersion/features/ocr_import/domain/services/logbook_parser.dart';
import 'package:submersion/features/ocr_import/domain/services/ocr_engine.dart';
import 'package:submersion/features/ocr_import/domain/services/site_resolver.dart';
import 'package:submersion/features/ocr_import/domain/services/unit_context.dart';

/// Orchestrates photo -> OCR -> parse -> site resolution -> DivePrefill.
///
/// Never throws: engine or parse failures produce an empty-fields prefill
/// so the flow always lands on the edit form with the photo attached.
class ScanFlowController {
  final OcrEngine engine;
  final LogbookParser parser;
  final List<DiveSite> existingSites;
  final UnitDefaults fallbackUnits;
  final bool preferDayFirst;

  ScanFlowController({
    required this.engine,
    required this.parser,
    required this.existingSites,
    required this.fallbackUnits,
    required this.preferDayFirst,
  });

  Future<DivePrefill> process(Uint8List imageBytes, String photoPath) async {
    ParsedDiveFields parsed;
    try {
      final ocr = await engine.recognize(imageBytes);
      parsed = parser.parse(
        ocr,
        fallbackUnits: fallbackUnits,
        preferDayFirst: preferDayFirst,
      );
    } catch (_) {
      parsed = const ParsedDiveFields();
    }

    final site = parsed.siteName != null
        ? resolveSiteByName(parsed.siteName!, existingSites)
        : null;

    return DivePrefill(
      diveNumber: parsed.diveNumber,
      dateTime: parsed.date,
      hasTimeOfDay: parsed.hasTimeOfDay,
      durationMinutes: parsed.durationMinutes,
      maxDepthMeters: parsed.maxDepthMeters,
      waterTempCelsius: parsed.waterTempCelsius,
      airTempCelsius: parsed.airTempCelsius,
      rating: parsed.rating,
      notes: _composeNotes(parsed, site),
      site: site,
      startPressureBar: parsed.startPressureBar,
      endPressureBar: parsed.endPressureBar,
      o2Percent: parsed.o2Percent,
      cylinderVolumeLiters: parsed.cylinderVolumeLiters,
      weightKg: parsed.weightKg,
      photoPath: photoPath,
      importSource: 'ocr',
    );
  }

  /// Notes body plus a plain-text appendix for values the form cannot
  /// hold (unresolved site name, visibility, buddy...). The appendix is
  /// data, not UI chrome, so it is intentionally not localized.
  String? _composeNotes(ParsedDiveFields parsed, DiveSite? resolvedSite) {
    final appendix = <String, String>{};
    if (resolvedSite == null && parsed.siteName != null) {
      appendix['Site'] = parsed.siteName!;
      if (parsed.locationText != null) {
        appendix['Location'] = parsed.locationText!;
      }
    }
    for (final entry in parsed.unmapped.entries) {
      final key = entry.key[0].toUpperCase() + entry.key.substring(1);
      appendix[key] = entry.value;
    }

    if (appendix.isEmpty) return parsed.notes;
    final block = [
      '--- Scanned from paper log ---',
      for (final entry in appendix.entries) '${entry.key}: ${entry.value}',
    ].join('\n');
    return parsed.notes == null ? block : '${parsed.notes}\n\n$block';
  }
}
