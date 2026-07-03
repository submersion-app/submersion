import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/core/providers/provider.dart';
import 'package:submersion/features/settings/presentation/pages/default_visible_metrics_page.dart';
import 'package:submersion/features/settings/presentation/providers/settings_providers.dart';
import 'package:submersion/l10n/arb/app_localizations.dart';

/// Minimal SettingsNotifier stub that mutates in-memory state without touching
/// the database. Only the setters tapped by this test are implemented; every
/// other [SettingsNotifier] member falls through to [noSuchMethod] (never
/// invoked, since the page only takes tear-offs of the untapped setters).
class _StubSettingsNotifier extends StateNotifier<AppSettings>
    implements SettingsNotifier {
  _StubSettingsNotifier() : super(const AppSettings());

  @override
  Future<void> setShowAscentRateColors(bool value) async =>
      state = state.copyWith(showAscentRateColors: value);

  @override
  Future<void> setDefaultShowAscentRateLine(bool value) async =>
      state = state.copyWith(defaultShowAscentRateLine: value);

  @override
  Future<void> setDefaultShowPhotoMarkers(bool value) async =>
      state = state.copyWith(defaultShowPhotoMarkers: value);

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

void main() {
  Widget buildPage(_StubSettingsNotifier notifier) {
    return ProviderScope(
      overrides: [settingsProvider.overrideWith((ref) => notifier)],
      child: const MaterialApp(
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: DefaultVisibleMetricsPage(),
      ),
    );
  }

  testWidgets('shows the renamed Ascent Rate toggle plus the new line toggle', (
    tester,
  ) async {
    await tester.pumpWidget(buildPage(_StubSettingsNotifier()));
    await tester.pumpAndSettle();

    await tester.dragUntilVisible(
      find.text('Ascent Rate'),
      find.byType(Scrollable),
      const Offset(0, -200),
    );
    await tester.pumpAndSettle();

    // The chart-matching labels are present; the old "Ascent Rate Colors"
    // wording is gone.
    expect(find.text('Ascent Rate'), findsOneWidget);
    expect(find.text('Ascent Rate Line'), findsOneWidget);
    expect(find.text('Ascent Rate Colors'), findsNothing);
  });

  testWidgets('both ascent-rate toggles start off', (tester) async {
    await tester.pumpWidget(buildPage(_StubSettingsNotifier()));
    await tester.pumpAndSettle();

    await tester.dragUntilVisible(
      find.text('Ascent Rate'),
      find.byType(Scrollable),
      const Offset(0, -200),
    );
    await tester.pumpAndSettle();

    final switches = tester
        .widgetList<SwitchListTile>(find.byType(SwitchListTile))
        .toList();
    SwitchListTile tileFor(String label) =>
        switches.firstWhere((s) => (s.title as Text).data == label);

    expect(tileFor('Ascent Rate').value, isFalse);
    expect(tileFor('Ascent Rate Line').value, isFalse);
  });

  testWidgets('tapping Ascent Rate Line enables the persisted default', (
    tester,
  ) async {
    final notifier = _StubSettingsNotifier();
    await tester.pumpWidget(buildPage(notifier));
    await tester.pumpAndSettle();

    await tester.dragUntilVisible(
      find.text('Ascent Rate Line'),
      find.byType(Scrollable),
      const Offset(0, -200),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.text('Ascent Rate Line'));
    await tester.pumpAndSettle();

    expect(notifier.state.defaultShowAscentRateLine, isTrue);
  });

  testWidgets('tapping Ascent Rate enables velocity coloring', (tester) async {
    final notifier = _StubSettingsNotifier();
    await tester.pumpWidget(buildPage(notifier));
    await tester.pumpAndSettle();

    await tester.tap(find.text('Ascent Rate'));
    await tester.pumpAndSettle();

    expect(notifier.state.showAscentRateColors, isTrue);
  });

  testWidgets('toggles Photo Markers default', (tester) async {
    await tester.pumpWidget(buildPage(_StubSettingsNotifier()));
    await tester.pumpAndSettle();

    final tile = find.widgetWithText(SwitchListTile, 'Photo Markers');
    await tester.ensureVisible(tile);
    await tester.pumpAndSettle();
    expect(tester.widget<SwitchListTile>(tile).value, isTrue);

    await tester.tap(tile);
    await tester.pumpAndSettle();
    expect(tester.widget<SwitchListTile>(tile).value, isFalse);
  });
}
