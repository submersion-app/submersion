import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/core/constants/units.dart';
import 'package:submersion/core/providers/provider.dart';
import 'package:submersion/features/dive_log/domain/entities/dive.dart';
import 'package:submersion/features/dive_log/presentation/providers/profile_review_provider.dart';
import 'package:submersion/features/dive_log/presentation/widgets/profile_instrument_bar.dart';
import 'package:submersion/features/dive_log/presentation/widgets/readout_tile.dart';
import 'package:submersion/features/settings/presentation/providers/settings_providers.dart';
import 'package:submersion/l10n/arb/app_localizations.dart';

class _FakeSettingsNotifier extends StateNotifier<AppSettings>
    implements SettingsNotifier {
  _FakeSettingsNotifier([AppSettings? initial])
    : super(initial ?? const AppSettings());

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

/// Unlike [_FakeSettingsNotifier], this actually applies
/// [setFullscreenTilePreferences] to its own state (skipping persistence),
/// so tests can verify the customize sheet reacts to real state changes.
class _SpySettingsNotifier extends StateNotifier<AppSettings>
    implements SettingsNotifier {
  _SpySettingsNotifier([AppSettings? initial])
    : super(initial ?? const AppSettings());

  @override
  Future<void> setFullscreenTilePreferences({
    required List<String> order,
    required List<String> hidden,
  }) async {
    state = state.copyWith(
      fullscreenTileOrder: order,
      fullscreenHiddenTiles: hidden,
    );
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

Dive _recDive() => Dive(
  id: 'd1',
  dateTime: DateTime(2026, 1, 1, 10),
  profile: List.generate(
    61,
    (i) => DiveProfilePoint(timestamp: i * 10, depth: 10, temperature: 20),
  ),
);

Dive _ascentDive() => Dive(
  id: 'd2',
  dateTime: DateTime(2026, 1, 1, 10),
  profile: List.generate(
    61,
    (i) => DiveProfilePoint(timestamp: i * 10, depth: 10, ascentRate: 9.0),
  ),
);

void main() {
  late ProviderContainer container;

  Widget wrap(Dive dive, {AppSettings? settings}) {
    container = ProviderContainer(
      overrides: [
        settingsProvider.overrideWith((ref) => _FakeSettingsNotifier(settings)),
      ],
    );
    return UncontrolledProviderScope(
      container: container,
      child: MaterialApp(
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: Scaffold(
          body: ProfileInstrumentBar(
            diveId: dive.id,
            dive: dive,
            analysis: null,
            tankPressures: null,
          ),
        ),
      ),
    );
  }

  testWidgets('rec dive shows depth, runtime, temperature tiles only', (
    tester,
  ) async {
    await tester.pumpWidget(wrap(_recDive()));
    await tester.pump();
    expect(find.byType(ReadoutTile), findsNWidgets(3));
  });

  testWidgets('tiles update when the review position changes', (tester) async {
    await tester.pumpWidget(wrap(_recDive()));
    await tester.pump();

    container.read(profileReviewProvider('d1').notifier).state = 100;
    await tester.pump();

    // Depth at t=100 for the fixture; assert the formatted value appears.
    // (Fixture: depth 10.0 m at timestamp 100 -> default metric "10.0 m".)
    expect(find.textContaining('10.0'), findsWidgets);
  });

  testWidgets('ascent rate tile shows a per-minute rate, not a bare depth', (
    tester,
  ) async {
    await tester.pumpWidget(wrap(_ascentDive()));
    await tester.pump();

    container.read(profileReviewProvider('d2').notifier).state = 100;
    await tester.pump();

    // 9.0 m/min in metric (default) formats as "9m/min", never a bare "9m".
    expect(find.text('9m/min'), findsOneWidget);
  });

  testWidgets('ascent rate tile respects the depth unit setting', (
    tester,
  ) async {
    await tester.pumpWidget(
      wrap(
        _ascentDive(),
        settings: const AppSettings(depthUnit: DepthUnit.feet),
      ),
    );
    await tester.pump();

    container.read(profileReviewProvider('d2').notifier).state = 100;
    await tester.pump();

    // 9.0 m/min converted to feet/min.
    expect(find.text('30ft/min'), findsOneWidget);
  });

  testWidgets('hidden tiles are not rendered', (tester) async {
    await tester.pumpWidget(
      wrap(
        _recDive(),
        settings: const AppSettings(fullscreenHiddenTiles: ['temperature']),
      ),
    );
    await tester.pump();
    expect(find.byType(ReadoutTile), findsNWidgets(2));
  });

  group('customize sheet', () {
    late ProviderContainer spyContainer;

    Widget wrapWithSpy(Dive dive, {AppSettings? settings}) {
      spyContainer = ProviderContainer(
        overrides: [
          settingsProvider.overrideWith(
            (ref) => _SpySettingsNotifier(settings),
          ),
        ],
      );
      return UncontrolledProviderScope(
        container: spyContainer,
        child: MaterialApp(
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: Scaffold(
            body: ProfileInstrumentBar(
              diveId: dive.id,
              dive: dive,
              analysis: null,
              tankPressures: null,
            ),
          ),
        ),
      );
    }

    testWidgets('opens with one switch per candidate tile', (tester) async {
      await tester.pumpWidget(wrapWithSpy(_recDive()));
      await tester.pump();

      await tester.tap(find.byIcon(Icons.tune));
      await tester.pumpAndSettle();

      expect(find.text('Customize instruments'), findsOneWidget);
      expect(find.byType(SwitchListTile), findsNWidgets(3));
    });

    testWidgets('toggling a switch off hides the tile behind the sheet live', (
      tester,
    ) async {
      await tester.pumpWidget(wrapWithSpy(_recDive()));
      await tester.pump();

      await tester.tap(find.byIcon(Icons.tune));
      await tester.pumpAndSettle();

      await tester.tap(find.widgetWithText(SwitchListTile, 'Temp'));
      await tester.pumpAndSettle();

      // The sheet itself reflects the new hidden state immediately.
      final tile = tester.widget<SwitchListTile>(
        find.widgetWithText(SwitchListTile, 'Temp'),
      );
      expect(tile.value, isFalse);
      expect(
        spyContainer.read(settingsProvider).fullscreenHiddenTiles,
        contains('temperature'),
      );

      // Close the sheet and confirm the instrument bar dropped the tile too.
      await tester.tapAt(const Offset(200, 50));
      await tester.pumpAndSettle();
      expect(find.byType(ReadoutTile), findsNWidgets(2));
    });

    testWidgets('sheet reflects a settings change made while it is open', (
      tester,
    ) async {
      await tester.pumpWidget(wrapWithSpy(_recDive()));
      await tester.pump();

      await tester.tap(find.byIcon(Icons.tune));
      await tester.pumpAndSettle();

      expect(
        tester
            .widget<SwitchListTile>(find.widgetWithText(SwitchListTile, 'Temp'))
            .value,
        isTrue,
      );

      // Simulate an external settings change (e.g. from another surface)
      // while the sheet is still open.
      spyContainer.read(settingsProvider.notifier).state = spyContainer
          .read(settingsProvider)
          .copyWith(fullscreenHiddenTiles: ['temperature']);
      await tester.pump();

      expect(
        tester
            .widget<SwitchListTile>(find.widgetWithText(SwitchListTile, 'Temp'))
            .value,
        isFalse,
      );
    });
  });
}
