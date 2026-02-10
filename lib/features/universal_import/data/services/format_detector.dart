import 'dart:convert';
import 'dart:typed_data';

import 'package:csv/csv.dart';

import 'package:submersion/features/universal_import/data/models/detection_result.dart';
import 'package:submersion/features/universal_import/data/models/import_enums.dart';

/// Detects the format and source application of an imported file.
///
/// Inspects file contents (not just extensions) using a detection chain
/// ordered by specificity:
/// 1. Binary magic bytes (FIT, SQLite)
/// 2. XML root element inspection
/// 3. CSV header analysis
/// 4. Fallback: unknown
class FormatDetector {
  const FormatDetector();

  /// Maximum bytes to read for detection purposes.
  static const _peekSize = 8192;

  /// Detect the format and source app of the given file bytes.
  DetectionResult detect(Uint8List bytes) {
    if (bytes.isEmpty) {
      return const DetectionResult(
        format: ImportFormat.unknown,
        confidence: 0.0,
        warnings: ['File is empty'],
      );
    }

    // 1. Binary detection
    final binaryResult = _detectBinary(bytes);
    if (binaryResult != null) return binaryResult;

    // Try to decode as text for XML/CSV detection
    final String textContent;
    try {
      final peekBytes = bytes.length > _peekSize
          ? bytes.sublist(0, _peekSize)
          : bytes;
      textContent = utf8.decode(peekBytes, allowMalformed: true);
    } catch (_) {
      return const DetectionResult(
        format: ImportFormat.unknown,
        confidence: 0.1,
        warnings: [
          'File does not appear to be text or a recognized binary format',
        ],
      );
    }

    // 2. XML detection
    final xmlResult = _detectXml(textContent);
    if (xmlResult != null) return xmlResult;

    // 3. CSV detection
    final csvResult = _detectCsv(textContent, bytes);
    if (csvResult != null) return csvResult;

    // 4. Fallback
    return const DetectionResult(
      format: ImportFormat.unknown,
      confidence: 0.0,
      warnings: ['Could not identify file format'],
    );
  }

  // ======================== Binary Detection ========================

  DetectionResult? _detectBinary(Uint8List bytes) {
    // FIT file: header ends with ".FIT" (bytes 8-11 or at specific offset)
    if (_isFitFile(bytes)) {
      return const DetectionResult(
        format: ImportFormat.fit,
        sourceApp: SourceApp.garminConnect,
        confidence: 1.0,
      );
    }

    // SQLite: starts with "SQLite format 3\0"
    if (_isSqliteFile(bytes)) {
      return _detectSqliteApp(bytes);
    }

    return null;
  }

  bool _isFitFile(Uint8List bytes) {
    if (bytes.length < 12) return false;
    // FIT header: byte[0] = header size, bytes[8..11] = ".FIT"
    final headerSize = bytes[0];
    if (headerSize < 12) return false;
    return bytes[8] == 0x2E && // .
        bytes[9] == 0x46 && // F
        bytes[10] == 0x49 && // I
        bytes[11] == 0x54; // T
  }

  bool _isSqliteFile(Uint8List bytes) {
    if (bytes.length < 16) return false;
    const magic = 'SQLite format 3';
    try {
      final header = utf8.decode(bytes.sublist(0, 15));
      return header == magic;
    } catch (_) {
      return false;
    }
  }

  DetectionResult _detectSqliteApp(Uint8List bytes) {
    // We can't easily query SQLite tables from raw bytes without a driver.
    // Return a generic SQLite detection and let the parser layer handle it.
    return const DetectionResult(
      format: ImportFormat.sqlite,
      confidence: 0.5,
      warnings: [
        'Detected SQLite database. '
            'Further analysis is needed to determine the source application.',
      ],
    );
  }

  // ======================== XML Detection ========================

  DetectionResult? _detectXml(String content) {
    final trimmed = content.trimLeft();

    // Must start with XML declaration or opening tag
    if (!trimmed.startsWith('<?xml') && !trimmed.startsWith('<')) {
      return null;
    }

    final lower = trimmed.toLowerCase();

    // Subsurface XML: <divelog program='subsurface'> or program="subsurface"
    if (lower.contains('<divelog') && lower.contains('subsurface')) {
      return const DetectionResult(
        format: ImportFormat.subsurfaceXml,
        sourceApp: SourceApp.subsurface,
        confidence: 0.98,
      );
    }

    // UDDF: <uddf> root element
    if (lower.contains('<uddf')) {
      // Check if it's a Submersion export
      final isSubmersion = lower.contains('submersion');
      return DetectionResult(
        format: ImportFormat.uddf,
        sourceApp: isSubmersion ? SourceApp.submersion : null,
        confidence: 0.95,
      );
    }

    // Diving Log XML: <DivingLog> root
    if (lower.contains('<divinglog')) {
      return const DetectionResult(
        format: ImportFormat.divingLogXml,
        sourceApp: SourceApp.divingLog,
        confidence: 0.95,
      );
    }

    // Suunto SML: <sml> root
    if (lower.contains('<sml')) {
      return const DetectionResult(
        format: ImportFormat.suuntoSml,
        sourceApp: SourceApp.suunto,
        confidence: 0.95,
      );
    }

    // DAN DL7 markers
    if (lower.contains('dl7') || lower.contains('divers alert network')) {
      return const DetectionResult(
        format: ImportFormat.danDl7,
        sourceApp: SourceApp.dan,
        confidence: 0.90,
      );
    }

    // Generic XML with dive-related keywords
    if (_hasDiveKeywords(lower)) {
      return const DetectionResult(
        format: ImportFormat.uddf,
        confidence: 0.5,
        warnings: [
          'XML file contains dive-related data but format is not recognized. '
              'Attempting to parse as UDDF.',
        ],
      );
    }

    return null;
  }

  bool _hasDiveKeywords(String lowerContent) {
    const keywords = [
      'dive',
      'depth',
      'maxdepth',
      'duration',
      'profile',
      'waypoint',
      'tank',
      'cylinder',
    ];
    var matchCount = 0;
    for (final keyword in keywords) {
      if (lowerContent.contains(keyword)) matchCount++;
    }
    return matchCount >= 3;
  }

  // ======================== CSV Detection ========================

  DetectionResult? _detectCsv(String content, Uint8List bytes) {
    // Try to parse first line as CSV headers
    List<List<dynamic>> rows;
    try {
      rows = const CsvToListConverter().convert(content);
    } catch (_) {
      return null;
    }

    if (rows.isEmpty) return null;

    final headers = rows.first
        .map((e) => e.toString().toLowerCase().trim())
        .toList();

    if (headers.isEmpty || headers.length < 2) return null;

    // Score against known app signatures
    final appScores = <SourceApp, double>{};

    appScores[SourceApp.macdive] = _scoreMacDive(headers);
    appScores[SourceApp.divingLog] = _scoreDivingLog(headers);
    appScores[SourceApp.diveMate] = _scoreDiveMate(headers);
    appScores[SourceApp.subsurface] = _scoreSubsurfaceCsv(headers);
    appScores[SourceApp.ssiMyDiveGuide] = _scoreSsi(headers);
    appScores[SourceApp.garminConnect] = _scoreGarminConnect(headers);
    appScores[SourceApp.shearwater] = _scoreShearwater(headers);
    appScores[SourceApp.submersion] = _scoreSubmersion(headers);

    // Find best match
    final bestEntry = appScores.entries.reduce(
      (a, b) => a.value >= b.value ? a : b,
    );

    // Check if it has enough dive-related columns to be a dive CSV
    final genericScore = _scoreGenericDiveCsv(headers);

    if (bestEntry.value > 0.6) {
      return DetectionResult(
        format: ImportFormat.csv,
        sourceApp: bestEntry.key,
        confidence: bestEntry.value,
        csvHeaders: rows.first.map((e) => e.toString().trim()).toList(),
      );
    }

    if (genericScore > 0.3) {
      return DetectionResult(
        format: ImportFormat.csv,
        sourceApp: SourceApp.generic,
        confidence: genericScore,
        csvHeaders: rows.first.map((e) => e.toString().trim()).toList(),
      );
    }

    return null;
  }

  // ======================== CSV App Scoring ========================

  double _scoreMacDive(List<String> headers) {
    const signatures = [
      'dive no',
      'max. depth',
      'bottom temp',
      'bottom time',
      'surface interval',
      'dive type',
    ];
    return _matchScore(headers, signatures);
  }

  double _scoreDivingLog(List<String> headers) {
    final joined = headers.join(' ');
    if (joined.contains('divelog')) return 0.85;
    const signatures = [
      'divedate',
      'divetime',
      'maxdepth',
      'divetime',
      'airtemp',
      'watertemp',
    ];
    return _matchScore(headers, signatures);
  }

  double _scoreDiveMate(List<String> headers) {
    final joined = headers.join(' ');
    if (joined.contains('divemate')) return 0.85;
    const signatures = [
      'dive no.',
      'date/time',
      'max depth',
      'duration',
      'water temperature',
    ];
    return _matchScore(headers, signatures);
  }

  double _scoreSubsurfaceCsv(List<String> headers) {
    const signatures = [
      'divesiteid',
      'cylindertype',
      'diveguide',
      'divemaster',
      'sac',
    ];
    return _matchScore(headers, signatures);
  }

  double _scoreSsi(List<String> headers) {
    final joined = headers.join(' ');
    if (joined.contains('ssi') || joined.contains('mydiveguide')) return 0.85;
    return 0.0;
  }

  double _scoreGarminConnect(List<String> headers) {
    const signatures = [
      'activity type',
      'max depth',
      'bottom time',
      'surface time',
      'avg depth',
    ];
    return _matchScore(headers, signatures);
  }

  double _scoreShearwater(List<String> headers) {
    const signatures = [
      'dive number',
      'max depth',
      'avg depth',
      'gf low',
      'gf high',
      'ppO2',
    ];
    return _matchScore(headers, signatures);
  }

  double _scoreSubmersion(List<String> headers) {
    const signatures = [
      'dive number',
      'date',
      'time',
      'site',
      'max depth',
      'bottom time',
      'water temp',
      'start pressure',
    ];
    return _matchScore(headers, signatures);
  }

  double _scoreGenericDiveCsv(List<String> headers) {
    const diveKeywords = [
      'depth',
      'duration',
      'time',
      'date',
      'temp',
      'site',
      'location',
      'dive',
      'pressure',
      'tank',
      'buddy',
      'rating',
      'visibility',
      'notes',
    ];
    var matches = 0;
    for (final keyword in diveKeywords) {
      if (headers.any((h) => h.contains(keyword))) matches++;
    }
    // Need at least 3 dive-related columns
    if (matches < 3) return 0.0;
    return (matches / diveKeywords.length).clamp(0.0, 0.9);
  }

  /// Score how well headers match a set of expected signatures.
  ///
  /// Returns 0.0 to 0.95 based on fraction of signatures found.
  double _matchScore(List<String> headers, List<String> signatures) {
    if (signatures.isEmpty) return 0.0;
    var matches = 0;
    for (final sig in signatures) {
      if (headers.any((h) => h.contains(sig))) matches++;
    }
    if (matches == 0) return 0.0;
    // Scale: 2 matches = 0.5, 3+ = 0.7+, all = 0.95
    return (matches / signatures.length * 0.95).clamp(0.0, 0.95);
  }
}
