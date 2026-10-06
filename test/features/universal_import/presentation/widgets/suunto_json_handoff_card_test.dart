import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';

import 'package:submersion/core/services/suunto_cloud/suunto_json_file_reader.dart';
import 'package:submersion/features/import_wizard/presentation/suunto_file_import_navigation.dart';
import 'package:submersion/features/universal_import/presentation/widgets/suunto_json_handoff_card.dart';
import 'package:submersion/l10n/arb/app_localizations.dart';

void main() {
  testWidgets('opens the Suunto file import with the recognised file', (
    tester,
  ) async {
    final bytes = utf8.encode('{"DeviceLog":{}}');
    final router = GoRouter(
      routes: [
        GoRoute(
          path: '/',
          builder: (context, state) => Scaffold(
            body: SuuntoJsonHandoffCard(bytes: bytes, fileName: 'nautic.json'),
          ),
        ),
        GoRoute(
          path: suuntoFileImportPath,
          builder: (context, state) {
            final files = state.extra! as List<SuuntoJsonFile>;
            return Text(
              'opened ${files.length} ${files.single.name} '
              '${files.single.bytes.length}',
            );
          },
        ),
      ],
    );
    addTearDown(router.dispose);

    await tester.pumpWidget(
      MaterialApp.router(
        locale: const Locale('en'),
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        routerConfig: router,
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Suunto dive export recognised'), findsOneWidget);

    await tester.tap(find.byKey(const ValueKey('suunto-json-handoff-import')));
    await tester.pumpAndSettle();

    expect(find.text('opened 1 nautic.json ${bytes.length}'), findsOneWidget);
  });
}
