import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/core/constants/gas_consumption_display.dart';
import 'package:submersion/core/utils/unit_formatter.dart';
import 'package:submersion/features/dive_log/data/services/profile_analysis_service.dart';
import 'package:submersion/features/dive_log/domain/entities/dive.dart';
import 'package:submersion/features/dive_log/presentation/utils/sac_rate_display.dart';
import 'package:submersion/features/dive_log/presentation/widgets/sac_segments_view.dart';
import 'package:submersion/features/dive_log/presentation/widgets/sac_time_columns.dart';
import 'package:submersion/features/settings/presentation/providers/settings_providers.dart';
import 'package:submersion/l10n/arb/app_localizations.dart';

SacSegment sacSegment(
  int startMin,
  int endMin, {
  double sacRate = 1.0,
  double avgDepth = 20.0,
  DivePhase? phase,
  String? tankId,
  String? tankName,
  GasMix? gasMix,
}) => SacSegment(
  startTimestamp: startMin * 60,
  endTimestamp: endMin * 60,
  avgDepth: avgDepth,
  minDepth: 0.0,
  maxDepth: 30.0,
  sacRate: sacRate,
  gasConsumed: 1.0,
  phase: phase,
  tankId: tankId,
  tankName: tankName,
  gasMix: gasMix,
);

final sacTimeSegments = [
  sacSegment(0, 5, sacRate: 1.0, avgDepth: 10),
  sacSegment(5, 10, sacRate: 2.0, avgDepth: 20),
  sacSegment(10, 15, sacRate: 0.5, avgDepth: 30),
  sacSegment(15, 20, sacRate: 0.5, avgDepth: 5),
];

final sacPhaseSegments = [
  sacSegment(0, 2, sacRate: 2.0, avgDepth: 12, phase: DivePhase.descent),
  sacSegment(2, 14, sacRate: 1.0, avgDepth: 21, phase: DivePhase.bottom),
  sacSegment(14, 16, sacRate: 0.8, avgDepth: 11, phase: DivePhase.ascent),
  sacSegment(16, 19, sacRate: 0.5, avgDepth: 5, phase: DivePhase.safetyStop),
  sacSegment(19, 20, sacRate: 0.8, avgDepth: 2, phase: DivePhase.ascent),
];

final sacGasSegments = [
  sacSegment(0, 15, sacRate: 1.0, tankId: 'back', tankName: 'Back gas'),
  sacSegment(15, 20, sacRate: 0.5, tankId: 'stage', tankName: 'EAN50'),
];

SacRateDisplay sacRates({
  GasConsumptionLane lane = GasConsumptionLane.rmv,
  double? Function(String?)? volumeFor,
}) => SacRateDisplay(
  units: const UnitFormatter(AppSettings()),
  lane: lane,
  normalizationFactor: 1.0,
  volumeFor: volumeFor ?? (_) => 10.0,
);

Future<void> pumpSacSegmentsView(
  WidgetTester tester, {
  List<SacSegment>? time,
  List<SacSegment>? phases,
  List<SacSegment>? gases,
  SacRateDisplay? rates,
  int? selectedTimestamp,
  Widget? laneSelector,
  double width = 342,
  Locale locale = const Locale('en'),
  TextScaler textScaler = TextScaler.noScaling,
}) {
  return tester.pumpWidget(
    MaterialApp(
      locale: locale,
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      home: MediaQuery(
        data: MediaQueryData(textScaler: textScaler),
        child: Scaffold(
          body: Center(
            child: SizedBox(
              width: width,
              child: SacSegmentsView(
                timeSegments: time ?? sacTimeSegments,
                phaseSegments: phases ?? sacPhaseSegments,
                gasSegments: gases ?? sacGasSegments,
                rates: rates ?? sacRates(),
                selectedTimestamp: selectedTimestamp,
                laneSelector: laneSelector,
              ),
            ),
          ),
        ),
      ),
    ),
  );
}

Text sacText(WidgetTester tester, String value) =>
    tester.widget<Text>(find.text(value));

bool sacIsHighlighted(WidgetTester tester, String label) =>
    sacText(tester, label).style?.fontWeight == FontWeight.bold;

Offset sacColumnCenter(WidgetTester tester, int index, int count) {
  final chart = tester.getRect(find.byKey(SacTimeColumns.plotKey));
  return Offset(
    chart.left + chart.width * (index + 0.5) / count,
    chart.top + 30,
  );
}
