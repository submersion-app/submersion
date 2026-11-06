import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/core/deco/entities/deco_status.dart';
import 'package:submersion/core/deco/entities/tissue_compartment.dart';
import 'package:submersion/features/dive_log/presentation/widgets/tissue_tooltip_text.dart';
import 'package:submersion/l10n/arb/app_localizations.dart';

/// Issue #4228: the bar chart, heat map and area chart share one localized
/// tooltip that names each gas's direction and the surface level.
void main() {
  TissueCompartment comp({double pN2 = 0.74, double pHe = 0.0}) =>
      TissueCompartment(
        compartmentNumber: 1,
        halfTimeN2: 4.0,
        halfTimeHe: 1.51,
        mValueAN2: 1.2599,
        mValueBN2: 0.5050,
        mValueAHe: 1.7424,
        mValueBHe: 0.4245,
        currentPN2: pN2,
        currentPHe: pHe,
      );

  DecoStatus statusOf(TissueCompartment c, {double? inspiredN2}) => DecoStatus(
    compartments: [c],
    ndlSeconds: 0,
    ceilingMeters: 0,
    ttsSeconds: 0,
    gfLow: 0.3,
    gfHigh: 0.7,
    decoStops: const [],
    currentDepthMeters: 0,
    ambientPressureBar: 1.0,
    inspiredN2Bar: inspiredN2,
    inspiredHeBar: inspiredN2 == null ? null : 0.0,
  );

  test('an air compartment: one gas, its half-time and the surface level', () {
    final l10n = lookupAppLocalizations(const Locale('en'));
    final c = comp(pN2: 1.2);
    final text = tissueCompartmentTooltip(
      l10n,
      statusOf(c, inspiredN2: 0.74),
      c,
    );

    expect(
      text,
      'Compartment 1\n'
      '${c.percentLoading.toStringAsFixed(1)}% loaded\n'
      // (1.2 - 1.0) / (3.2401 - 1.0) at 1 bar ambient.
      'GF: 9%\n'
      'N₂: 1.20 bar\n'
      'Half-time: 4 min\n'
      'Surface level: 23%\n'
      'Offgassing',
    );
  });

  test('a trimix compartment: each gas with its own direction', () {
    final l10n = lookupAppLocalizations(const Locale('en'));
    final c = comp(pN2: 0.40, pHe: 0.30);
    final text = tissueCompartmentTooltip(
      l10n,
      statusOf(c, inspiredN2: 0.74),
      c,
    );

    expect(text, contains('N₂: 0.40 bar (Ongassing)'));
    expect(text, contains('He: 0.30 bar (Offgassing)'));
    expect(text, contains('Half-time: 4 / 1.5 min'));
  });

  test('leaves directions out when the inspired gas is unknown', () {
    final l10n = lookupAppLocalizations(const Locale('en'));
    final c = comp(pN2: 1.2);
    final text = tissueCompartmentTooltip(l10n, statusOf(c), c);

    expect(text, isNot(contains('gassing')));
    expect(text, isNot(contains('Equilibrium')));
  });

  test('is translated', () {
    final l10n = lookupAppLocalizations(const Locale('de'));
    final c = comp(pN2: 1.2);
    final text = tissueCompartmentTooltip(
      l10n,
      statusOf(c, inspiredN2: 0.74),
      c,
    );

    expect(text, startsWith('Kompartiment 1\n'));
    expect(text, contains('Halbwertszeit: 4 min'));
    expect(text, endsWith('Entsättigung'));
  });
}
