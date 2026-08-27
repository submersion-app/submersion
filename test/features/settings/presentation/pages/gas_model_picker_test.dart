import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:submersion/core/constants/gas_model.dart';
import 'package:submersion/core/providers/provider.dart';
import 'package:submersion/features/settings/presentation/pages/settings_page.dart';
import 'package:submersion/features/settings/presentation/providers/settings_providers.dart';
import 'package:submersion/l10n/arb/app_localizations.dart';

/// Records what the picker asks the notifier to persist, without touching the
/// database. Everything except the gas model falls through to noSuchMethod.
class _RecordingSettingsNotifier extends StateNotifier<AppSettings>
    implements SettingsNotifier {
  _RecordingSettingsNotifier(super.settings);

  final List<GasModel> saved = [];

  @override
  Future<void> setGasModel(GasModel model) async {
    saved.add(model);
    state = state.copyWith(gasModel: model);
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

void main() {
  late _RecordingSettingsNotifier notifier;

  Widget host(AppSettings settings) {
    notifier = _RecordingSettingsNotifier(settings);
    return ProviderScope(
      overrides: [settingsProvider.overrideWith((ref) => notifier)],
      child: const MaterialApp(
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: SettingsSectionDetailPage(sectionId: 'units'),
      ),
    );
  }

  group('gas model picker (issue #828)', () {
    testWidgets('the units row shows the active model', (tester) async {
      await tester.pumpWidget(host(const AppSettings()));
      await tester.pumpAndSettle();

      await tester.scrollUntilVisible(find.text('Gas calculations'), 50.0);
      await tester.pumpAndSettle();

      expect(find.text('Gas calculations'), findsOneWidget);
      // Default is real gas, so that is what the row reports.
      expect(find.text('Real gas'), findsOneWidget);
      expect(find.text('Ideal gas'), findsNothing);
    });

    testWidgets('the row reports ideal gas once selected', (tester) async {
      await tester.pumpWidget(
        host(const AppSettings(gasModel: GasModel.ideal)),
      );
      await tester.pumpAndSettle();

      await tester.scrollUntilVisible(find.text('Gas calculations'), 50.0);
      await tester.pumpAndSettle();

      expect(find.text('Ideal gas'), findsOneWidget);
      expect(find.text('Real gas'), findsNothing);
    });

    testWidgets('opening the picker explains the consequence', (tester) async {
      await tester.pumpWidget(host(const AppSettings()));
      await tester.pumpAndSettle();

      await tester.scrollUntilVisible(find.text('Gas calculations'), 50.0);
      await tester.pumpAndSettle();
      await tester.tap(find.text('Gas calculations'));
      await tester.pumpAndSettle();

      // The dialog has to say what the choice changes, because the difference
      // between the two answers is what gets reported as a bug.
      expect(
        find.textContaining('How cylinder pressure is converted'),
        findsOneWidget,
      );
      expect(find.textContaining('2317 L'), findsOneWidget);
      expect(find.textContaining('2400 L'), findsOneWidget);
    });

    testWidgets('choosing ideal gas persists it and closes the dialog', (
      tester,
    ) async {
      await tester.pumpWidget(host(const AppSettings()));
      await tester.pumpAndSettle();

      await tester.scrollUntilVisible(find.text('Gas calculations'), 50.0);
      await tester.pumpAndSettle();
      await tester.tap(find.text('Gas calculations'));
      await tester.pumpAndSettle();

      await tester.tap(find.text('Ideal gas'));
      await tester.pumpAndSettle();

      expect(notifier.saved, [GasModel.ideal]);
      expect(find.byType(AlertDialog), findsNothing);
    });

    testWidgets('choosing real gas persists it', (tester) async {
      await tester.pumpWidget(
        host(const AppSettings(gasModel: GasModel.ideal)),
      );
      await tester.pumpAndSettle();

      await tester.scrollUntilVisible(find.text('Gas calculations'), 50.0);
      await tester.pumpAndSettle();
      await tester.tap(find.text('Gas calculations'));
      await tester.pumpAndSettle();

      await tester.tap(find.text('Real gas'));
      await tester.pumpAndSettle();

      expect(notifier.saved, [GasModel.real]);
    });
  });
}
