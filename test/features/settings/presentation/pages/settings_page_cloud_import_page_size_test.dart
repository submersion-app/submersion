import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:submersion/core/providers/provider.dart';
import 'package:go_router/go_router.dart';
import 'package:submersion/features/import_wizard/domain/cloud_import_paging.dart';
import 'package:submersion/features/import_wizard/presentation/providers/cloud_import_page_size_provider.dart';
import 'package:submersion/features/settings/presentation/pages/settings_page.dart';
import 'package:submersion/l10n/arb/app_localizations.dart';

import '../../../../helpers/mock_providers.dart';

void main() {
  Widget buildDataSection(List<Override> overrides) {
    final router = GoRouter(
      initialLocation: '/settings?selected=data',
      routes: [
        GoRoute(
          path: '/settings',
          builder: (context, state) => const SettingsPage(),
        ),
      ],
    );

    return ProviderScope(
      overrides: overrides,
      child: MaterialApp.router(
        locale: const Locale('en'),
        routerConfig: router,
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
      ),
    );
  }

  testWidgets('cloud import page size defaults to 15', (tester) async {
    await tester.binding.setSurfaceSize(const Size(400, 2000));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    await tester.pumpWidget(buildDataSection(await getBaseOverrides()));
    await tester.pumpAndSettle();

    expect(find.text('Cloud import page size'), findsOneWidget);
    expect(find.text('${CloudImportPaging.defaultPageSize}'), findsOneWidget);
  });

  testWidgets('saving a new page size records the preference', (tester) async {
    await tester.binding.setSurfaceSize(const Size(400, 2000));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    final notifier = CloudImportPageSizeNotifier(initial: 15);
    await tester.pumpWidget(
      buildDataSection([
        ...await getBaseOverrides(),
        cloudImportPageSizeProvider.overrideWith((ref) => notifier),
      ]),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.text('Cloud import page size'));
    await tester.pumpAndSettle();

    await tester.enterText(find.byType(TextField), '8');
    await tester.tap(find.text('Save'));
    await tester.pumpAndSettle();

    expect(notifier.state, 8);
    expect(find.text('8'), findsOneWidget);
  });
}
