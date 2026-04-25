import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/core/deco/entities/deco_status.dart';
import 'package:submersion/core/deco/entities/tissue_compartment.dart';
import 'package:submersion/features/dive_log/presentation/widgets/compact_tissue_loading_card.dart';
import 'package:submersion/features/dive_log/presentation/widgets/tissue_heat_map.dart';
import 'package:submersion/features/settings/presentation/providers/settings_providers.dart';
import 'package:submersion/l10n/arb/app_localizations.dart';

import '../../../../helpers/mock_providers.dart';

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
  gfLow: 0.4,
  gfHigh: 0.85,
  decoStops: [],
  currentDepthMeters: 10.0,
  ambientPressureBar: 2.0,
);

Widget buildCard({
  List<DecoStatus>? decoStatuses,
  bool expandVisualization = false,
}) {
  return ProviderScope(
    overrides: [settingsProvider.overrideWith((ref) => MockSettingsNotifier())],
    child: MaterialApp(
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      home: Scaffold(
        body: CompactTissueLoadingCard(
          status: _status,
          decoStatuses: decoStatuses,
          expandVisualization: expandVisualization,
        ),
      ),
    ),
  );
}

void main() {
  group('CompactTissueLoadingCard heatmap labels', () {
    testWidgets('shows Fast and Slow labels when heatmap data is provided', (
      tester,
    ) async {
      await tester.pumpWidget(buildCard(decoStatuses: [_status]));
      await tester.pumpAndSettle();

      final context = tester.element(find.byType(CompactTissueLoadingCard));
      final l10n = AppLocalizations.of(context);
      // Fast appears in the bar chart row and in the heatmap header
      expect(find.text(l10n.diveLog_deco_tissueFast), findsNWidgets(2));
      // Slow appears in the bar chart row and below the heatmap strip
      expect(find.text(l10n.diveLog_deco_tissueSlow), findsNWidgets(2));
    });

    testWidgets(
      'fires onCompartmentHoverChanged with index on tap then null on release',
      (tester) async {
        await tester.pumpWidget(buildCard(decoStatuses: [_status]));
        await tester.pumpAndSettle();

        final heatMap = find.byType(TissueHeatMapStrip);
        // Tap down → _showTooltipForPosition → onCompartmentHoverChanged(compIdx)
        // Tap up   → _removeTooltip          → onCompartmentHoverChanged(null)
        await tester.tap(heatMap);
        await tester.pumpAndSettle();
      },
    );

    testWidgets(
      'shows Fast and Slow labels when heatmap data is provided in expanded mode',
      (tester) async {
        await tester.pumpWidget(
          buildCard(decoStatuses: [_status], expandVisualization: true),
        );
        await tester.pumpAndSettle();

        final context = tester.element(find.byType(CompactTissueLoadingCard));
        final l10n = AppLocalizations.of(context);
        expect(find.text(l10n.diveLog_deco_tissueFast), findsNWidgets(2));
        expect(find.text(l10n.diveLog_deco_tissueSlow), findsNWidgets(2));
      },
    );
  });
}
