import 'package:csv/csv.dart';
import 'package:intl/intl.dart';

import 'package:submersion/core/constants/enums.dart' as enums;

/// Handles importing dive data from CSV files.
class CsvImportService {
  /// Import dives from CSV content.
  ///
  /// Parses CSV with flexible header matching -- supports various column
  /// naming conventions from different dive log software.
  /// Returns a list of maps with parsed dive fields.
  Future<List<Map<String, dynamic>>> importDivesFromCsv(
    String csvContent,
  ) async {
    final rows = const CsvToListConverter().convert(csvContent);
    if (rows.isEmpty) {
      throw const FormatException('CSV file is empty');
    }

    final originalHeaders = rows.first.map((e) => e.toString().trim()).toList();
    final headers = originalHeaders.map((e) => e.toLowerCase()).toList();
    final dataRows = rows.skip(1);

    final dives = <Map<String, dynamic>>[];

    for (final row in dataRows) {
      if (row.isEmpty ||
          row.every((cell) => cell == null || cell.toString().isEmpty)) {
        continue; // Skip empty rows
      }

      final diveData = <String, dynamic>{};

      // Map CSV columns to dive fields
      for (var i = 0; i < headers.length && i < row.length; i++) {
        final header = headers[i];
        final value = row[i]?.toString().trim() ?? '';

        if (value.isEmpty) continue;

        if (header.contains('dive') && header.contains('number')) {
          diveData['diveNumber'] = int.tryParse(value);
        } else if (header == 'date' ||
            header.contains('date') && !header.contains('time')) {
          diveData['date'] = _parseDate(value);
        } else if (header == 'time' ||
            header.contains('time') && !header.contains('date')) {
          diveData['time'] = _parseTime(value);
        } else if (header.contains('max') && header.contains('depth')) {
          diveData['maxDepth'] = _parseDouble(value);
        } else if (header.contains('avg') && header.contains('depth')) {
          diveData['avgDepth'] = _parseDouble(value);
        } else if (header.contains('bottom') && header.contains('time')) {
          diveData['duration'] = _parseDuration(value);
        } else if (header.contains('runtime')) {
          diveData['runtime'] = _parseDuration(value);
        } else if (header.contains('duration') ||
            header.contains('time') && header.contains('min')) {
          diveData['duration'] = _parseDuration(value);
        } else if (header.contains('water') && header.contains('temp')) {
          diveData['waterTemp'] = _parseDouble(value);
        } else if (header.contains('air') && header.contains('temp')) {
          diveData['airTemp'] = _parseDouble(value);
        } else if (header.contains('site') || header.contains('location')) {
          diveData['siteName'] = value;
        } else if (header.contains('buddy')) {
          diveData['buddy'] = value;
        } else if (header.contains('dive') && header.contains('master')) {
          diveData['diveMaster'] = value;
        } else if (header.contains('rating')) {
          diveData['rating'] = int.tryParse(value);
        } else if (header.contains('note')) {
          diveData['notes'] = value;
        } else if (header.contains('visibility')) {
          diveData['visibility'] = _parseVisibility(value);
        } else if (header.contains('type')) {
          diveData['diveType'] = _parseDiveType(value);
        } else if (header.contains('start') && header.contains('pressure')) {
          diveData['startPressure'] = int.tryParse(value);
        } else if (header.contains('end') && header.contains('pressure')) {
          diveData['endPressure'] = int.tryParse(value);
        } else if (header.contains('tank') && header.contains('volume')) {
          diveData['tankVolume'] = _parseDouble(value);
        } else if (header.contains('o2') || header.contains('oxygen')) {
          diveData['o2Percent'] = _parseDouble(value);
        } else if (header.startsWith('custom:')) {
          // Extract key from original (non-lowercased) header to preserve case
          final customKey = originalHeaders[i].substring(7).trim();
          if (customKey.isNotEmpty) {
            diveData.putIfAbsent('customFields', () => <Map<String, String>>[]);
            (diveData['customFields'] as List).add({
              'key': customKey,
              'value': value,
            });
          }
        }
      }

      // Combine date and time if both present
      if (diveData['date'] != null) {
        DateTime dateTime = diveData['date'] as DateTime;
        if (diveData['time'] != null) {
          final time = diveData['time'] as DateTime;
          dateTime = DateTime(
            dateTime.year,
            dateTime.month,
            dateTime.day,
            time.hour,
            time.minute,
          );
        }
        diveData['dateTime'] = dateTime;
        diveData.remove('date');
        diveData.remove('time');
      }

      if (diveData.isNotEmpty) {
        dives.add(diveData);
      }
    }

    return dives;
  }

  // ==================== Parsing Helpers ====================

  DateTime? _parseDate(String value) {
    final formats = [
      'yyyy-MM-dd',
      'MM/dd/yyyy',
      'dd/MM/yyyy',
      'yyyy/MM/dd',
      'dd-MM-yyyy',
      'MM-dd-yyyy',
    ];

    for (final format in formats) {
      try {
        return DateFormat(format).parse(value);
      } catch (_) {
        continue;
      }
    }

    return DateTime.tryParse(value);
  }

  DateTime? _parseTime(String value) {
    final formats = ['HH:mm', 'H:mm', 'hh:mm a', 'h:mm a'];

    for (final format in formats) {
      try {
        return DateFormat(format).parse(value);
      } catch (_) {
        continue;
      }
    }

    return null;
  }

  double? _parseDouble(String value) {
    final cleanValue = value.replaceAll(RegExp(r'[^\d.-]'), '');
    return double.tryParse(cleanValue);
  }

  Duration? _parseDuration(String value) {
    final minutes = int.tryParse(value.replaceAll(RegExp(r'[^\d]'), ''));
    if (minutes != null) {
      return Duration(minutes: minutes);
    }

    final parts = value.split(':');
    if (parts.length == 2) {
      final hours = int.tryParse(parts[0]);
      final mins = int.tryParse(parts[1]);
      if (hours != null && mins != null) {
        return Duration(hours: hours, minutes: mins);
      }
    }

    return null;
  }

  enums.Visibility? _parseVisibility(String value) {
    final lower = value.toLowerCase();
    if (lower.contains('excellent') ||
        lower.contains('>30') ||
        lower.contains('>100')) {
      return enums.Visibility.excellent;
    } else if (lower.contains('good') ||
        lower.contains('15-30') ||
        lower.contains('50-100')) {
      return enums.Visibility.good;
    } else if (lower.contains('moderate') ||
        lower.contains('fair') ||
        lower.contains('5-15') ||
        lower.contains('15-50')) {
      return enums.Visibility.moderate;
    } else if (lower.contains('poor') ||
        lower.contains('<5') ||
        lower.contains('<15')) {
      return enums.Visibility.poor;
    }
    return enums.Visibility.unknown;
  }

  String _parseDiveType(String value) {
    final lower = value.toLowerCase();
    if (lower.contains('training') || lower.contains('course')) {
      return 'training';
    } else if (lower.contains('night')) {
      return 'night';
    } else if (lower.contains('deep')) {
      return 'deep';
    } else if (lower.contains('wreck')) {
      return 'wreck';
    } else if (lower.contains('drift')) {
      return 'drift';
    } else if (lower.contains('cave') || lower.contains('cavern')) {
      return 'cave';
    } else if (lower.contains('tech')) {
      return 'technical';
    } else if (lower.contains('free')) {
      return 'freedive';
    } else if (lower.contains('ice')) {
      return 'ice';
    } else if (lower.contains('altitude')) {
      return 'altitude';
    } else if (lower.contains('shore')) {
      return 'shore';
    } else if (lower.contains('boat')) {
      return 'boat';
    } else if (lower.contains('liveaboard')) {
      return 'liveaboard';
    }
    return 'recreational';
  }
}
