import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:submersion/core/constants/enums.dart';
import 'package:submersion/core/providers/provider.dart';
import 'package:submersion/features/settings/presentation/pages/settings_page.dart';
import 'package:submersion/features/settings/presentation/providers/settings_providers.dart';
import 'package:submersion/l10n/arb/app_localizations.dart';

class _RecordingSettingsNotifier extends StateNotifier<AppSettings>
    implements SettingsNotifier {
  _RecordingSettingsNotifier(super.settings);

  final List<PlannerWaterType> saved = [];

  @override
  Future<void> setDefaultPlannerWaterType(PlannerWaterType type) async {
    saved.add(type);
    state = state.copyWith(defaultPlannerWaterType: type);
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
      // Pinned to English: every finder below matches on a UI string, so
      // platform-locale resolution would make the test non-deterministic
      // (see test/helpers/test_app.dart).
      child: const MaterialApp(
        locale: Locale('en'),
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: SettingsSectionDetailPage(sectionId: 'units'),
      ),
    );
  }

  testWidgets('the units row shows salt water as the default', (tester) async {
    await tester.pumpWidget(host(const AppSettings()));
    await tester.pumpAndSettle();

    await tester.scrollUntilVisible(find.text('Water type'), 50.0);
    await tester.pumpAndSettle();

    expect(find.text('Water type'), findsOneWidget);
    expect(find.text('Salt Water'), findsOneWidget);
  });

  testWidgets('picking fresh water updates the row', (tester) async {
    await tester.pumpWidget(host(const AppSettings()));
    await tester.pumpAndSettle();

    await tester.scrollUntilVisible(find.text('Water type'), 50.0);
    await tester.pumpAndSettle();
    await tester.tap(find.text('Water type'));
    await tester.pumpAndSettle();

    await tester.tap(find.text('Fresh Water').last);
    await tester.pumpAndSettle();

    expect(notifier.saved, [PlannerWaterType.fresh]);
    expect(find.text('Fresh Water'), findsOneWidget);
    expect(find.text('Salt Water'), findsNothing);
  });

  testWidgets('the units row shows custom when that is the default', (
    tester,
  ) async {
    await tester.pumpWidget(
      host(
        const AppSettings().copyWith(
          defaultPlannerWaterType: PlannerWaterType.custom,
        ),
      ),
    );
    await tester.pumpAndSettle();

    await tester.scrollUntilVisible(find.text('Water type'), 50.0);
    await tester.pumpAndSettle();

    // Units also has a "Custom" visibility-scale option, so this label is
    // not unique on the page. Salt Water must be gone from the water-type row.
    expect(find.text('Custom'), findsWidgets);
    expect(find.text('Salt Water'), findsNothing);
  });

  testWidgets('picking custom updates the row', (tester) async {
    await tester.pumpWidget(host(const AppSettings()));
    await tester.pumpAndSettle();

    await tester.scrollUntilVisible(find.text('Water type'), 50.0);
    await tester.pumpAndSettle();
    await tester.tap(find.text('Water type'));
    await tester.pumpAndSettle();

    await tester.tap(find.text('Custom').last);
    await tester.pumpAndSettle();

    expect(notifier.saved, [PlannerWaterType.custom]);
    expect(find.text('Custom'), findsWidgets);
    expect(find.text('Salt Water'), findsNothing);
  });
}
