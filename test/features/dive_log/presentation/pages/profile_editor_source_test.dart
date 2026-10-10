import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:mockito/mockito.dart';
import 'package:submersion/features/dive_log/domain/entities/dive.dart';
import 'package:submersion/features/dive_log/domain/entities/profile_series_revision.dart';
import 'package:submersion/features/dive_log/domain/entities/source_profile.dart';
import 'package:submersion/features/dive_log/presentation/pages/profile_editor_page.dart';
import 'package:submersion/features/dive_log/presentation/providers/dive_providers.dart';
import 'package:submersion/features/dive_log/presentation/providers/profile_editor_provider.dart';
import 'package:submersion/features/dive_log/presentation/widgets/profile_editor_chart.dart';
import 'package:submersion/l10n/arb/app_localizations.dart';

import '../../../../helpers/mock_providers.dart';
import '../../../weather/data/repositories/weather_repository_test.mocks.dart';

/// Issue #3066: the editor starts from the computer chosen in the "Choose
/// starting profile" sheet, and saves the edit against that computer.
void main() {
  const primaryPoints = [
    DiveProfilePoint(timestamp: 0, depth: 0.0),
    DiveProfilePoint(timestamp: 60, depth: 12.0),
    DiveProfilePoint(timestamp: 120, depth: 0.0),
  ];
  const secondPoints = [
    DiveProfilePoint(timestamp: 0, depth: 0.0),
    DiveProfilePoint(timestamp: 30, depth: 18.0),
    DiveProfilePoint(timestamp: 60, depth: 25.0),
    DiveProfilePoint(timestamp: 90, depth: 18.0),
    DiveProfilePoint(timestamp: 120, depth: 0.0),
  ];

  late MockDiveRepository mockRepo;
  late Dive dive;
  bool? popResult;

  setUp(() {
    mockRepo = MockDiveRepository();
    popResult = null;
    dive = createTestDiveWithBottomTime().copyWith(profile: primaryPoints);
    when(
      mockRepo.saveEditedProfileWithKind(
        diveId: anyNamed('diveId'),
        editedPoints: anyNamed('editedPoints'),
        editKind: anyNamed('editKind'),
        sourceId: anyNamed('sourceId'),
      ),
    ).thenAnswer((_) async {});
  });

  Future<void> pumpEditor(WidgetTester tester, {String? sourceId}) async {
    final base = await getBaseOverrides();
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          ...base,
          diveRepositoryProvider.overrideWithValue(mockRepo),
          diveProvider(dive.id).overrideWith((ref) async => dive),
          sourceProfilesProvider(dive.id).overrideWith(
            (ref) async => {
              'src-a': const SourceProfile(
                sourceId: 'src-a',
                computerId: 'dc-a',
                isEdited: false,
                points: primaryPoints,
              ),
              'src-b': const SourceProfile(
                sourceId: 'src-b',
                computerId: 'dc-b',
                isEdited: false,
                points: secondPoints,
              ),
            },
          ),
          profileSeriesHistoryProvider(dive.id).overrideWith(
            (ref) async => [
              ProfileSeriesRevision(
                seriesId: 'series-a',
                diveId: dive.id,
                parentSeriesId: null,
                rootSeriesId: 'series-a',
                contentHash: 'hash-a',
                revisionKind: 'computer_import',
                createdAt: 1000,
                isActive: true,
              ),
            ],
          ),
        ],
        child: MaterialApp.router(
          locale: const Locale('en'),
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          routerConfig: GoRouter(
            routes: [
              GoRoute(
                path: '/',
                builder: (context, _) => Scaffold(
                  body: TextButton(
                    onPressed: () async =>
                        popResult = await context.push<bool>('/edit'),
                    child: const Text('open'),
                  ),
                ),
              ),
              GoRoute(
                path: '/edit',
                builder: (context, _) => ProfileEditorPage(
                  diveId: dive.id,
                  initialMode: EditorMode.smooth,
                  sourceId: sourceId,
                ),
              ),
            ],
          ),
        ),
      ),
    );
    await tester.tap(find.text('open'));
    await tester.pump();
    await tester.pump(const Duration(seconds: 1));
  }

  List<DiveProfilePoint> chartOriginal(WidgetTester tester) => tester
      .widget<ProfileEditorChart>(find.byType(ProfileEditorChart))
      .originalProfile;

  Future<void> smoothAndSave(WidgetTester tester) async {
    await tester.ensureVisible(find.text('Apply to All'));
    await tester.tap(find.text('Apply to All'));
    await tester.pumpAndSettle();
    await tester.tap(find.byIcon(Icons.save));
    await tester.pumpAndSettle();
    await tester.tap(find.widgetWithText(FilledButton, 'Save').last);
    await tester.pumpAndSettle();
  }

  testWidgets('starts from the primary profile without a source', (
    tester,
  ) async {
    await pumpEditor(tester);
    expect(chartOriginal(tester), primaryPoints);
  });

  testWidgets('starts from the chosen source profile', (tester) async {
    await pumpEditor(tester, sourceId: 'src-b');
    expect(chartOriginal(tester), secondPoints);
  });

  testWidgets('saves the edit against the chosen source', (tester) async {
    await pumpEditor(tester, sourceId: 'src-b');
    await smoothAndSave(tester);

    verify(
      mockRepo.saveEditedProfileWithKind(
        diveId: dive.id,
        editedPoints: anyNamed('editedPoints'),
        editKind: anyNamed('editKind'),
        sourceId: 'src-b',
      ),
    ).called(1);
    // The caller refreshes its form only when the editor reports a save.
    expect(popResult, isTrue);
  });

  testWidgets('hides the revision selector for a non-primary source', (
    tester,
  ) async {
    // The revision history is the primary's lineage; switching it would
    // reload a profile other than the one being edited.
    await pumpEditor(tester, sourceId: 'src-b');
    expect(find.byIcon(Icons.history), findsNothing);
  });
}
