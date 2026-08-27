import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/features/ocr_import/domain/models/parsed_dive_fields.dart';

void main() {
  ParsedDiveFields full() => ParsedDiveFields(
    diveNumber: 66,
    date: DateTime(2006, 2, 6, 10, 0),
    hasTimeOfDay: true,
    durationMinutes: 32,
    maxDepthMeters: 21.0,
    waterTempCelsius: 22.8,
    airTempCelsius: 24,
    startPressureBar: 206.8,
    endPressureBar: 110.3,
    o2Percent: 32,
    cylinderVolumeLiters: 11.1,
    weightKg: 2.7,
    siteName: "O'ahu - pipe",
    locationText: 'Hawaii',
    notes: 'humpback whale',
    rating: 5,
    unmapped: const {'visibility': '60 ft'},
  );

  test('value equality covers every field', () {
    expect(full(), full());
    expect(full() == full().copyLike(diveNumber: 67), isFalse);
  });

  test('isEmpty is true only when nothing was extracted', () {
    expect(const ParsedDiveFields().isEmpty, isTrue);
    expect(full().isEmpty, isFalse);
    expect(const ParsedDiveFields(notes: 'x').isEmpty, isFalse);
    expect(const ParsedDiveFields(unmapped: {'buddy': 'Sam'}).isEmpty, isFalse);
  });
}

extension on ParsedDiveFields {
  /// Minimal field-change helper for the equality test.
  ParsedDiveFields copyLike({int? diveNumber}) => ParsedDiveFields(
    diveNumber: diveNumber ?? this.diveNumber,
    date: date,
    hasTimeOfDay: hasTimeOfDay,
    durationMinutes: durationMinutes,
    maxDepthMeters: maxDepthMeters,
    waterTempCelsius: waterTempCelsius,
    airTempCelsius: airTempCelsius,
    startPressureBar: startPressureBar,
    endPressureBar: endPressureBar,
    o2Percent: o2Percent,
    cylinderVolumeLiters: cylinderVolumeLiters,
    weightKg: weightKg,
    siteName: siteName,
    locationText: locationText,
    notes: notes,
    rating: rating,
    unmapped: unmapped,
  );
}
