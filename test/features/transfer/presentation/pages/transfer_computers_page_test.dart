import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import 'package:submersion/core/router/nav_shortcut_pages.dart';
import 'package:submersion/features/dive_computer/presentation/providers/auto_connect_settings_provider.dart';
import 'package:submersion/features/dive_log/presentation/providers/dive_computer_providers.dart';
import 'package:submersion/features/transfer/presentation/pages/transfer_computers_page.dart';
import 'package:submersion/features/transfer/presentation/widgets/computers_section_content.dart';
import 'package:submersion/l10n/arb/app_localizations.dart';

/// The Dive Computers nav shortcut opens Transfer's section on a page of its
/// own (#4210).
void main() {
  String? previousDefaultLocale;

  setUp(() {
    previousDefaultLocale = Intl.defaultLocale;
    Intl.defaultLocale = 'en_US';
  });

  tearDown(() {
    Intl.defaultLocale = previousDefaultLocale;
  });

  Future<void> pumpShortcut(WidgetTester tester, {Size? size}) async {
    await tester.binding.setSurfaceSize(size ?? const Size(420, 900));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    final router = GoRouter(
      initialLocation: '/shortcut/transfer-computers',
      routes: [
        GoRoute(path: '/', builder: (context, state) => const SizedBox()),
        navShortcutRoute(),
      ],
    );
    addTearDown(router.dispose);

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          allDiveComputersProvider.overrideWith((ref) async => const []),
          // Off: a real scan against no platform channel shows an
          // indeterminate spinner that pumpAndSettle never settles on.
          autoConnectKnownComputersProvider.overrideWith(
            (ref) => AutoConnectKnownComputersNotifier.unstored(false),
          ),
        ],
        child: MaterialApp.router(
          locale: const Locale('en'),
          routerConfig: router,
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
        ),
      ),
    );
    await tester.pumpAndSettle();
  }

  testWidgets('shows the section under its own title, with no back arrow', (
    tester,
  ) async {
    await pumpShortcut(tester);

    expect(find.byType(TransferComputersPage), findsOneWidget);
    expect(find.byType(ComputersSectionContent), findsOneWidget);
    expect(
      find.descendant(
        of: find.byType(AppBar),
        matching: find.text('Dive Computers'),
      ),
      findsOneWidget,
    );
    expect(find.byType(BackButton), findsNothing);
    expect(find.text('Connect New Computer'), findsOneWidget);
  });

  testWidgets('a wide window shows the same page', (tester) async {
    await pumpShortcut(tester, size: const Size(1200, 900));

    expect(find.byType(ComputersSectionContent), findsOneWidget);
    expect(find.byType(BackButton), findsNothing);
  });
}
