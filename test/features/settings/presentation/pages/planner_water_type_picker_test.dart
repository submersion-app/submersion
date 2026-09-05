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
      child: const MaterialApp(
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
}
