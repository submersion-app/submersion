import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/core/providers/provider.dart';
import 'package:submersion/features/dive_sites/presentation/widgets/edit_sections/type_tags_section.dart';
import 'package:submersion/features/site_types/domain/entities/site_type_entity.dart';
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

  Widget harness(Widget child) => ProviderScope(
    overrides: [
      // The tag input reads the tag list; an empty list keeps this test off
      // the database.
      tagListNotifierProvider.overrideWith((ref) => _EmptyTagList(ref)),
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
}

class _EmptyTagList extends StateNotifier<AsyncValue<List<Tag>>>
    implements TagListNotifier {
  _EmptyTagList(Ref ref) : super(const AsyncValue.data([]));

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}
