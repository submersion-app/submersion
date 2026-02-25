import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mockito/annotations.dart';
import 'package:mockito/mockito.dart';
import 'package:submersion/core/providers/provider.dart';
import 'package:submersion/features/tags/data/repositories/tag_repository.dart';
import 'package:submersion/features/tags/domain/entities/tag.dart';
import 'package:submersion/features/tags/presentation/providers/tag_providers.dart';
import 'package:submersion/features/tags/presentation/widgets/tag_input_widget.dart';
import 'package:submersion/features/tags/presentation/widgets/tag_merge_sheet.dart';
import 'package:submersion/l10n/arb/app_localizations.dart';

@GenerateMocks([TagRepository])
import 'tag_merge_sheet_test.mocks.dart';

/// Mock TagListNotifier that tracks mergeTags calls without database access.
class MockTagListNotifier extends StateNotifier<AsyncValue<List<Tag>>>
    implements TagListNotifier {
  MockTagListNotifier() : super(const AsyncValue.data([]));

  bool mergeTagsCalled = false;
  List<String>? lastSourceTagIds;
  String? lastSurvivingTagId;
  String? lastName;
  String? lastColorHex;

  @override
  Future<void> mergeTags({
    required List<String> sourceTagIds,
    required String survivingTagId,
    required String name,
    required String? colorHex,
  }) async {
    mergeTagsCalled = true;
    lastSourceTagIds = sourceTagIds;
    lastSurvivingTagId = survivingTagId;
    lastName = name;
    lastColorHex = colorHex;
  }

  @override
  Future<Tag> addTag(Tag tag) async => tag;
  @override
  Future<Tag> getOrCreateTag(String name, {String? colorHex}) async =>
      Tag.create(id: 'new', name: name, colorHex: colorHex);
  @override
  Future<void> updateTag(Tag tag) async {}
  @override
  Future<void> deleteTag(String id) async {}
  @override
  Future<void> deleteTags(List<String> ids) async {}
  @override
  Future<void> setTagsForDive(String diveId, List<Tag> tags) async {}
  @override
  Future<void> addTagToDive(String diveId, String tagId) async {}
  @override
  Future<void> removeTagFromDive(String diveId, String tagId) async {}
  @override
  Future<void> refresh() async {}
}

void main() {
  late MockTagRepository mockRepository;
  late MockTagListNotifier mockNotifier;

  final testStats = [
    TagStatistic(
      tag: Tag(
        id: 'tag1',
        diverId: 'diver1',
        name: 'Night Dive',
        colorHex: '#EF4444',
        createdAt: DateTime(2024),
        updatedAt: DateTime(2024),
      ),
      diveCount: 12,
    ),
    TagStatistic(
      tag: Tag(
        id: 'tag2',
        diverId: 'diver1',
        name: 'Night',
        colorHex: '#3B82F6',
        createdAt: DateTime(2024),
        updatedAt: DateTime(2024),
      ),
      diveCount: 3,
    ),
    TagStatistic(
      tag: Tag(
        id: 'tag3',
        diverId: 'diver1',
        name: 'Evening Dive',
        colorHex: '#22C55E',
        createdAt: DateTime(2024),
        updatedAt: DateTime(2024),
      ),
      diveCount: 1,
    ),
  ];

  setUp(() {
    mockRepository = MockTagRepository();
    mockNotifier = MockTagListNotifier();

    when(mockRepository.getMergedDiveCount(any)).thenAnswer((_) async => 14);
  });

  Widget buildTestWidget({List<TagStatistic>? stats}) {
    return ProviderScope(
      overrides: [
        tagRepositoryProvider.overrideWithValue(mockRepository),
        tagListNotifierProvider.overrideWith((ref) => mockNotifier),
      ],
      child: MaterialApp(
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: Scaffold(body: TagMergeSheet(selectedStats: stats ?? testStats)),
      ),
    );
  }

  group('TagMergeSheet', () {
    testWidgets('pre-populates name field with most-used tag name', (
      tester,
    ) async {
      await tester.pumpWidget(buildTestWidget());
      await tester.pumpAndSettle();

      // The most-used tag is "Night Dive" with 12 dives
      final textField = tester.widget<TextField>(find.byType(TextField));
      expect(textField.controller!.text, 'Night Dive');
    });

    testWidgets('radio buttons switch the name field', (tester) async {
      await tester.pumpWidget(buildTestWidget());
      await tester.pumpAndSettle();

      // Initially "Night Dive" is selected (most-used)
      final textFieldBefore = tester.widget<TextField>(find.byType(TextField));
      expect(textFieldBefore.controller!.text, 'Night Dive');

      // Tap the "Night" radio button to switch
      final nightRadio = find.text('Night');
      expect(nightRadio, findsOneWidget);
      await tester.tap(nightRadio);
      await tester.pumpAndSettle();

      // Name field should now contain "Night"
      final textFieldAfter = tester.widget<TextField>(find.byType(TextField));
      expect(textFieldAfter.controller!.text, 'Night');
    });

    testWidgets('color picker is displayed', (tester) async {
      await tester.pumpWidget(buildTestWidget());
      await tester.pumpAndSettle();

      expect(find.byType(TagColorPicker), findsOneWidget);
    });

    testWidgets('merge button disabled with empty name', (tester) async {
      await tester.pumpWidget(buildTestWidget());
      await tester.pumpAndSettle();

      // Clear the text field
      final textFieldFinder = find.byType(TextField);
      await tester.enterText(textFieldFinder, '');
      await tester.pumpAndSettle();

      // Tap the Merge button
      final mergeButton = find.widgetWithText(FilledButton, 'Merge');
      expect(mergeButton, findsOneWidget);
      await tester.tap(mergeButton);
      await tester.pumpAndSettle();

      // The merge should NOT have been called because name is empty
      expect(mockNotifier.mergeTagsCalled, isFalse);
    });

    testWidgets('shows affected dive count', (tester) async {
      await tester.pumpWidget(buildTestWidget());
      await tester.pumpAndSettle();

      // The mock returns 14 for getMergedDiveCount
      expect(find.textContaining('14 dives'), findsOneWidget);
    });
  });
}
