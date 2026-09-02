import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/core/deco/entities/deco_status.dart';
import 'package:submersion/core/deco/entities/gradient_factor_source.dart';
import 'package:submersion/core/deco/entities/tissue_compartment.dart';
import 'package:submersion/features/dive_log/presentation/widgets/compact_deco_status_card.dart';
import 'package:submersion/features/settings/presentation/providers/settings_providers.dart';
import 'package:submersion/l10n/arb/app_localizations.dart';

import '../../../../helpers/mock_providers.dart';

/// The GF chip must name where its numbers came from (#1047).
///
/// A diver whose computer is set to 45/80 read "GF: 50/85" off their own dive
/// -- the app's default setting, silently substituted because the computer
/// reported no gradient factors. The number was never wrong for what it was;
/// it was unlabelled.
const _comp = TissueCompartment(
  compartmentNumber: 1,
  halfTimeN2: 4.0,
  halfTimeHe: 1.51,
  mValueAN2: 1.2599,
  mValueBN2: 0.5050,
  mValueAHe: 1.7424,
  mValueBHe: 0.4245,
);

const _status = DecoStatus(
  compartments: [_comp],
  ndlSeconds: 600,
  ceilingMeters: 0.0,
  ttsSeconds: 0,
  gfLow: 0.5,
  gfHigh: 0.85,
  decoStops: [],
  currentDepthMeters: 10.0,
  ambientPressureBar: 2.0,
);

Widget buildCard(
  GradientFactorSource gfSource, {
  Locale locale = const Locale('en'),
}) {
  return ProviderScope(
    overrides: [settingsProvider.overrideWith((ref) => MockSettingsNotifier())],
    child: MaterialApp(
      // Pinned: an unpinned MaterialApp resolves against the host
      // machine's locale list, so English label assertions below fail
      // on a non-English dev machine.
      locale: locale,
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      home: Scaffold(
        body: CompactDecoStatusCard(status: _status, gfSource: gfSource),
      ),
    ),
  );
}

void main() {
  testWidgets('shows the computer\'s gradient factors unqualified', (
    tester,
  ) async {
    await tester.pumpWidget(
      buildCard(
        const GradientFactorSource(
          low: 45,
          high: 80,
          origin: GfOrigin.computer,
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('GF: 45/80'), findsOneWidget);
  });

  testWidgets('qualifies gradient factors that came from the diver settings', (
    tester,
  ) async {
    await tester.pumpWidget(
      buildCard(
        const GradientFactorSource(
          low: 50,
          high: 85,
          origin: GfOrigin.diverSettings,
        ),
      ),
    );
    await tester.pumpAndSettle();

    // The bare "GF: 50/85" is exactly what misled the reporter.
    expect(find.text('GF: 50/85'), findsNothing);
    expect(find.textContaining('50/85'), findsOneWidget);
    expect(find.textContaining('your settings'), findsOneWidget);
  });

  testWidgets('names a recorded non-GF deco model instead of implying GF', (
    tester,
  ) async {
    await tester.pumpWidget(
      buildCard(
        const GradientFactorSource(
          low: 50,
          high: 85,
          origin: GfOrigin.diverSettings,
          recordedAlgorithm: 'vpm',
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.textContaining('VPM'), findsOneWidget);
    expect(find.textContaining('50/85'), findsOneWidget);
  });

  testWidgets('speaks the gradient factors in the app locale, not a mix', (
    tester,
  ) async {
    await tester.pumpWidget(
      buildCard(
        const GradientFactorSource(
          low: 50,
          high: 85,
          origin: GfOrigin.diverSettings,
        ),
        locale: const Locale('de'),
      ),
    );
    await tester.pumpAndSettle();

    final labels = tester
        .widgetList<Semantics>(find.byType(Semantics))
        .map((s) => s.properties.label)
        .whereType<String>()
        .toList();

    // German throughout: an English lead-in stitched to a translated
    // qualifier is what a screen reader would otherwise announce.
    expect(labels.where((l) => l.contains('Gradientenfaktoren')), hasLength(1));
    expect(labels.where((l) => l.contains('Gradient factors')), isEmpty);
  });

  testWidgets('normalizes a recorded model name for display', (tester) async {
    await tester.pumpWidget(
      buildCard(
        const GradientFactorSource(
          low: 50,
          high: 85,
          origin: GfOrigin.diverSettings,
          recordedAlgorithm: ' vpm-b ',
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.textContaining('VPM-B'), findsOneWidget);
  });

  testWidgets('does not name a recorded Buhlmann model, which is what the app '
      'computes anyway', (tester) async {
    await tester.pumpWidget(
      buildCard(
        const GradientFactorSource(
          low: 45,
          high: 80,
          origin: GfOrigin.computer,
          recordedAlgorithm: 'buhlmann',
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('GF: 45/80'), findsOneWidget);
    expect(find.textContaining('BUHLMANN'), findsNothing);
  });
}
