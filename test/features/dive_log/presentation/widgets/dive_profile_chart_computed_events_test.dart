import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/core/constants/enums.dart';
import 'package:submersion/core/constants/map_style.dart';
import 'package:submersion/core/providers/provider.dart';
import 'package:submersion/features/dive_log/domain/entities/dive.dart';
import 'package:submersion/features/dive_log/domain/entities/profile_event.dart';
import 'package:submersion/features/dive_log/presentation/providers/profile_legend_provider.dart';
import 'package:submersion/features/dive_log/presentation/widgets/dive_profile_chart.dart';
import 'package:submersion/features/settings/presentation/providers/settings_providers.dart';
import 'package:submersion/l10n/arb/app_localizations.dart';

/// issue #1523 — the "Computed events" legend toggle: on a dive that carries
/// the computer's own events, the app's computed events are hidden by default
/// and can be shown/hidden independently of the plain "Events" toggle.

class _TestSettingsNotifier extends StateNotifier<AppSettings>
    implements SettingsNotifier {
  _TestSettingsNotifier() : super(const AppSettings());

  @override
  Future<void> setMapStyle(MapStyle style) async =>
      state = state.copyWith(mapStyle: style);

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

List<DiveProfilePoint> _profile() => List.generate(41, (i) {
  final t = i * 30;
  final double depth = t < 180
      ? 30.0 * t / 180
      : t < 900
      ? 30
      : t < 1110
      ? 30.0 * (1110 - t) / 210
      : 4;
  return DiveProfilePoint(timestamp: t, depth: depth);
});

ProfileEvent _event(int ts, ProfileEventType type, EventSource source) =>
    ProfileEvent(
      id: 'e$ts',
      diveId: 'd1',
      timestamp: ts,
      eventType: type,
      severity: EventSeverity.warning,
      source: source,
      createdAt: DateTime(2026),
    );

final _container = <ProviderContainer>[];

Widget _chart(List<ProfileEvent> events) {
  return ProviderScope(
    overrides: [
      settingsProvider.overrideWith((ref) => _TestSettingsNotifier()),
    ],
    child: MaterialApp(
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      home: Scaffold(
        body: SizedBox(
          width: 400,
          height: 300,
          child: Consumer(
            builder: (context, ref, _) {
              _container.add(ProviderScope.containerOf(context));
              return DiveProfileChart(profile: _profile(), events: events);
            },
          ),
        ),
      ),
    ),
  );
}

List<VerticalLine> _eventLines(WidgetTester tester) => tester
    .widget<LineChart>(find.byType(LineChart).first)
    .data
    .extraLinesData
    .verticalLines
    .where((l) => l.dashArray != null)
    .toList();

void main() {
  setUp(_container.clear);

  testWidgets(
    'computed events are hidden by default when the dive has imported events',
    (tester) async {
      await tester.pumpWidget(
        _chart([
          _event(300, ProfileEventType.ascentRateWarning, EventSource.imported),
          _event(600, ProfileEventType.ascentRateWarning, EventSource.computed),
        ]),
      );
      await tester.pumpAndSettle();

      // Only the imported event survives the default seed.
      expect(_eventLines(tester), hasLength(1));

      final notifier = _container.first.read(profileLegendProvider.notifier);
      notifier.toggleComputedEvents(); // show computed
      await tester.pumpAndSettle();
      expect(_eventLines(tester), hasLength(2));
    },
  );

  testWidgets('with no imported events, computed events show by default', (
    tester,
  ) async {
    await tester.pumpWidget(
      _chart([
        _event(300, ProfileEventType.ascentRateWarning, EventSource.computed),
        _event(600, ProfileEventType.safetyStopStart, EventSource.computed),
      ]),
    );
    await tester.pumpAndSettle();

    expect(_eventLines(tester), hasLength(2));
  });

  testWidgets('the plain Events toggle still hides everything', (tester) async {
    await tester.pumpWidget(
      _chart([
        _event(300, ProfileEventType.ascentRateWarning, EventSource.imported),
        _event(600, ProfileEventType.ascentRateWarning, EventSource.computed),
      ]),
    );
    await tester.pumpAndSettle();

    final notifier = _container.first.read(profileLegendProvider.notifier);
    notifier.toggleComputedEvents(); // both visible now
    await tester.pumpAndSettle();
    expect(_eventLines(tester), hasLength(2));

    notifier.toggleEvents(); // hide all
    await tester.pumpAndSettle();
    expect(_eventLines(tester), isEmpty);
  });
}
