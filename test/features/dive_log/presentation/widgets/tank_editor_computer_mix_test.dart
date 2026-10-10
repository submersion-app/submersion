import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:submersion/core/constants/tank_presets.dart';
import 'package:submersion/core/providers/provider.dart';
import 'package:submersion/features/dive_computer/data/services/computer_mix_reader.dart';
import 'package:submersion/features/dive_log/domain/entities/dive.dart';
import 'package:submersion/features/dive_log/presentation/providers/computer_mix_providers.dart';
import 'package:submersion/features/dive_log/presentation/widgets/tank_editor.dart';
import 'package:submersion/features/divers/presentation/providers/diver_providers.dart';
import 'package:submersion/features/equipment/presentation/providers/equipment_providers.dart';
import 'package:submersion/features/settings/presentation/providers/settings_providers.dart';
import 'package:submersion/features/tank_presets/domain/entities/tank_preset_entity.dart';
import 'package:submersion/features/tank_presets/presentation/providers/tank_preset_providers.dart';
import 'package:submersion/l10n/arb/app_localizations.dart';

import '../../../../helpers/mock_providers.dart';

class _PresetListNotifier
    extends StateNotifier<AsyncValue<List<TankPresetEntity>>>
    implements TankPresetListNotifier {
  _PresetListNotifier(List<TankPresetEntity> presets)
    : super(AsyncValue.data(presets));

  @override
  Future<void> refresh() async {}

  @override
  dynamic noSuchMethod(Invocation invocation) => null;
}

/// Serves a fixed recorded mix and counts the reads.
class _FakeReader implements ComputerMixReader {
  _FakeReader(this.recorded);

  final GasMix? recorded;
  int reads = 0;

  @override
  Future<GasMix?> recordedMix({
    required String diveId,
    required DiveTank tank,
  }) async {
    reads++;
    return recorded;
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

const _recordedTank = DiveTank(
  id: 'tank-1',
  gasMix: GasMix(o2: 32),
  computerId: 'dc1',
  sourceTankIndex: 0,
);

/// Issue #3021: a tank the dive computer recorded says so under its gas
/// fields, and when its mix was changed, offers the computer's back.
void main() {
  Future<AppLocalizations> pump(
    WidgetTester tester, {
    required _FakeReader reader,
    DiveTank tank = _recordedTank,
    String? diveId = 'dive-1',
    void Function(DiveTank)? onChanged,
  }) async {
    SharedPreferences.setMockInitialValues({});
    final prefs = await SharedPreferences.getInstance();
    final presets = TankPresets.all.map(TankPresetEntity.fromBuiltIn).toList();
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          sharedPreferencesProvider.overrideWithValue(prefs),
          settingsProvider.overrideWith((ref) => MockSettingsNotifier()),
          currentDiverIdProvider.overrideWith(
            (ref) => MockCurrentDiverIdNotifier(),
          ),
          tankPresetListNotifierProvider.overrideWith(
            (ref) => _PresetListNotifier(presets),
          ),
          tankPresetsProvider.overrideWith((ref) => Future.value(presets)),
          activeEquipmentProvider.overrideWith((ref) async => const []),
          computerMixReaderProvider.overrideWithValue(reader),
        ].cast(),
        child: MaterialApp(
          locale: const Locale('en'),
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: Scaffold(
            body: SingleChildScrollView(
              child: TankEditor(
                tank: tank,
                tankNumber: 1,
                diveId: diveId,
                onChanged: onChanged ?? (_) {},
              ),
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    return AppLocalizations.of(tester.element(find.byType(TankEditor)));
  }

  final restore = find.byKey(const Key('tank-restore-computer-mix'));

  testWidgets('a mix that matches the computer says it was recorded', (
    tester,
  ) async {
    final l10n = await pump(tester, reader: _FakeReader(const GasMix(o2: 32)));

    expect(find.text(l10n.diveLog_tank_computerMix_matches), findsOneWidget);
    expect(restore, findsNothing);
  });

  testWidgets('an overwritten mix names the computer\'s and restores it', (
    tester,
  ) async {
    DiveTank? changed;
    final l10n = await pump(
      tester,
      reader: _FakeReader(const GasMix(o2: 32)),
      tank: _recordedTank.copyWith(gasMix: const GasMix(o2: 21)),
      onChanged: (t) => changed = t,
    );

    expect(
      find.text(l10n.diveLog_tank_computerMix_differs('EAN32')),
      findsOneWidget,
    );
    await tester.tap(restore);
    await tester.pumpAndSettle();

    expect(changed!.gasMix, const GasMix(o2: 32));
    expect(find.text(l10n.diveLog_tank_computerMix_matches), findsOneWidget);
  });

  testWidgets('typing a different mix offers the computer\'s back', (
    tester,
  ) async {
    final reader = _FakeReader(const GasMix(o2: 32));
    final l10n = await pump(tester, reader: reader);

    await tester.enterText(
      find.widgetWithText(TextFormField, l10n.diveLog_tank_label_o2),
      '28',
    );
    await tester.pumpAndSettle();

    expect(restore, findsOneWidget);
    // Keystrokes do not re-read the raw bytes.
    expect(reader.reads, 1);
  });

  testWidgets('a hand-added tank shows nothing and reads nothing', (
    tester,
  ) async {
    final reader = _FakeReader(const GasMix(o2: 32));
    final l10n = await pump(
      tester,
      reader: reader,
      tank: const DiveTank(id: 'tank-1', gasMix: GasMix(o2: 21)),
    );

    expect(find.text(l10n.diveLog_tank_computerMix_matches), findsNothing);
    expect(restore, findsNothing);
    expect(reader.reads, 0);
  });

  testWidgets('an unknown recorded mix shows nothing', (tester) async {
    final l10n = await pump(tester, reader: _FakeReader(null));

    expect(find.text(l10n.diveLog_tank_computerMix_matches), findsNothing);
    expect(restore, findsNothing);
  });

  testWidgets('a dive not yet saved shows nothing', (tester) async {
    final reader = _FakeReader(const GasMix(o2: 32));
    final l10n = await pump(tester, reader: reader, diveId: null);

    expect(find.text(l10n.diveLog_tank_computerMix_matches), findsNothing);
    expect(reader.reads, 0);
  });
}
