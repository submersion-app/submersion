import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:submersion/core/providers/provider.dart';
import 'package:submersion/features/dive_sites/presentation/providers/site_providers.dart';
import 'package:submersion/features/dive_sites/presentation/widgets/site_tags_card.dart';
import 'package:submersion/features/tags/domain/entities/tag.dart';
import 'package:submersion/l10n/arb/app_localizations.dart';

/// The Tags card on site detail (issue #1765), the twin of the dive one.
void main() {
  final now = DateTime(2026);

  Tag tag(String id, String name) => Tag(
    id: id,
    name: name,
    createdAt: now,
    updatedAt: now,
    scopes: const {TagScope.dives, TagScope.sites},
  );

  ProviderContainer containerWith(List<Tag> tags) => ProviderContainer(
    overrides: [tagsForSiteProvider('s1').overrideWith((ref) async => tags)],
  );

  Future<void> pump(WidgetTester tester, ProviderContainer container) async {
    final router = GoRouter(
      initialLocation: '/sites/s1',
      routes: [
        GoRoute(path: '/sites', builder: (_, _) => const Text('site list')),
        GoRoute(
          path: '/sites/:id',
          builder: (_, _) => const Scaffold(body: SiteTagsCard(siteId: 's1')),
        ),
      ],
    );
    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: MaterialApp.router(
          routerConfig: router,
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
        ),
      ),
    );
    await tester.pumpAndSettle();
  }

  testWidgets('a card titled Tags, with the count and a chip per tag', (
    tester,
  ) async {
    final container = containerWith([tag('t1', 'To try'), tag('t2', 'Avoid')]);
    addTearDown(container.dispose);
    await pump(tester, container);

    expect(find.byType(Card), findsOneWidget);
    expect(find.text('Tags'), findsOneWidget);
    expect(find.text('2 tags'), findsOneWidget);
    expect(find.widgetWithText(ActionChip, 'To try'), findsOneWidget);
    expect(find.widgetWithText(ActionChip, 'Avoid'), findsOneWidget);
  });

  testWidgets('tapping a tag opens the site list filtered to it', (
    tester,
  ) async {
    final container = containerWith([tag('t1', 'To try')]);
    addTearDown(container.dispose);
    await pump(tester, container);

    await tester.tap(find.text('To try'));
    await tester.pumpAndSettle();

    expect(find.text('site list'), findsOneWidget);
    expect(container.read(siteFilterProvider).tagIds, {'t1'});
    expect(container.read(siteFilterProvider).siteTypeIds, isEmpty);
  });

  testWidgets('the tag filter replaces any filter already set', (tester) async {
    final container = containerWith([tag('t1', 'To try')]);
    addTearDown(container.dispose);
    container.read(siteFilterProvider.notifier).state = const SiteFilterState(
      country: 'Malta',
      siteTypeIds: {'wreck'},
    );
    await pump(tester, container);

    await tester.tap(find.text('To try'));
    await tester.pumpAndSettle();

    final filter = container.read(siteFilterProvider);
    expect(filter.tagIds, {'t1'});
    expect(filter.country, isNull);
    expect(filter.siteTypeIds, isEmpty);
  });

  testWidgets('renders nothing for a site without tags', (tester) async {
    final container = containerWith(const []);
    addTearDown(container.dispose);
    await pump(tester, container);

    expect(find.byType(Card), findsNothing);
    expect(find.text('Tags'), findsNothing);
  });
}
