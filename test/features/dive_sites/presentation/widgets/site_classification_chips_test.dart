import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:submersion/core/providers/provider.dart';
import 'package:submersion/features/dive_sites/presentation/providers/site_providers.dart';
import 'package:submersion/features/dive_sites/presentation/widgets/site_classification_chips.dart';
import 'package:submersion/features/site_types/domain/entities/site_type_entity.dart';
import 'package:submersion/features/tags/domain/entities/tag.dart';
import 'package:submersion/l10n/arb/app_localizations.dart';

/// The site detail chip row (issue #1765).
void main() {
  final now = DateTime(2026);

  ProviderContainer containerWith({
    List<SiteTypeEntity> types = const [],
    List<Tag> tags = const [],
  }) => ProviderContainer(
    overrides: [
      siteTypesForSiteProvider('s1').overrideWith((ref) async => types),
      tagsForSiteProvider('s1').overrideWith((ref) async => tags),
    ],
  );

  Future<void> pump(WidgetTester tester, ProviderContainer container) async {
    final router = GoRouter(
      initialLocation: '/sites/s1',
      routes: [
        GoRoute(path: '/sites', builder: (_, _) => const Text('site list')),
        GoRoute(
          path: '/sites/:id',
          builder: (_, _) =>
              const Scaffold(body: SiteClassificationChips(siteId: 's1')),
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

  final wreck = SiteTypeEntity(
    id: 'wreck',
    name: 'Wreck',
    isBuiltIn: true,
    createdAt: now,
    updatedAt: now,
  );
  final toTry = Tag(
    id: 't1',
    name: 'To try',
    createdAt: now,
    updatedAt: now,
    appliesToSites: true,
  );

  testWidgets('shows types then tags', (tester) async {
    final container = containerWith(types: [wreck], tags: [toTry]);
    addTearDown(container.dispose);
    await pump(tester, container);

    expect(find.text('Wreck'), findsOneWidget);
    expect(find.text('To try'), findsOneWidget);
    expect(
      tester.getTopLeft(find.text('Wreck')).dx,
      lessThan(tester.getTopLeft(find.text('To try')).dx),
    );
  });

  testWidgets('tapping a tag opens the site list filtered to it', (
    tester,
  ) async {
    final container = containerWith(types: [wreck], tags: [toTry]);
    addTearDown(container.dispose);
    await pump(tester, container);

    await tester.tap(find.text('To try'));
    await tester.pumpAndSettle();

    expect(find.text('site list'), findsOneWidget);
    expect(container.read(siteFilterProvider).tagIds, {'t1'});
    expect(container.read(siteFilterProvider).siteTypeIds, isEmpty);
  });

  testWidgets('tapping a type opens the site list filtered to it', (
    tester,
  ) async {
    final container = containerWith(types: [wreck]);
    addTearDown(container.dispose);
    await pump(tester, container);

    await tester.tap(find.text('Wreck'));
    await tester.pumpAndSettle();

    expect(container.read(siteFilterProvider).siteTypeIds, {'wreck'});
  });

  testWidgets('renders nothing for a site with no types or tags', (
    tester,
  ) async {
    final container = containerWith();
    addTearDown(container.dispose);
    await pump(tester, container);

    expect(find.byType(ActionChip), findsNothing);
  });
}
