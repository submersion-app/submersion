// Issue #3482: the import preferences moved off the Data page onto their own
// Import options page under Advanced.

import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/features/dive_sites/domain/matching/site_match_sensitivity.dart';
import 'package:submersion/features/settings/presentation/pages/import_options_page.dart';
import 'package:submersion/features/settings/presentation/widgets/import_preferences_group.dart';

import '../../../../helpers/mock_providers.dart';
import '../../../../helpers/test_app.dart';

void main() {
  Future<void> pumpPage(
    WidgetTester tester, {
    MockSettingsNotifier? settings,
  }) async {
    await tester.pumpWidget(
      testApp(
        overrides: await getBaseOverrides(settingsNotifier: settings),
        child: const ImportOptionsPage(),
      ),
    );
    await tester.pumpAndSettle();
  }

  testWidgets('shows the three import controls', (tester) async {
    await pumpPage(tester);

    expect(find.text('Import options'), findsOneWidget);
    expect(find.byType(ImportPreferencesGroup), findsOneWidget);
    expect(find.text('Auto site matching'), findsOneWidget);
    expect(find.text('Tank pressure at surfacing'), findsOneWidget);
    expect(find.text('Tag imports automatically'), findsOneWidget);
  });

  testWidgets('choosing a site matching level records the preference', (
    tester,
  ) async {
    final settings = MockSettingsNotifier();
    await pumpPage(tester, settings: settings);
    expect(settings.state.siteMatchSensitivity, SiteMatchSensitivity.balanced);

    await tester.tap(find.text('Balanced'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Strict').last);
    await tester.pumpAndSettle();

    expect(settings.state.siteMatchSensitivity, SiteMatchSensitivity.strict);
  });
}
