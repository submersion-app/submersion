import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/core/constants/units.dart';
import 'package:submersion/core/utils/unit_formatter.dart';
import 'package:submersion/features/media/presentation/widgets/perdix_overlay/perdix_face.dart';
import 'package:submersion/features/media/presentation/widgets/perdix_overlay/perdix_face_resolver.dart';
import 'package:submersion/features/settings/presentation/providers/settings_providers.dart';
import 'package:submersion/l10n/arb/app_localizations.dart';

Widget host(PerdixFace face) => MaterialApp(
  locale: const Locale('en'),
  localizationsDelegates: AppLocalizations.localizationsDelegates,
  supportedLocales: AppLocalizations.supportedLocales,
  home: Scaffold(body: Center(child: face)),
);

Color? textColor(WidgetTester tester, String text) =>
    tester.widget<Text>(find.text(text)).style?.color;

void main() {
  const settings = AppSettings();

  testWidgets('renders full three-row face', (tester) async {
    const data = PerdixFaceData(
      diveTimeSeconds: 1935, // 32:15
      depthMeters: 18.4,
      runningMaxDepthMeters: 24.1,
      ndlSeconds: 24 * 60,
      temperatureCelsius: 22.0,
      gasLabel: 'Air',
      tankPressureBar: 142.0,
      cnsPercent: 8.0,
      ppO2Bar: 0.85,
    );
    await tester.pumpWidget(
      host(const PerdixFace(data: data, settings: settings)),
    );
    expect(find.text('DEPTH'), findsOneWidget);
    expect(find.text('18.4m'), findsOneWidget);
    expect(find.text('NDL'), findsOneWidget);
    expect(find.text('24'), findsOneWidget); // NDL minutes
    expect(find.text('TIME'), findsOneWidget);
    expect(find.text('32:15'), findsOneWidget);
    expect(find.text('MAX'), findsOneWidget);
    expect(find.text('24.1m'), findsOneWidget);
    expect(find.text('TEMP'), findsOneWidget);
    expect(find.text('GAS'), findsOneWidget);
    expect(find.text('Air'), findsOneWidget);
    expect(find.text('TANK'), findsOneWidget);
    expect(find.text('142 bar'), findsOneWidget);
    expect(find.text('CNS'), findsOneWidget);
    expect(find.text('8%'), findsOneWidget);
    expect(find.text('PPO2'), findsOneWidget);
    expect(find.text('0.85'), findsOneWidget);
  });

  testWidgets('third row collapses when tank/cns/ppO2/gas all absent', (
    tester,
  ) async {
    const data = PerdixFaceData(
      diveTimeSeconds: 600,
      depthMeters: 10.0,
      runningMaxDepthMeters: 12.0,
      ndlSeconds: 1800,
      temperatureCelsius: 24.0,
    );
    await tester.pumpWidget(
      host(const PerdixFace(data: data, settings: settings)),
    );
    expect(find.text('TANK'), findsNothing);
    expect(find.text('CNS'), findsNothing);
    expect(find.text('PPO2'), findsNothing);
    expect(find.text('GAS'), findsNothing);
    expect(find.text('MAX'), findsOneWidget);
    expect(find.text('TEMP'), findsOneWidget);
  });

  testWidgets('deco swap: NDL cell becomes STOP, MAX becomes TTS', (
    tester,
  ) async {
    const data = PerdixFaceData(
      diveTimeSeconds: 2400,
      depthMeters: 21.0,
      runningMaxDepthMeters: 45.0,
      ceilingMeters: 5.2, // rounds UP to 6 m stop
      ttsSeconds: 14 * 60,
      inDeco: true,
    );
    await tester.pumpWidget(
      host(const PerdixFace(data: data, settings: settings)),
    );
    expect(find.text('STOP'), findsOneWidget);
    expect(find.text('NDL'), findsNothing);
    expect(find.text('6m'), findsOneWidget);
    expect(find.text('TTS'), findsOneWidget);
    expect(find.text('MAX'), findsNothing);
    expect(find.text('14'), findsOneWidget); // TTS minutes
  });

  testWidgets('NDL color thresholds', (tester) async {
    PerdixFaceData ndl(int seconds) => PerdixFaceData(
      diveTimeSeconds: 0,
      depthMeters: 18.0,
      ndlSeconds: seconds,
    );
    await tester.pumpWidget(
      host(PerdixFace(data: ndl(6 * 60), settings: settings)),
    );
    expect(textColor(tester, '6'), PerdixFace.perdixGreen);
    await tester.pumpWidget(
      host(PerdixFace(data: ndl(4 * 60), settings: settings)),
    );
    expect(textColor(tester, '4'), PerdixFace.perdixYellow);
    await tester.pumpWidget(host(PerdixFace(data: ndl(0), settings: settings)));
    expect(textColor(tester, '0'), PerdixFace.perdixRed);
  });

  testWidgets('ppO2 color thresholds', (tester) async {
    PerdixFaceData ppo2(double v) =>
        PerdixFaceData(diveTimeSeconds: 0, depthMeters: 18.0, ppO2Bar: v);
    await tester.pumpWidget(
      host(PerdixFace(data: ppo2(1.2), settings: settings)),
    );
    expect(textColor(tester, '1.20'), Colors.white);
    await tester.pumpWidget(
      host(PerdixFace(data: ppo2(1.45), settings: settings)),
    );
    expect(textColor(tester, '1.45'), PerdixFace.perdixYellow);
    await tester.pumpWidget(
      host(PerdixFace(data: ppo2(1.65), settings: settings)),
    );
    expect(textColor(tester, '1.65'), PerdixFace.perdixRed);
  });

  testWidgets('imperial units respected, including 10 ft stop rounding', (
    tester,
  ) async {
    const imperial = AppSettings(
      depthUnit: DepthUnit.feet,
      temperatureUnit: TemperatureUnit.fahrenheit,
      pressureUnit: PressureUnit.psi,
    );
    const units = UnitFormatter(imperial);
    const data = PerdixFaceData(
      diveTimeSeconds: 60,
      depthMeters: 18.4,
      runningMaxDepthMeters: 24.1,
      temperatureCelsius: 22.0,
      tankPressureBar: 142.0,
    );
    await tester.pumpWidget(
      host(const PerdixFace(data: data, settings: imperial)),
    );
    expect(find.text(units.formatDepth(18.4)), findsOneWidget);
    expect(find.text(units.formatTemperature(22.0)), findsOneWidget);
    expect(find.text(units.formatPressure(142.0)), findsOneWidget);

    // Deco stop rounding in imperial: 5.2 m ceiling = 17.1 ft -> next 10 ft
    // stop is 20 ft.
    const deco = PerdixFaceData(
      diveTimeSeconds: 60,
      depthMeters: 21.0,
      ceilingMeters: 5.2,
      ttsSeconds: 600,
      inDeco: true,
    );
    await tester.pumpWidget(
      host(const PerdixFace(data: deco, settings: imperial)),
    );
    expect(find.text('20ft'), findsOneWidget);
  });
}
