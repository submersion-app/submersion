import 'package:submersion/features/ocr_import/domain/models/ocr_result.dart';
import 'package:submersion/features/ocr_import/domain/models/parsed_dive_fields.dart';
import 'package:submersion/features/ocr_import/domain/services/label_binder.dart';
import 'package:submersion/features/ocr_import/domain/services/label_definitions.dart';
import 'package:submersion/features/ocr_import/domain/services/unit_context.dart';
import 'package:submersion/features/ocr_import/domain/services/value_normalizer.dart';

/// Turns positioned OCR text into dive fields.
///
/// Two passes: label-bound values win; a pattern pass fills remaining
/// nulls from self-describing values ("18m", "EAN32"). All output metric.
/// Values that fail plausibility gates are silently dropped to null.
class LogbookParser {
  static const _ftToM = 1 / 3.28084;
  static const _psiToBar = 1 / 14.5038;
  static const _lbsToKg = 0.453592;

  // Plausibility gates (metric).
  static const _maxDepthM = 350.0;
  static const _maxDurationMin = 600;
  static const _waterTempC = (-2.0, 40.0);
  static const _airTempC = (-40.0, 50.0);
  static const _pressureBar = (1.0, 400.0);
  static const _maxWeightKg = 40.0;
  static const _maxDiveNumber = 20000;

  ParsedDiveFields parse(
    OcrResult ocr, {
    required UnitDefaults fallbackUnits,
    required bool preferDayFirst,
  }) {
    if (ocr.isEmpty) return const ParsedDiveFields();

    final units = inferPageUnits(ocr.blocks, fallbackUnits);
    final labels = findLabels(ocr.blocks);
    final labelBlocks = {for (final l in labels) l.block};

    final bound = <LogField, OcrTextBlock>{};
    for (final label in labels) {
      // Notes handled separately (region, not single block).
      if (label.field == LogField.notes) continue;
      if (bound.containsKey(label.field)) continue;
      // Exclude values already consumed by earlier labels so binding
      // falls through to the next-best candidate instead of dropping.
      final value = bindValue(
        label,
        ocr.blocks,
        labelBlocks: {...labelBlocks, ...bound.values},
      );
      if (value != null) {
        bound[label.field] = value;
      }
    }

    final notesLabel = labels
        .where((l) => l.field == LogField.notes)
        .firstOrNull;
    final consumed = bound.values.toSet();
    final notesBlocks = _notesBlocks(notesLabel, ocr.blocks, labelBlocks, {
      ...consumed,
    });
    final notes = notesBlocks.isEmpty
        ? null
        : notesBlocks.map((b) => b.text.trim()).join(' ');

    // --- Quantities from bound labels ---
    var maxDepth = _lengthMeters(bound[LogField.maxDepth], units);
    var startPressure = _pressureToBar(bound[LogField.startPressure], units);
    var endPressure = _pressureToBar(bound[LogField.endPressure], units);
    final waterTemp = _tempCelsius(bound[LogField.waterTemp], units);
    final airTemp = _tempCelsius(bound[LogField.airTemp], units);
    final weight = _weightKg(bound[LogField.weight], units);
    final diveNumber = int.tryParse(
      bound[LogField.diveNumber]?.text.trim() ?? '',
    );
    final rating = int.tryParse(bound[LogField.rating]?.text.trim() ?? '');
    var o2 = bound[LogField.o2Percent] != null
        ? parseO2Percent(bound[LogField.o2Percent]!.text)
        : null;
    var durationMin = bound[LogField.bottomTime] != null
        ? parseDurationToken(bound[LogField.bottomTime]!.text)?.inMinutes
        : null;

    // --- Date and times ---
    var date = bound[LogField.date] != null
        ? parseDateToken(
            bound[LogField.date]!.text,
            preferDayFirst: preferDayFirst,
          )
        : null;
    final timeIn = bound[LogField.timeIn] != null
        ? parseClockToken(bound[LogField.timeIn]!.text)
        : null;
    final timeOut = bound[LogField.timeOut] != null
        ? parseClockToken(bound[LogField.timeOut]!.text)
        : null;
    var hasTimeOfDay = false;
    if (date != null && timeIn != null) {
      date = DateTime(
        date.year,
        date.month,
        date.day,
        timeIn.hour,
        timeIn.minute,
      );
      hasTimeOfDay = true;
    }
    if (durationMin == null && timeIn != null && timeOut != null) {
      var minutes =
          (timeOut.hour * 60 + timeOut.minute) -
          (timeIn.hour * 60 + timeIn.minute);
      if (minutes < 0) minutes += 24 * 60; // dive over midnight
      durationMin = minutes;
    }

    // --- Free text ---
    final siteName = _freeText(bound[LogField.siteName]);
    final locationText = _freeText(bound[LogField.location]);
    final unmapped = <String, String>{};
    for (final (field, key) in [
      (LogField.visibility, 'visibility'),
      (LogField.buddy, 'buddy'),
      (LogField.divemaster, 'divemaster'),
    ]) {
      final raw = bound[field]?.text.trim();
      if (raw != null && raw.isNotEmpty) unmapped[key] = raw;
    }

    // --- Pattern pass: fill nulls from self-describing unbound blocks ---
    final excluded = {...labelBlocks, ...consumed, ...notesBlocks};
    final free = ocr.blocks.where((b) => !excluded.contains(b));
    final freePressures = <double>[];
    for (final b in free) {
      date ??= parseDateToken(b.text, preferDayFirst: preferDayFirst);
      o2 ??= parseO2Percent(b.text);
      final q = parseQuantity(b.text);
      if (q == null || q.unit == null) continue;
      switch (q.unit) {
        case 'm':
          maxDepth ??= q.value;
        case 'ft':
          maxDepth ??= q.value * _ftToM;
        case 'bar':
          freePressures.add(q.value);
        case 'psi':
          freePressures.add(q.value * _psiToBar);
        case 'min':
          durationMin ??= q.value.round();
      }
    }
    if (startPressure == null &&
        endPressure == null &&
        freePressures.isNotEmpty) {
      freePressures.sort();
      startPressure = freePressures.last;
      if (freePressures.length > 1) endPressure = freePressures.first;
    }

    // --- Sanity gates ---
    maxDepth = _gate(maxDepth, 0, _maxDepthM, exclusiveMin: true);
    startPressure = _gate(startPressure, _pressureBar.$1, _pressureBar.$2);
    endPressure = _gate(endPressure, _pressureBar.$1, _pressureBar.$2);
    if (startPressure != null &&
        endPressure != null &&
        startPressure <= endPressure) {
      startPressure = null;
      endPressure = null;
    }
    if (durationMin != null &&
        (durationMin < 1 || durationMin > _maxDurationMin)) {
      durationMin = null;
    }

    return ParsedDiveFields(
      diveNumber:
          (diveNumber != null &&
              diveNumber >= 1 &&
              diveNumber <= _maxDiveNumber)
          ? diveNumber
          : null,
      date: date,
      hasTimeOfDay: hasTimeOfDay,
      durationMinutes: durationMin,
      maxDepthMeters: maxDepth,
      waterTempCelsius: _gate(waterTemp, _waterTempC.$1, _waterTempC.$2),
      airTempCelsius: _gate(airTemp, _airTempC.$1, _airTempC.$2),
      startPressureBar: startPressure,
      endPressureBar: endPressure,
      o2Percent: o2,
      weightKg: _gate(weight, 0, _maxWeightKg, exclusiveMin: true),
      siteName: siteName,
      locationText: locationText,
      notes: notes,
      rating: (rating != null && rating >= 1 && rating <= 5) ? rating : null,
      unmapped: unmapped,
    );
  }

  List<OcrTextBlock> _notesBlocks(
    LabelMatch? notesLabel,
    List<OcrTextBlock> blocks,
    Set<OcrTextBlock> labelBlocks,
    Set<OcrTextBlock> consumed,
  ) {
    if (notesLabel == null) return const [];
    // Comments text may start on the same line as the label, so the
    // region opens half a line above the label's top edge.
    final top =
        notesLabel.block.boundingBox.top - 0.5 * notesLabel.block.height;
    // Template chrome below the notes area (signatures, certification
    // numbers) ends the notes region.
    var cutoff = double.infinity;
    for (final b in blocks) {
      if (b.boundingBox.top > top &&
          labelStopList.any((re) => re.hasMatch(b.text.trim())) &&
          b.boundingBox.top < cutoff) {
        cutoff = b.boundingBox.top;
      }
    }
    final region =
        blocks
            .where(
              (b) =>
                  !identical(b, notesLabel.block) &&
                  b.boundingBox.top > top &&
                  b.boundingBox.top < cutoff &&
                  !labelBlocks.contains(b) &&
                  !consumed.contains(b),
            )
            .toList()
          ..sort((a, b) {
            final byTop = a.boundingBox.top.compareTo(b.boundingBox.top);
            return byTop != 0
                ? byTop
                : a.boundingBox.left.compareTo(b.boundingBox.left);
          });
    return region;
  }

  String? _freeText(OcrTextBlock? block) {
    final text = block?.text.trim();
    if (text == null || text.isEmpty) return null;
    // A bare number is not a site or country name.
    if (parseQuantity(text) != null) return null;
    return text;
  }

  double? _lengthMeters(OcrTextBlock? block, UnitDefaults units) {
    if (block == null) return null;
    final q = parseQuantity(block.text);
    if (q == null) return null;
    return switch (q.unit) {
      'm' => q.value,
      'ft' => q.value * _ftToM,
      null => units.depthFeet ? q.value * _ftToM : q.value,
      _ => null,
    };
  }

  double? _pressureToBar(OcrTextBlock? block, UnitDefaults units) {
    if (block == null) return null;
    final q = parseQuantity(block.text);
    if (q == null) return null;
    return switch (q.unit) {
      'bar' => q.value,
      'psi' => q.value * _psiToBar,
      null => units.pressurePsi ? q.value * _psiToBar : q.value,
      _ => null,
    };
  }

  double? _tempCelsius(OcrTextBlock? block, UnitDefaults units) {
    if (block == null) return null;
    final q = parseQuantity(block.text);
    if (q == null) return null;
    return switch (q.unit) {
      'c' => q.value,
      'f' => (q.value - 32) * 5 / 9,
      null => units.tempFahrenheit ? (q.value - 32) * 5 / 9 : q.value,
      _ => null,
    };
  }

  double? _weightKg(OcrTextBlock? block, UnitDefaults units) {
    if (block == null) return null;
    final q = parseQuantity(block.text);
    if (q == null) return null;
    return switch (q.unit) {
      'kg' => q.value,
      'lbs' => q.value * _lbsToKg,
      null => units.weightLbs ? q.value * _lbsToKg : q.value,
      _ => null,
    };
  }

  double? _gate(
    double? value,
    double min,
    double max, {
    bool exclusiveMin = false,
  }) {
    if (value == null) return null;
    if (exclusiveMin ? value <= min : value < min) return null;
    if (value > max) return null;
    return value;
  }
}

extension<T> on Iterable<T> {
  T? get firstOrNull => isEmpty ? null : first;
}
