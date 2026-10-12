import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:submersion/core/providers/provider.dart';
import 'package:submersion/features/documents/domain/entities/document_page.dart';
import 'package:submersion/features/documents/presentation/pages/document_detail_page.dart';
import 'package:submersion/features/documents/presentation/providers/document_providers.dart';
import 'package:submersion/l10n/arb/app_localizations.dart';

import '../../../../helpers/mock_providers.dart';

/// An embedded detail pane is not a page: on a section list pushed over
/// another page, its placeholder bars must not grow a back arrow of their
/// own (#3292).
void main() {
  testWidgets('an embedded not-found document shows no back arrow', (
    tester,
  ) async {
    final router = GoRouter(
      initialLocation: '/root',
      routes: [
        GoRoute(
          path: '/root',
          builder: (_, _) => const Scaffold(body: Text('ROOT')),
        ),
        GoRoute(
          path: '/pane',
          builder: (_, _) => const Scaffold(
            body: DocumentDetailPage(documentId: 'gone', embedded: true),
          ),
        ),
      ],
    );
    addTearDown(router.dispose);

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          ...await getBaseOverrides(),
          documentEntryProvider('gone').overrideWith((ref) async => null),
          documentPagesProvider(
            'gone',
          ).overrideWith((ref) async => const <DocumentPage>[]),
        ].cast(),
        child: MaterialApp.router(
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          routerConfig: router,
        ),
      ),
    );
    router.push('/pane');
    await tester.pumpAndSettle();

    expect(find.byType(BackButton), findsNothing);
  });
}
