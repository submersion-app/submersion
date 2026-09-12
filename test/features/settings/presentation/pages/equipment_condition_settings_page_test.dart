import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/core/constants/units.dart';
import 'package:submersion/core/providers/provider.dart';
import 'package:submersion/features/divers/presentation/providers/diver_providers.dart';
import 'package:submersion/features/equipment/presentation/providers/equipment_condition_sweep.dart';
import 'package:submersion/features/settings/presentation/pages/equipment_condition_settings_page.dart';
import 'package:submersion/features/settings/presentation/providers/settings_providers.dart';
import 'package:submersion/l10n/arb/app_localizations.dart';

import '../../../../helpers/mock_providers.dart';

/// Counts threshold writes so a single Done action is proven to commit once.
class _CountingSettingsNotifier extends MockSettingsNotifier {
  int coldWrites = 0;

  /// When set, the next cold write throws instead of saving.
  bool failNextColdWrite = false;

  @override
  Future<void> setColdWaterThresholdC(double value) async {
    coldWrites++;
    if (failNextColdWrite) {
      failNextColdWrite = false;
      throw StateError('write failed');
    }
    return super.setColdWaterThresholdC(value);
  }
}

Widget _build(MockSettingsNotifier notifier) => ProviderScope(
  overrides: [settingsProvider.overrideWith((ref) => notifier)],
  child: const MaterialApp(
    locale: Locale('en'),
    localizationsDelegates: AppLocalizations.localizationsDelegates,
    supportedLocales: AppLocalizations.supportedLocales,
    home: EquipmentConditionSettingsPage(),
  ),
);

void main() {
  testWidgets('shows the defaults in metric and saves a new cold line', (
    tester,
  ) async {
    final notifier = _CountingSettingsNotifier();
    await tester.pumpWidget(_build(notifier));
    await tester.pumpAndSettle();

    expect(find.text('Equipment condition'), findsOneWidget);
    expect(find.widgetWithText(TextFormField, '10'), findsOneWidget);
    expect(find.widgetWithText(TextFormField, '30'), findsOneWidget);
    expect(find.widgetWithText(TextFormField, '40'), findsOneWidget);

    await tester.enterText(find.byKey(const Key('threshold-cold')), '8');
    await tester.testTextInput.receiveAction(TextInputAction.done);
    await tester.pumpAndSettle();
    expect(notifier.state.coldWaterThresholdC, 8.0);
    // Done reaches both the submit and the focus-loss path; one write.
    expect(notifier.coldWrites, 1);
  });

  testWidgets('a failed write shows an error and the next Done retries', (
    tester,
  ) async {
    final notifier = _CountingSettingsNotifier()..failNextColdWrite = true;
    await tester.pumpWidget(_build(notifier));
    await tester.pumpAndSettle();

    await tester.enterText(find.byKey(const Key('threshold-cold')), '8');
    await tester.testTextInput.receiveAction(TextInputAction.done);
    await tester.pumpAndSettle();
    expect(find.text('Could not save. Try again.'), findsOneWidget);
    expect(notifier.state.coldWaterThresholdC, 10.0);
    expect(notifier.coldWrites, 1);

    await tester.tap(find.byKey(const Key('threshold-cold')));
    await tester.testTextInput.receiveAction(TextInputAction.done);
    await tester.pumpAndSettle();
    expect(find.text('Could not save. Try again.'), findsNothing);
    expect(notifier.state.coldWaterThresholdC, 8.0);
    expect(notifier.coldWrites, 2);
  });

  testWidgets('imperial divers edit in their units and store metric', (
    tester,
  ) async {
    final notifier = MockSettingsNotifier(
      const AppSettings(
        temperatureUnit: TemperatureUnit.fahrenheit,
        depthUnit: DepthUnit.feet,
      ),
    );
    await tester.pumpWidget(_build(notifier));
    await tester.pumpAndSettle();

    expect(find.widgetWithText(TextFormField, '50'), findsOneWidget);
    expect(find.widgetWithText(TextFormField, '98.4'), findsOneWidget);

    await tester.enterText(find.byKey(const Key('threshold-deep')), '100');
    await tester.testTextInput.receiveAction(TextInputAction.done);
    await tester.pumpAndSettle();
    expect(notifier.state.deepDiveThresholdM, closeTo(30.48, 0.01));
  });

  group('rebuild sensor summaries', () {
    Widget buildWithSweep(
      EquipmentConditionSweep sweep, {
      String? diverId = 'diver-1',
    }) => ProviderScope(
      overrides: [
        settingsProvider.overrideWith((ref) => MockSettingsNotifier()),
        // The rebuild scopes to the active diver. Overridden so the page
        // does not build the real notifier (SharedPreferences and DB), and
        // so the resolved id is the one the sweep is asserted against.
        validatedCurrentDiverIdProvider.overrideWith((ref) async => diverId),
        equipmentConditionSweepProvider.overrideWithValue(sweep),
      ],
      child: const MaterialApp(
        locale: Locale('en'),
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: EquipmentConditionSettingsPage(),
      ),
    );

    testWidgets('runs a forced sweep for the active diver and reports', (
      tester,
    ) async {
      var forced = false;
      String? diverSeen;
      await tester.pumpWidget(
        buildWithSweep(
          _FakeSweep((diverId, force, onProgress) async {
            forced = force;
            diverSeen = diverId;
            onProgress?.call(0, 2);
            onProgress?.call(2, 2);
            return const EquipmentConditionSweepResult(
              swept: 2,
              failed: 0,
              cancelled: false,
            );
          }),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('Rebuild sensor summaries'), findsOneWidget);
      await tester.tap(find.text('Rebuild sensor summaries'));
      await tester.pumpAndSettle();

      expect(forced, isTrue);
      // The resolved active diver, not the raw notifier's starting null:
      // reading that unvalidated would sweep every diver's dives on a
      // shared device whenever the tap beat the async load.
      expect(diverSeen, 'diver-1');
      expect(find.text('Sensor summaries rebuilt'), findsOneWidget);
    });

    testWidgets('a library with no diver still rebuilds, unscoped', (
      tester,
    ) async {
      String? diverSeen = 'unset';
      var ran = false;
      await tester.pumpWidget(
        buildWithSweep(
          _FakeSweep((diverId, force, onProgress) async {
            ran = true;
            diverSeen = diverId;
            return const EquipmentConditionSweepResult(
              swept: 0,
              failed: 0,
              cancelled: false,
            );
          }),
          diverId: null,
        ),
      );
      await tester.pumpAndSettle();
      await tester.tap(find.text('Rebuild sensor summaries'));
      await tester.pumpAndSettle();

      // Dives in a single-diver library carry no diver id, so refusing to
      // run here would leave the action dead for exactly those libraries.
      expect(ran, isTrue);
      expect(diverSeen, isNull);
    });

    Future<void> rebuildReporting(
      WidgetTester tester, {
      required int failedDives,
      required int failedItems,
    }) async {
      await tester.pumpWidget(
        buildWithSweep(
          _FakeSweep(
            (_, _, _) async => EquipmentConditionSweepResult(
              swept: 5,
              failed: failedDives,
              items: 4,
              itemsFailed: failedItems,
              cancelled: false,
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      await tester.tap(find.text('Rebuild sensor summaries'));
      await tester.pumpAndSettle();
    }

    testWidgets('dives that failed to summarise are reported', (tester) async {
      await rebuildReporting(tester, failedDives: 2, failedItems: 0);
      expect(find.text('Sensor summaries rebuilt'), findsNothing);
      expect(
        find.text('Sensor summaries rebuilt; 2 dives could not be summarised'),
        findsOneWidget,
      );
    });

    testWidgets('findings that failed to refresh are reported', (tester) async {
      // The sweep counts them; "rebuilt" alone would hide that the
      // condition findings for those items are still stale.
      await rebuildReporting(tester, failedDives: 0, failedItems: 2);
      expect(find.text('Sensor summaries rebuilt'), findsNothing);
      expect(
        find.text(
          'Sensor summaries rebuilt; condition findings could not be '
          'refreshed for 2 items',
        ),
        findsOneWidget,
      );
    });

    testWidgets('dive and findings failures are both reported', (tester) async {
      await rebuildReporting(tester, failedDives: 1, failedItems: 1);
      expect(
        find.text(
          '1 dive could not be summarised; condition findings could not '
          'be refreshed for 1 item',
        ),
        findsOneWidget,
      );
    });

    testWidgets('a failing sweep shows the failure text', (tester) async {
      await tester.pumpWidget(
        buildWithSweep(
          _FakeSweep((_, _, _) async => throw StateError('no db')),
        ),
      );
      await tester.pumpAndSettle();
      await tester.tap(find.text('Rebuild sensor summaries'));
      await tester.pumpAndSettle();
      expect(
        find.text('Could not rebuild the sensor summaries.'),
        findsOneWidget,
      );
    });
  });

  group('condition engine toggles', () {
    SwitchListTile switchFor(WidgetTester tester, String label) => tester
        .widget<SwitchListTile>(find.widgetWithText(SwitchListTile, label));

    Future<void> pumpTall(WidgetTester tester, MockSettingsNotifier n) async {
      // The page is a ListView; a tall surface builds every tile.
      tester.view.physicalSize = const Size(2400, 9000);
      addTearDown(tester.view.resetPhysicalSize);
      await tester.pumpWidget(_build(n));
      await tester.pumpAndSettle();
    }

    testWidgets('shows the master switch and one per rule, all on', (
      tester,
    ) async {
      await pumpTall(tester, MockSettingsNotifier());
      expect(find.byType(SwitchListTile), findsNWidgets(11));
      expect(find.text('Condition findings'), findsOneWidget);
      expect(find.text('Rules'), findsOneWidget);
      for (final label in [
        'Cell output declining',
        'Cell output low',
        'Cell disagrees with its peers',
        'Cell current-limited at high ppO2',
        'Transmitter dropouts rising',
        'Transmitter dropouts high',
        'Recurring issue',
        'Issues on cold dives',
        'Issues on deep dives',
        'Linked incidents',
      ]) {
        expect(switchFor(tester, label).value, isTrue, reason: label);
        expect(switchFor(tester, label).onChanged, isNotNull, reason: label);
      }
    });

    testWidgets('the master switch writes the setting and locks the rules', (
      tester,
    ) async {
      final notifier = MockSettingsNotifier();
      await pumpTall(tester, notifier);
      await tester.tap(
        find.widgetWithText(SwitchListTile, 'Condition findings'),
      );
      await tester.pumpAndSettle();
      expect(notifier.state.conditionEngineEnabled, isFalse);
      expect(switchFor(tester, 'Condition findings').value, isFalse);
      expect(switchFor(tester, 'Cell output low').onChanged, isNull);
      // A rule's own state survives the master being off.
      expect(switchFor(tester, 'Cell output low').value, isTrue);
    });

    testWidgets('a rule switch records the rule as disabled and back', (
      tester,
    ) async {
      final notifier = MockSettingsNotifier();
      await pumpTall(tester, notifier);
      await tester.tap(find.widgetWithText(SwitchListTile, 'Cell output low'));
      await tester.pumpAndSettle();
      expect(notifier.state.conditionDisabledRules, {'cellOutputLow'});
      expect(switchFor(tester, 'Cell output low').value, isFalse);
      expect(switchFor(tester, 'Cell output declining').value, isTrue);
      await tester.tap(find.widgetWithText(SwitchListTile, 'Cell output low'));
      await tester.pumpAndSettle();
      expect(notifier.state.conditionDisabledRules, isEmpty);
    });

    testWidgets('rules start locked when the master is off', (tester) async {
      await pumpTall(
        tester,
        MockSettingsNotifier(
          const AppSettings(
            conditionEngineEnabled: false,
            conditionDisabledRules: {'incidentLinked'},
          ),
        ),
      );
      expect(switchFor(tester, 'Condition findings').value, isFalse);
      expect(switchFor(tester, 'Linked incidents').value, isFalse);
      expect(switchFor(tester, 'Linked incidents').onChanged, isNull);
      expect(switchFor(tester, 'Recurring issue').onChanged, isNull);
    });
  });
}

class _FakeSweep implements EquipmentConditionSweep {
  final Future<EquipmentConditionSweepResult> Function(
    String? diverId,
    bool force,
    void Function(int, int)? onProgress,
  )
  _run;

  _FakeSweep(this._run);

  @override
  Future<EquipmentConditionSweepResult> run({
    String? diverId,
    List<String>? diveIds,
    bool force = false,
    bool findings = true,
    void Function(int done, int total)? onProgress,
    bool Function()? isCancelled,
  }) => _run(diverId, force, onProgress);
}
