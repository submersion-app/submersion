import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/core/providers/provider.dart';
import 'package:submersion/features/dive_sites/presentation/widgets/edit_sections/type_tags_section.dart';
import 'package:submersion/features/site_types/domain/entities/site_type_entity.dart';
import 'package:submersion/features/tags/data/repositories/tag_repository.dart';
import 'package:submersion/features/tags/domain/entities/tag.dart';
import 'package:submersion/features/tags/presentation/providers/tag_providers.dart';
import 'package:submersion/l10n/arb/app_localizations.dart';

/// The site edit page's Type & Tags section (issue #1765).
void main() {
  final now = DateTime(2026);
  final types = [
    SiteTypeEntity(
      id: 'wreck',
      name: 'Wreck',
      isBuiltIn: true,
      createdAt: now,
      updatedAt: now,
    ),
    SiteTypeEntity(
      id: 'lake',
      name: 'Lake',
      isBuiltIn: true,
      createdAt: now,
      updatedAt: now,
    ),
    SiteTypeEntity(
      id: 'mine',
      diverId: 'diver-1',
      name: 'Mine',
      createdAt: now,
      updatedAt: now,
    ),
  ];

  Widget harness(Widget child, {List<TagStatistic> tagStats = const []}) =>
      ProviderScope(
        overrides: [
          // The tag input reads the tag list; an empty list keeps this test off
          // the database.
          tagListNotifierProvider.overrideWith((ref) => _EmptyTagList(ref)),
          // The Browse sheet reads the usage statistics.
          tagStatisticsProvider.overrideWith((ref) async => tagStats),
        ],
        child: MaterialApp(
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: Scaffold(body: SingleChildScrollView(child: child)),
        ),
      );

  testWidgets('shows every type, built-ins translated, custom by name', (
    tester,
  ) async {
    await tester.pumpWidget(
      harness(
        TypeTagsSection(
          allTypes: types,
          selectedTypeIds: const {},
          onTypesChanged: (_) {},
          selectedTags: const [],
          onTagsChanged: (_) {},
        ),
      ),
    );

    expect(find.text('Type & Tags'), findsOneWidget);
    expect(find.widgetWithText(FilterChip, 'Wreck'), findsOneWidget);
    expect(find.widgetWithText(FilterChip, 'Lake'), findsOneWidget);
    expect(find.widgetWithText(FilterChip, 'Mine'), findsOneWidget);
    expect(find.text('Manage types'), findsNothing);
  });

  testWidgets('toggling a type chip reports the new selection', (tester) async {
    Set<String>? reported;
    await tester.pumpWidget(
      harness(
        TypeTagsSection(
          allTypes: types,
          selectedTypeIds: const {'wreck'},
          onTypesChanged: (ids) => reported = ids,
          selectedTags: const [],
          onTagsChanged: (_) {},
        ),
      ),
    );

    await tester.tap(find.widgetWithText(FilterChip, 'Lake'));
    await tester.pump();
    expect(reported, {'wreck', 'lake'});

    await tester.tap(find.widgetWithText(FilterChip, 'Wreck'));
    await tester.pump();
    expect(reported, isEmpty);
  });

  testWidgets('the manage link appears when a handler is given', (
    tester,
  ) async {
    var tapped = false;
    await tester.pumpWidget(
      harness(
        TypeTagsSection(
          allTypes: types,
          selectedTypeIds: const {},
          onTypesChanged: (_) {},
          selectedTags: const [],
          onTagsChanged: (_) {},
          onManageTypes: () => tapped = true,
        ),
      ),
    );

    await tester.tap(find.text('Manage types'));
    expect(tapped, isTrue);
  });

  testWidgets('Browse picks from the site tags, as dive edit does', (
    tester,
  ) async {
    Tag tag(String id, String name, {bool dives = false, bool sites = true}) =>
        Tag(
          id: id,
          name: name,
          createdAt: now,
          updatedAt: now,
          scopes: {if (dives) TagScope.dives, if (sites) TagScope.sites},
        );
    final avoid = tag('avoid', 'Avoid');
    final toTry = tag('try', 'To try');
    final night = tag('night', 'Night', dives: true, sites: false);
    List<Tag>? reported;
    await tester.pumpWidget(
      harness(
        TypeTagsSection(
          allTypes: types,
          selectedTypeIds: const {},
          onTypesChanged: (_) {},
          selectedTags: [avoid],
          onTagsChanged: (tags) => reported = tags,
        ),
        tagStats: [
          TagStatistic(tag: night, counts: const {TagScope.dives: 9}),
          TagStatistic(
            tag: toTry,
            counts: const {TagScope.dives: 0, TagScope.sites: 3},
          ),
          TagStatistic(
            tag: avoid,
            counts: const {TagScope.dives: 0, TagScope.sites: 1},
          ),
        ],
      ),
    );

    await tester.tap(find.text('Browse'));
    await tester.pumpAndSettle();

    // Only site tags, minus the one the site already has.
    expect(find.widgetWithText(CheckboxListTile, 'To try'), findsOneWidget);
    expect(find.widgetWithText(CheckboxListTile, 'Night'), findsNothing);
    expect(find.widgetWithText(CheckboxListTile, 'Avoid'), findsNothing);

    await tester.tap(find.widgetWithText(CheckboxListTile, 'To try'));
    await tester.pump();
    await tester.tap(find.text('Add 1 tag'));
    await tester.pumpAndSettle();

    expect(reported?.map((t) => t.id), ['avoid', 'try']);
    expect(find.byType(CheckboxListTile), findsNothing, reason: 'sheet closed');
  });
}

class _EmptyTagList extends StateNotifier<AsyncValue<List<Tag>>>
    implements TagListNotifier {
  _EmptyTagList(Ref ref) : super(const AsyncValue.data([]));

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}
