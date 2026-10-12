import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import 'package:submersion/core/providers/provider.dart';
import 'package:submersion/features/cylinder_passports/domain/entities/passport_usage.dart';
import 'package:submersion/features/cylinder_passports/presentation/providers/cylinder_passport_providers.dart';
import 'package:submersion/features/cylinder_passports/presentation/widgets/passport_usage_card.dart';
import 'package:submersion/l10n/arb/app_localizations.dart';

import '../../../../helpers/mock_providers.dart';

/// The dives a tagged cylinder was used on, on its passports (#2650).
void main() {
  late String? savedIntlLocale;
  setUp(() {
    savedIntlLocale = Intl.defaultLocale;
    Intl.defaultLocale = 'en_US';
  });
  tearDown(() => Intl.defaultLocale = savedIntlLocale);

  List<PassportUsageDive> dives(int n) => [
    for (var i = 0; i < n; i++)
      PassportUsageDive(
        diveId: 'd$i',
        dateTime: DateTime.utc(2026, 3, 12 - i),
        diveNumber: 40 - i,
        siteName: i == 0 ? 'Bari Reef' : null,
      ),
  ];

  // Each row is keyed by its dive.
  final rows = find.byWidgetPredicate(
    (w) =>
        w.key is ValueKey<String> &&
        (w.key! as ValueKey<String>).value.startsWith('passport_usage_row_'),
  );

  Future<(AppLocalizations, List<String>)> pump(
    WidgetTester tester, {
    required Future<List<PassportUsageDive>> Function() usage,
    PassportUsageTitle title = PassportUsageTitle.foreign,
  }) async {
    tester.view.devicePixelRatio = 1.0;
    tester.view.physicalSize = const Size(600, 1600);
    addTearDown(tester.view.reset);
    final pushed = <String>[];
    final router = GoRouter(
      routes: [
        GoRoute(
          path: '/',
          builder: (_, _) => Scaffold(
            body: SingleChildScrollView(
              child: PassportUsageCard(passportId: 'p-1', title: title),
            ),
          ),
        ),
        GoRoute(
          path: '/dives/:diveId',
          builder: (_, state) {
            pushed.add(state.pathParameters['diveId']!);
            return const Scaffold();
          },
        ),
      ],
    );
    final overrides = await getBaseOverrides();
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          ...overrides,
          passportUsageProvider('p-1').overrideWith((ref) => usage()),
        ].cast(),
        child: MaterialApp.router(
          locale: const Locale('en'),
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          routerConfig: router,
        ),
      ),
    );
    await tester.pumpAndSettle();
    return (
      AppLocalizations.of(tester.element(find.byType(Scaffold).first)),
      pushed,
    );
  }

  testWidgets('hidden when the cylinder was never used', (tester) async {
    await pump(tester, usage: () async => const []);
    expect(find.byType(Card), findsNothing);
  });

  testWidgets('foreign: the count heads the card, rows newest first', (
    tester,
  ) async {
    final (l10n, _) = await pump(tester, usage: () async => dives(3));
    expect(find.text(l10n.passport_usage_foreignTitle(3)), findsOneWidget);
    expect(find.text(l10n.passport_usage_title), findsNothing);
    expect(
      find.text(l10n.passport_usage_lastUsed('Mar 12, 2026')),
      findsOneWidget,
    );
    expect(rows, findsNWidgets(3));
    expect(find.text('Bari Reef'), findsOneWidget);
    expect(find.text(l10n.passport_usage_noSite), findsNWidgets(2));
    expect(
      find.textContaining(l10n.passport_usage_diveNumber(40)),
      findsOneWidget,
    );
    // Newest first: the Bari Reef dive (Mar 12) sits above the others.
    expect(
      tester.getTopLeft(find.text('Bari Reef')).dy,
      lessThan(
        tester.getTopLeft(find.text(l10n.passport_usage_noSite).first).dy,
      ),
    );
  });

  testWidgets('own: a Dives section with the count under it', (tester) async {
    final (l10n, _) = await pump(
      tester,
      usage: () async => dives(2),
      title: PassportUsageTitle.own,
    );
    expect(find.text(l10n.passport_usage_title), findsOneWidget);
    expect(find.text(l10n.passport_usage_ownTitle(2)), findsOneWidget);
    expect(find.text(l10n.passport_usage_foreignTitle(2)), findsNothing);
  });

  testWidgets('five rows, then Show all expands in place', (tester) async {
    final (l10n, _) = await pump(tester, usage: () async => dives(7));
    expect(rows, findsNWidgets(5));
    await tester.tap(find.text(l10n.passport_usage_showAll(7)));
    await tester.pumpAndSettle();
    expect(rows, findsNWidgets(7));
    expect(find.text(l10n.passport_usage_showAll(7)), findsNothing);
  });

  testWidgets('exactly five rows offer no Show all', (tester) async {
    final (l10n, _) = await pump(tester, usage: () async => dives(5));
    expect(rows, findsNWidgets(5));
    expect(find.text(l10n.passport_usage_showAll(5)), findsNothing);
  });

  testWidgets('a row opens its dive', (tester) async {
    final (_, pushed) = await pump(tester, usage: () async => dives(1));
    await tester.tap(find.text('Bari Reef'));
    await tester.pumpAndSettle();
    expect(pushed, ['d0']);
  });

  testWidgets('a load error shows one line', (tester) async {
    final (l10n, _) = await pump(
      tester,
      usage: () async => throw StateError('database is locked'),
    );
    expect(find.text(l10n.passport_usage_loadFailed), findsOneWidget);
    expect(rows, findsNothing);
  });
}
