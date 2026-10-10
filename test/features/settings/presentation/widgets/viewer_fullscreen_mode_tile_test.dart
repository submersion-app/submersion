import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/core/providers/provider.dart';
import 'package:submersion/features/settings/presentation/pages/section_appearance_page.dart';
import 'package:submersion/features/settings/presentation/providers/settings_providers.dart';
import 'package:submersion/features/settings/presentation/providers/viewer_fullscreen_mode_provider.dart';
import 'package:submersion/l10n/arb/app_localizations.dart';

import '../../../../helpers/mock_providers.dart';

/// The Full window / Full screen choice under Appearance > Dives > Dive
/// Profile (#3178). Desktop only: phones and tablets already hide the system
/// bars in these viewers, so the choice would do nothing there.
void main() {
  late ViewerFullscreenModeNotifier modeNotifier;

  Widget buildPage(String sectionKey) {
    modeNotifier = ViewerFullscreenModeNotifier.unstored(
      ViewerFullscreenMode.fullWindow,
    );
    return ProviderScope(
      overrides: [
        settingsProvider.overrideWith((ref) => MockSettingsNotifier()),
        viewerFullscreenModeProvider.overrideWith((ref) => modeNotifier),
      ],
      child: MaterialApp(
        locale: const Locale('en'),
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: SectionAppearancePage(sectionKey: sectionKey),
      ),
    );
  }

  Future<void> pumpPage(WidgetTester tester, String sectionKey) async {
    await tester.binding.setSurfaceSize(const Size(400, 6000));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    await tester.pumpWidget(buildPage(sectionKey));
    await tester.pumpAndSettle();
  }

  final title = find.text('Fullscreen mode');
  final fullWindow = find.text('Full window');
  final fullScreen = find.text('Full screen');

  testWidgets(
    'desktop: the Dive Profile section offers it, Full window selected',
    (tester) async {
      await pumpPage(tester, 'dives');

      expect(title, findsOneWidget);
      expect(fullWindow, findsOneWidget);
      expect(fullScreen, findsOneWidget);
      final segmented = tester.widget<SegmentedButton<ViewerFullscreenMode>>(
        find.byType(SegmentedButton<ViewerFullscreenMode>),
      );
      expect(segmented.selected, {ViewerFullscreenMode.fullWindow});
    },
    variant: TargetPlatformVariant.desktop(),
  );

  testWidgets('desktop: choosing Full screen saves the choice', (tester) async {
    await pumpPage(tester, 'dives');

    await tester.tap(fullScreen);
    await tester.pumpAndSettle();

    expect(modeNotifier.state, ViewerFullscreenMode.fullscreen);
    final segmented = tester.widget<SegmentedButton<ViewerFullscreenMode>>(
      find.byType(SegmentedButton<ViewerFullscreenMode>),
    );
    expect(segmented.selected, {ViewerFullscreenMode.fullscreen});
  }, variant: TargetPlatformVariant.only(TargetPlatform.macOS));

  testWidgets('mobile: the choice is not shown', (tester) async {
    await pumpPage(tester, 'dives');

    expect(find.text('Dive Profile'), findsOneWidget);
    expect(title, findsNothing);
  }, variant: TargetPlatformVariant.mobile());

  testWidgets('desktop: sections without a dive profile do not show it', (
    tester,
  ) async {
    await pumpPage(tester, 'sites');

    expect(title, findsNothing);
  }, variant: TargetPlatformVariant.only(TargetPlatform.macOS));
}
