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
  Widget buildDecompressionWidget(
    ProviderContainer container, {
    ThemeData? theme,
  }) {
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
          theme: theme,
          locale: const Locale('en'),
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

  // The selected row is filled with primaryContainer. A theme where that is a
  // bright accent (the Console dark theme in #2959) made the row's default
  // onSurface text unreadable, and hid the check icon drawn in primary.
  testWidgets('selected method draws its content in onPrimaryContainer', (
    tester,
  ) async {
    const onSurface = Color(0xFFE0E4E8);
    const onPrimaryContainer = Color(0xFF0A1018);
    final theme = ThemeData(
      colorScheme: const ColorScheme.dark(
        primary: Color(0xFF4AE0C0),
        primaryContainer: Color(0xFF4AE0C0),
        onPrimaryContainer: onPrimaryContainer,
        onSurface: onSurface,
      ),
    );
    final container = ProviderContainer(
      overrides: [
        settingsProvider.overrideWith((ref) => _FakeSettingsNotifier()),
      ],
    );
    addTearDown(container.dispose);

    await tester.pumpWidget(buildDecompressionWidget(container, theme: theme));
    await tester.pumpAndSettle();
    await tester.scrollUntilVisible(
      find.text('CNS calculation'),
      100.0,
      scrollable: find.byType(Scrollable).first,
    );
    await tester.tap(find.text('CNS calculation'));
    await tester.pumpAndSettle();

    Text dialogText(String text) => tester.widget<Text>(
      find.descendant(of: find.byType(AlertDialog), matching: find.text(text)),
    );

    // Shearwater is the default, so it is the selected row.
    expect(
      dialogText('Linear interpolation (Shearwater-style)').style?.color,
      onPrimaryContainer,
    );
    expect(
      dialogText(
        'Interpolates between the NOAA limits as documented by Shearwater. '
        'Matches most dive computers.',
      ).style?.color,
      onPrimaryContainer,
    );
    expect(
      tester.widget<Icon>(find.byIcon(Icons.check)).color,
      onPrimaryContainer,
    );

    // Unselected rows keep the ordinary surface foreground.
    expect(dialogText('NOAA table, stepped (classic)').style?.color, onSurface);
  });
}
