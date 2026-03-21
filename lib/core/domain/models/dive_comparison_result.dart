import 'package:submersion/core/domain/models/incoming_dive_data.dart';
import 'package:submersion/features/dive_log/domain/entities/dive.dart';

/// The type of field being compared, used for unit-aware formatting.
enum ComparisonFieldType { dateTime, depth, duration, temperature, text }

/// A field that matched within tolerance.
class SameField {
  final String name;
  final ComparisonFieldType type;
  final double? rawValue;

  const SameField({required this.name, required this.type, this.rawValue});
}

/// A field that differed beyond tolerance.
class DiffField {
  final String name;
  final ComparisonFieldType type;

  /// Raw existing value, or null if the existing dive lacks this field.
  final double? existingRaw;

  /// Raw incoming value, or null if the incoming dive lacks this field.
  final double? incomingRaw;

  /// Pre-formatted text values (for non-numeric fields like computer, date/time).
  final String? existingText;
  final String? incomingText;

  /// Raw numeric delta (incoming - existing), null if non-numeric or missing.
  final double? delta;

  const DiffField({
    required this.name,
    required this.type,
    this.existingRaw,
    this.incomingRaw,
    this.existingText,
    this.incomingText,
    this.delta,
  });
}

/// Result of comparing an existing [Dive] with an [IncomingDiveData].
class DiveComparisonResult {
  final List<SameField> sameFields;
  final List<DiffField> diffFields;

  const DiveComparisonResult({
    required this.sameFields,
    required this.diffFields,
  });
}

/// Compare an existing dive with incoming data, classifying each field
/// as same (within tolerance) or different.
///
/// Tolerances: time 60s, depth 0.5m, temperature 1.0C, duration 60s.
DiveComparisonResult compareForConsolidation(
  Dive existing,
  IncomingDiveData incoming,
) {
  final same = <SameField>[];
  final diff = <DiffField>[];

  // --- Time ---
  final existingTime = existing.effectiveEntryTime;
  final incomingTime = incoming.startTime;
  if (incomingTime != null) {
    final diffSec = existingTime.difference(incomingTime).inSeconds.abs();
    if (diffSec <= 60) {
      same.add(
        const SameField(name: 'date/time', type: ComparisonFieldType.dateTime),
      );
    } else {
      diff.add(
        DiffField(
          name: 'date/time',
          type: ComparisonFieldType.dateTime,
          existingText: _formatDateTime(existingTime),
          incomingText: _formatDateTime(incomingTime),
        ),
      );
    }
  }

  // --- Max Depth ---
  _compareNumeric(
    name: 'max depth',
    type: ComparisonFieldType.depth,
    existingVal: existing.maxDepth,
    incomingVal: incoming.maxDepth,
    tolerance: 0.5,
    same: same,
    diff: diff,
  );

  // --- Avg Depth ---
  _compareNumeric(
    name: 'avg depth',
    type: ComparisonFieldType.depth,
    existingVal: existing.avgDepth,
    incomingVal: incoming.avgDepth,
    tolerance: 0.5,
    same: same,
    diff: diff,
  );

  // --- Duration ---
  _compareNumeric(
    name: 'duration',
    type: ComparisonFieldType.duration,
    existingVal: existing.duration?.inSeconds.toDouble(),
    incomingVal: incoming.durationSeconds?.toDouble(),
    tolerance: 60,
    same: same,
    diff: diff,
  );

  // --- Water Temp ---
  _compareNumeric(
    name: 'water temp',
    type: ComparisonFieldType.temperature,
    existingVal: existing.waterTemp,
    incomingVal: incoming.waterTemp,
    tolerance: 1.0,
    same: same,
    diff: diff,
  );

  // --- Computer (always diff — different devices by definition) ---
  diff.add(
    DiffField(
      name: 'computer',
      type: ComparisonFieldType.text,
      existingText: _formatComputer(
        name: null,
        model: existing.diveComputerModel,
        serial: existing.diveComputerSerial,
      ),
      incomingText: _formatComputer(
        name: incoming.computerName,
        model: incoming.computerModel,
        serial: incoming.computerSerial,
      ),
    ),
  );

  return DiveComparisonResult(sameFields: same, diffFields: diff);
}

void _compareNumeric({
  required String name,
  required ComparisonFieldType type,
  required double? existingVal,
  required double? incomingVal,
  required double tolerance,
  required List<SameField> same,
  required List<DiffField> diff,
}) {
  if (existingVal == null && incomingVal == null) return;

  if (existingVal == null || incomingVal == null) {
    diff.add(
      DiffField(
        name: name,
        type: type,
        existingRaw: existingVal,
        incomingRaw: incomingVal,
      ),
    );
    return;
  }

  final delta = incomingVal - existingVal;
  if (delta.abs() <= tolerance) {
    same.add(SameField(name: name, type: type, rawValue: existingVal));
  } else {
    diff.add(
      DiffField(
        name: name,
        type: type,
        existingRaw: existingVal,
        incomingRaw: incomingVal,
        delta: delta,
      ),
    );
  }
}

String _formatDateTime(DateTime dt) {
  return '${dt.month}/${dt.day}/${dt.year} '
      '${dt.hour.toString().padLeft(2, '0')}:'
      '${dt.minute.toString().padLeft(2, '0')}';
}

String _formatComputer({String? name, String? model, String? serial}) {
  final parts = <String>[];
  if (name != null && name.isNotEmpty) parts.add(name);
  if (model != null && model != name) parts.add(model);
  if (serial != null) parts.add('S/N: $serial');
  return parts.isEmpty ? 'Unknown' : parts.join(' \u00b7 ');
}
