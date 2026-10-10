import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:submersion/core/providers/provider.dart';
import 'package:submersion/features/settings/presentation/pages/settings_page.dart';
import 'package:submersion/features/settings/presentation/providers/settings_providers.dart';
import 'package:submersion/l10n/arb/app_localizations.dart';

/// Minimal fake that only implements the state and the one setter exercised by
/// the ICD warnings toggle (issue #3121). All other [SettingsNotifier] members
/// are unused in this test and are routed through [noSuchMethod].
class _FakeSettingsNotifier extends StateNotifier<AppSettings>
    implements SettingsNotifier {
  _FakeSettingsNotifier() : super(const AppSettings());

  @override
  Future<void> setIcdWarningsEnabled(bool value) async =>
      state = state.copyWith(icdWarningsEnabled: value);

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

void main() {
  /// Renders the SettingsPage on the mobile decompression detail page via
  /// GoRouter (?selected=decompression), as cns_method_picker_test.dart does.
  Widget buildDecompressionWidget(ProviderContainer container) {
    final router = GoRouter(
      initialLocation: '/settings?selected=decompression',
      routes: [
        GoRoute(
          path: '/settings',
          builder: (context, state) => const SettingsPage(),
        ),
      ],
    );

    return UncontrolledProviderScope(
      container: container,
      child: MediaQuery(
        data: const MediaQueryData(size: Size(400, 900)),
        child: MaterialApp.router(
          locale: const Locale('en'),
          routerConfig: router,
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
        ),
      ),
    );
  }

  testWidgets('the ICD warnings switch turns the setting off and back on', (
    tester,
  ) async {
    final container = ProviderContainer(
      overrides: [
        settingsProvider.overrideWith((ref) => _FakeSettingsNotifier()),
      ],
    );
    addTearDown(container.dispose);

    await tester.pumpWidget(buildDecompressionWidget(container));
    await tester.pumpAndSettle();

    final tile = find.widgetWithText(SwitchListTile, 'Warn on ICD risk');
    await tester.scrollUntilVisible(
      tile,
      100.0,
      scrollable: find.byType(Scrollable).first,
    );
    expect(tester.widget<SwitchListTile>(tile).value, isTrue);

    await tester.tap(tile);
    await tester.pumpAndSettle();
    expect(container.read(settingsProvider).icdWarningsEnabled, isFalse);
    expect(tester.widget<SwitchListTile>(tile).value, isFalse);

    await tester.tap(tile);
    await tester.pumpAndSettle();
    expect(container.read(settingsProvider).icdWarningsEnabled, isTrue);
  });
}
