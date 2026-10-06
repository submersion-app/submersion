import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:submersion/core/constants/enums.dart';
import 'package:submersion/core/constants/list_view_mode.dart';
import 'package:submersion/core/providers/provider.dart';
import 'package:submersion/features/certifications/domain/entities/certification.dart';
import 'package:submersion/features/certifications/presentation/pages/certification_list_page.dart';
import 'package:submersion/features/certifications/presentation/providers/certification_currency_providers.dart';
import 'package:submersion/features/certifications/presentation/providers/certification_providers.dart';
import 'package:submersion/features/certifications/presentation/providers/certification_query_providers.dart';
import 'package:submersion/l10n/arb/app_localizations.dart';

import '../../../../helpers/mock_providers.dart';

/// The home chip's "needs attention" scope on the certification list (issue
/// #2267): real filter state with a visible, clearable indicator.
Certification _cert(String id, String name) => Certification(
  id: id,
  name: name,
  agency: CertificationAgency.padi.name,
  createdAt: DateTime(2020),
  updatedAt: DateTime(2020),
);

final _certs = [
  _cert('a', 'Alpha Open Water'),
  _cert('b', 'Bravo Rescue'),
  _cert('c', 'Charlie Nitrox'),
];

class _Notifier extends StateNotifier<AsyncValue<List<Certification>>>
    implements CertificationListNotifier {
  _Notifier() : super(AsyncValue.data(_certs));

  @override
  dynamic noSuchMethod(Invocation invocation) => null;
}

Future<ProviderContainer> _pump(
  WidgetTester tester, {
  required Set<String> attention,
  bool scoped = true,
  Future<CurrencyAttention>? pendingAttention,
}) async {
  final overrides = await getBaseOverrides();
  final router = GoRouter(
    initialLocation: '/certifications',
    routes: [
      GoRoute(
        path: '/certifications',
        builder: (_, _) => const CertificationListPage(),
      ),
    ],
  );
  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        ...overrides,
        certificationListNotifierProvider.overrideWith((ref) => _Notifier()),
        certificationListViewModeProvider.overrideWith(
          (ref) => ListViewMode.detailed,
        ),
        currencyAttentionProvider.overrideWith(
          (ref) =>
              pendingAttention ??
              Future.value(
                CurrencyAttention(
                  count: attention.isEmpty ? 0 : 1,
                  certificationIds: attention,
                ),
              ),
        ),
        certificationAttentionFilterProvider.overrideWith((ref) => scoped),
      ].cast(),
      child: MaterialApp.router(
        routerConfig: router,
        locale: const Locale('en'),
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
      ),
    ),
  );
  if (pendingAttention == null) {
    await tester.pumpAndSettle();
  } else {
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 100));
  }
  return ProviderScope.containerOf(tester.element(find.byType(MaterialApp)));
}

void main() {
  testWidgets('the scope shows only certifications needing attention', (
    tester,
  ) async {
    await _pump(tester, attention: {'b'});
    expect(find.text('Bravo Rescue'), findsOneWidget);
    expect(find.text('Alpha Open Water'), findsNothing);
    expect(find.text('Charlie Nitrox'), findsNothing);
  });

  testWidgets('the indicator is visible and clears the scope', (tester) async {
    final container = await _pump(tester, attention: {'b'});
    final chip = find.widgetWithText(InputChip, 'Needs attention');
    expect(chip, findsOneWidget);

    await tester.tap(
      find.descendant(of: chip, matching: find.byIcon(Icons.clear)),
    );
    await tester.pumpAndSettle();

    expect(container.read(certificationAttentionFilterProvider), isFalse);
    expect(find.text('Alpha Open Water'), findsOneWidget);
    expect(find.widgetWithText(InputChip, 'Needs attention'), findsNothing);
  });

  testWidgets('the count subtitle reads shown of total', (tester) async {
    await _pump(tester, attention: {'b'});
    expect(find.textContaining('1 of 3'), findsOneWidget);
  });

  testWidgets('an empty scope explains itself', (tester) async {
    final container = await _pump(tester, attention: const {});
    expect(find.text('No certifications need attention'), findsOneWidget);
    expect(find.textContaining('0 of 3'), findsOneWidget);

    await tester.tap(find.widgetWithText(TextButton, 'Clear'));
    await tester.pumpAndSettle();
    expect(container.read(certificationAttentionFilterProvider), isFalse);
    expect(find.text('Charlie Nitrox'), findsOneWidget);
  });

  testWidgets('the scope waits for currency instead of claiming it is empty', (
    tester,
  ) async {
    // On a cold start the attention set is still loading; an empty set in
    // the meantime would flash "No certifications need attention" and
    // "0 of 3", and a tap on Clear there would drop the scope.
    await _pump(
      tester,
      attention: const {},
      pendingAttention: Completer<CurrencyAttention>().future,
    );
    expect(find.text('No certifications need attention'), findsNothing);
    expect(find.textContaining('0 of 3'), findsNothing);
    expect(find.byType(CircularProgressIndicator), findsOneWidget);
  });

  testWidgets('with the scope off nothing is hidden and no bar shows', (
    tester,
  ) async {
    await _pump(tester, attention: {'b'}, scoped: false);
    expect(find.text('Alpha Open Water'), findsOneWidget);
    expect(find.widgetWithText(InputChip, 'Needs attention'), findsNothing);
  });
}
