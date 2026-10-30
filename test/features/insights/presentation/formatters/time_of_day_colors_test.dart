import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/features/insights/domain/time_of_day_bucket.dart';
import 'package:submersion/features/insights/presentation/formatters/time_of_day_colors.dart';

void main() {
  test('each bucket has its light theme colour', () {
    expect(
      {
        for (final b in TimeOfDayBucket.values)
          b: timeOfDayColor(b.key, Brightness.light),
      },
      const {
        TimeOfDayBucket.dawn: Color(0xFFE67E7D),
        TimeOfDayBucket.morning: Color(0xFFF4B41A),
        TimeOfDayBucket.afternoon: Color(0xFF2E8BC0),
        TimeOfDayBucket.dusk: Color(0xFF845EC2),
        TimeOfDayBucket.night: Color(0xFF14213D),
      },
    );
  });

  test('each bucket has its dark theme colour', () {
    expect(
      {
        for (final b in TimeOfDayBucket.values)
          b: timeOfDayColor(b.key, Brightness.dark),
      },
      const {
        TimeOfDayBucket.dawn: Color(0xFFFF9A9E),
        TimeOfDayBucket.morning: Color(0xFFFFE066),
        TimeOfDayBucket.afternoon: Color(0xFF00D2FC),
        TimeOfDayBucket.dusk: Color(0xFFD387FF),
        TimeOfDayBucket.night: Color(0xFFA2B2C8),
      },
    );
  });

  test('an unknown key is grey, not another bucket', () {
    expect(timeOfDayColor('Evening', Brightness.light), Colors.grey);
    expect(timeOfDayColor('Evening', Brightness.dark), Colors.grey);
  });
}
