import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import 'package:submersion/features/dive_log/domain/entities/dive_computer.dart';
import 'package:submersion/features/dive_log/presentation/providers/dive_computer_providers.dart';
import 'package:submersion/features/transfer/presentation/pages/transfer_page.dart';
import 'package:submersion/l10n/arb/app_localizations.dart';

/// The Dive Computers tab was the last place leaking hardcoded English
/// (#152): its section header, dive count, download tooltip and
/// last-download label all render here.
void main() {
  String? previousDefaultLocale;

  setUp(() {
    previousDefaultLocale = Intl.defaultLocale;
    Intl.defaultLocale = 'en_US';
  });

  tearDown(() {
    Intl.defaultLocale = previousDefaultLocale;
  });

  final now = DateTime(2026, 3, 1, 12);

  DiveComputer computer({
    String id = 'dc-1',
    String name = 'Perdix 2',
    int diveCount = 3,
    DateTime? lastDownload,
  }) => DiveComputer(
    id: id,
    name: name,
    manufacturer: 'Shearwater',
    model: name,
    diveCount: diveCount,
    lastDownload: lastDownload,
    createdAt: now,
    updatedAt: now,
  );

  Future<void> pumpComputersSection(
    WidgetTester tester,
    List<DiveComputer> computers, {
    Locale locale = const Locale('en'),
  }) async {
    await tester.binding.setSurfaceSize(const Size(420, 900));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    final router = GoRouter(
      initialLocation: '/transfer?selected=computers',
      routes: [
        GoRoute(
          path: '/transfer',
          builder: (context, state) => const TransferPage(),
        ),
      ],
    );

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          allDiveComputersProvider.overrideWith((ref) async => computers),
        ],
        child: MaterialApp.router(
          locale: locale,
          routerConfig: router,
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
        ),
      ),
    );
    await tester.pumpAndSettle();
  }

  testWidgets('the known-computers section renders localized strings', (
    tester,
  ) async {
    await pumpComputersSection(tester, [
      computer(lastDownload: DateTime.now().subtract(const Duration(days: 3))),
    ]);

    expect(find.text('Known Computers'), findsOneWidget);
    expect(find.text('3 dives'), findsOneWidget);
    expect(find.text('3 days ago'), findsOneWidget);
    expect(find.byTooltip('Download dives'), findsOneWidget);
  });

  testWidgets('a single dive uses the singular count', (tester) async {
    await pumpComputersSection(tester, [computer(diveCount: 1)]);

    expect(find.text('1 dive'), findsOneWidget);
    expect(
      find.text('Never'),
      findsOneWidget,
      reason: 'a computer with no lastDownload reads Never',
    );
  });

  testWidgets('the section is omitted when no computers are known', (
    tester,
  ) async {
    await pumpComputersSection(tester, const []);

    expect(find.text('Known Computers'), findsNothing);
  });

  testWidgets('the strings follow the locale, not hardcoded English', (
    tester,
  ) async {
    await pumpComputersSection(tester, [
      computer(diveCount: 2),
    ], locale: const Locale('de'));

    expect(find.text('Bekannte Computer'), findsOneWidget);
    expect(find.text('2 Tauchgänge'), findsOneWidget);
    expect(find.text('Nie'), findsOneWidget);
    expect(find.byTooltip('Tauchgänge herunterladen'), findsOneWidget);
  });
}
