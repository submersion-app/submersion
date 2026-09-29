import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:submersion/core/constants/enums.dart';
import 'package:submersion/features/certifications/domain/entities/certification.dart';
import 'package:submersion/features/certifications/presentation/providers/certification_providers.dart';
import 'package:submersion/features/certifications/presentation/widgets/certification_search_delegate.dart';

import '../../../../helpers/mock_providers.dart';
import '../../../../helpers/test_app.dart';

final _cert = Certification(
  id: 'c1',
  name: 'Advanced Open Water',
  agency: CertificationAgency.padi,
  createdAt: DateTime(2026, 1, 1),
  updatedAt: DateTime(2026, 1, 1),
);

/// Opens the certification list's search page the way its app bar does,
/// inside a router so a tapped result can navigate.
Future<void> _openSearch(
  WidgetTester tester,
  Future<List<Certification>> Function(String query) search,
) async {
  final router = GoRouter(
    routes: [
      GoRoute(
        path: '/',
        builder: (context, state) => Scaffold(
          body: Consumer(
            builder: (context, ref, _) => ElevatedButton(
              onPressed: () => showSearch(
                context: context,
                delegate: CertificationSearchDelegate(ref),
              ),
              child: const Text('open search'),
            ),
          ),
        ),
      ),
      GoRoute(
        path: '/certifications/:id',
        builder: (context, state) =>
            Text('detail ${state.pathParameters['id']}'),
      ),
    ],
  );
  await tester.pumpWidget(
    testAppRouter(
      router: router,
      locale: const Locale('en'),
      overrides: [
        ...await getBaseOverrides(),
        certificationSearchProvider.overrideWith((ref, q) => search(q)),
      ],
    ),
  );
  await tester.tap(find.text('open search'));
  await tester.pumpAndSettle();
}

Future<void> _type(WidgetTester tester, String text) async {
  await tester.enterText(find.byType(TextField), text);
  await tester.pumpAndSettle();
}

void main() {
  testWidgets('an empty query shows the search hint', (tester) async {
    await _openSearch(tester, (_) async => [_cert]);

    expect(find.text('Search by name, agency, or card number'), findsOneWidget);
    expect(find.text('Advanced Open Water'), findsNothing);
  });

  testWidgets('a query lists the matches, and a tap opens the detail', (
    tester,
  ) async {
    final queries = <String>[];
    await _openSearch(tester, (q) async {
      queries.add(q);
      return [_cert];
    });
    await _type(tester, 'adv');

    expect(queries, contains('adv'));
    expect(find.text('Advanced Open Water'), findsOneWidget);

    await tester.tap(find.text('Advanced Open Water'));
    await tester.pumpAndSettle();

    expect(find.text('detail c1'), findsOneWidget);
  });

  testWidgets('a query with no matches says so', (tester) async {
    await _openSearch(tester, (_) async => []);
    await _type(tester, 'zzz');

    expect(find.text('No certifications found for "zzz"'), findsOneWidget);
  });

  testWidgets('a failed search shows the error', (tester) async {
    await _openSearch(tester, (_) async => throw StateError('boom'));
    await _type(tester, 'adv');

    expect(find.textContaining('boom'), findsOneWidget);
  });

  testWidgets('submitting shows the same results', (tester) async {
    await _openSearch(tester, (_) async => [_cert]);
    await tester.enterText(find.byType(TextField), 'adv');
    await tester.testTextInput.receiveAction(TextInputAction.search);
    await tester.pumpAndSettle();

    expect(find.text('Advanced Open Water'), findsOneWidget);
  });

  testWidgets('clear empties the query, and back closes the search', (
    tester,
  ) async {
    await _openSearch(tester, (_) async => [_cert]);
    await _type(tester, 'adv');

    await tester.tap(find.byTooltip('Clear search'));
    await tester.pumpAndSettle();
    expect(find.text('Search by name, agency, or card number'), findsOneWidget);
    expect(find.byTooltip('Clear search'), findsNothing);

    await tester.tap(find.byIcon(Icons.arrow_back));
    await tester.pumpAndSettle();
    expect(find.text('open search'), findsOneWidget);
  });
}
