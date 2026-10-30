import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/features/dive_sites/domain/entities/dive_site.dart';
import 'package:submersion/features/dive_sites/presentation/pages/site_detail_page.dart';
import 'package:submersion/features/dive_sites/presentation/providers/site_providers.dart';
import 'package:submersion/l10n/arb/app_localizations.dart';
import 'package:submersion/shared/widgets/markdown_notes/markdown_notes_view.dart';

import '../../../../helpers/mock_providers.dart';

/// #3683: a site's description, notes and access notes draw as Markdown.
void main() {
  testWidgets('description, notes and access notes draw formatted', (
    tester,
  ) async {
    tester.view.devicePixelRatio = 1.0;
    tester.view.physicalSize = const Size(900, 4000);
    addTearDown(tester.view.reset);
    const site = DiveSite(
      id: 'site-1',
      name: 'Hilma Hooker',
      description: '**Wreck** on sand',
      notes: '- moray\n- turtles',
      accessNotes: 'Ladder at *the* pier',
    );
    final overrides = await getBaseOverrides();
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          ...overrides,
          siteProvider(site.id).overrideWith((_) async => site),
          siteDiveCountProvider(site.id).overrideWith((_) async => 0),
        ].cast<Override>(),
        child: const MaterialApp(
          locale: Locale('en'),
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: SiteDetailPage(siteId: 'site-1', embedded: true),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.byType(MarkdownNotesView), findsNWidgets(3));
    final text = tester
        .widgetList<RichText>(
          find.descendant(
            of: find.byType(MarkdownNotesView),
            matching: find.byType(RichText),
          ),
        )
        .map((r) => r.text.toPlainText())
        .join('\n');
    expect(text, contains('Wreck'));
    expect(text, contains('turtles'));
    expect(text, contains('Ladder at the pier'));
    expect(text, isNot(contains('*')));
  });
}
