import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/core/providers/provider.dart';
import 'package:submersion/features/tags/data/repositories/tag_repository.dart';
import 'package:submersion/features/tags/domain/entities/tag.dart';
import 'package:submersion/features/tags/presentation/providers/tag_providers.dart';
import 'package:submersion/features/tags/presentation/widgets/tag_form_block.dart';
import 'package:submersion/features/tags/presentation/widgets/tag_input_widget.dart';
import 'package:submersion/l10n/arb/app_localizations.dart';
import 'package:submersion/shared/widgets/forms/form_overline.dart';

/// The tags block shared by the dive and site edit forms (issue #3578).
void main() {
  final now = DateTime(2026);
  Tag tag(String id, String name, Set<TagScope> scopes) =>
      Tag(id: id, name: name, createdAt: now, updatedAt: now, scopes: scopes);

  Widget harness(Widget child, {List<TagStatistic> tagStats = const []}) =>
      ProviderScope(
        overrides: [
          tagListNotifierProvider.overrideWith((ref) => _EmptyTagList(ref)),
          tagStatisticsProvider.overrideWith((ref) async => tagStats),
        ],
        child: MaterialApp(
          locale: const Locale('en'),
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: Scaffold(body: SingleChildScrollView(child: child)),
        ),
      );

  testWidgets('heads the tag field with an overline carrying Browse', (
    tester,
  ) async {
    await tester.pumpWidget(
      harness(
        TagFormBlock(
          label: 'Tags',
          selectedTags: const [],
          onTagsChanged: (_) {},
          scope: TagScope.sites,
        ),
      ),
    );

    expect(find.text('TAGS'), findsOneWidget);
    expect(
      find.descendant(
        of: find.byType(FormOverline),
        matching: find.text('Browse'),
      ),
      findsOneWidget,
    );
    final block = tester.getRect(find.byType(TagFormBlock));
    final field = tester.getRect(find.byType(TagInputWidget));
    expect(field.left - block.left, 14);
    expect(block.right - field.right, 14);
    expect(block.bottom - field.bottom, 12);
  });

  testWidgets('Browse lists only tags of the block scope', (tester) async {
    final night = tag('night', 'Night', {TagScope.dives});
    final avoid = tag('avoid', 'Avoid', {TagScope.sites});
    List<Tag>? reported;
    await tester.pumpWidget(
      harness(
        TagFormBlock(
          label: 'Tags',
          selectedTags: const [],
          onTagsChanged: (tags) => reported = tags,
          scope: TagScope.dives,
        ),
        tagStats: [
          TagStatistic(tag: night, counts: const {TagScope.dives: 2}),
          TagStatistic(
            tag: avoid,
            counts: const {TagScope.dives: 0, TagScope.sites: 4},
          ),
        ],
      ),
    );

    await tester.tap(find.text('Browse'));
    await tester.pumpAndSettle();
    expect(find.widgetWithText(CheckboxListTile, 'Avoid'), findsNothing);

    await tester.tap(find.widgetWithText(CheckboxListTile, 'Night'));
    await tester.pump();
    await tester.tap(find.text('Add 1 tag'));
    await tester.pumpAndSettle();
    expect(reported?.map((t) => t.id), ['night']);
  });
}

class _EmptyTagList extends StateNotifier<AsyncValue<List<Tag>>>
    implements TagListNotifier {
  _EmptyTagList(Ref ref) : super(const AsyncValue.data([]));

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}
