import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:submersion/core/providers/provider.dart';
import 'package:submersion/core/deco/entities/cns_calculation_method.dart';
import 'package:submersion/features/settings/presentation/pages/settings_page.dart';
import 'package:submersion/features/settings/presentation/providers/settings_providers.dart';
import 'package:submersion/l10n/arb/app_localizations.dart';

/// Minimal fake that only implements the state and the one setter exercised by
/// the CNS method picker. All other [SettingsNotifier] members are unused in
/// this test and are routed through [noSuchMethod].
class _FakeSettingsNotifier extends StateNotifier<AppSettings>
    implements SettingsNotifier {
  _FakeSettingsNotifier() : super(const AppSettings());

  @override
  Future<void> setCnsCalculationMethod(CnsCalculationMethod value) async =>
      state = state.copyWith(cnsCalculationMethod: value);

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

void main() {
  /// Renders the SettingsPage on the mobile decompression detail page via
  /// GoRouter (?selected=decompression), mirroring the harness used by the
  /// Manage/Appearance section tests in settings_page_test.dart.
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
          routerConfig: router,
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
        ),
      ),
    );
  }

  testWidgets('picker lists three methods and applies selection', (
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

    // The tile lives in the Decompression section.
    await tester.scrollUntilVisible(
      find.text('CNS calculation'),
      100.0,
      scrollable: find.byType(Scrollable).first,
    );
    expect(find.text('CNS calculation'), findsOneWidget);

    // Open the picker.
    await tester.tap(find.text('CNS calculation'));
    await tester.pumpAndSettle();

    // All three methods are listed by their localized labels. The current
    // method (shearwater default) also shows as the tile subtitle behind the
    // dialog, so it appears twice.
    expect(find.text('NOAA table, stepped (classic)'), findsOneWidget);
    expect(
      find.text('Linear interpolation (Shearwater-style)'),
      findsNWidgets(2),
    );
    expect(find.text('Exponential fit (as Subsurface)'), findsOneWidget);

    // The historical explanation and disclaimer are present in the dialog.
    expect(find.text('About these methods'), findsOneWidget);
    expect(
      find.textContaining('no affiliation or endorsement is implied'),
      findsOneWidget,
    );

    // Expand "About these methods" to reveal the Sources link rows.
    await tester.tap(find.text('About these methods'));
    await tester.pumpAndSettle();

    expect(find.text('Sources'), findsOneWidget);
    expect(
      find.text('NOAA: Diving Program (publisher of the NOAA Diving Manual)'),
      findsOneWidget,
    );
    expect(find.text('Shearwater: The CNS Oxygen Clock'), findsOneWidget);
    expect(
      find.text('The Theoretical Diver: Calculating oxygen CNS toxicity'),
      findsOneWidget,
    );
    expect(
      find.text('Subsurface: implementation (divelist.cpp)'),
      findsOneWidget,
    );
    // Each source is a tappable row with an external-link affordance.
    expect(find.byIcon(Icons.open_in_new), findsNWidgets(4));

    // Default is shearwater; selecting Subsurface persists via the notifier.
    expect(
      container.read(settingsProvider).cnsCalculationMethod,
      CnsCalculationMethod.shearwater,
    );

    await tester.tap(find.text('Exponential fit (as Subsurface)'));
    await tester.pumpAndSettle();

    expect(
      container.read(settingsProvider).cnsCalculationMethod,
      CnsCalculationMethod.subsurface,
    );
    // Dialog closes after selection.
    expect(find.text('About these methods'), findsNothing);
  });
}
