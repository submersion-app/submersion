import 'dart:ui';

import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/features/settings/presentation/providers/settings_providers.dart';
import 'package:submersion/features/setup_wizard/domain/unit_preset_detector.dart';

void main() {
  test('US, Liberia, Myanmar map to imperial', () {
    expect(presetForLocale(const Locale('en', 'US')), UnitPreset.imperial);
    expect(presetForLocale(const Locale('en', 'LR')), UnitPreset.imperial);
    expect(presetForLocale(const Locale('my', 'MM')), UnitPreset.imperial);
  });

  test('everything else maps to metric', () {
    expect(presetForLocale(const Locale('de', 'DE')), UnitPreset.metric);
    expect(presetForLocale(const Locale('en', 'GB')), UnitPreset.metric);
    expect(presetForLocale(const Locale('en')), UnitPreset.metric);
  });
}
