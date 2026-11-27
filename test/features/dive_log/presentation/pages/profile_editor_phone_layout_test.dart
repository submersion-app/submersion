import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mockito/mockito.dart';
import 'package:submersion/features/dive_log/domain/entities/dive.dart';
import 'package:submersion/features/dive_log/domain/entities/profile_series_revision.dart';
import 'package:submersion/features/dive_log/presentation/pages/profile_editor_page.dart';
import 'package:submersion/features/dive_log/presentation/providers/dive_providers.dart';
import 'package:submersion/l10n/arb/app_localizations.dart';

import '../../../../helpers/mock_providers.dart';
import '../../../weather/data/repositories/weather_repository_test.mocks.dart';

/// The profile editor's app bar on a phone in portrait, where the revision
/// selector got no room beside the title and actions (issue #5056).
void main() {
  Dive diveWithProfile() => createTestDiveWithBottomTime().copyWith(
    profile: const [
      DiveProfilePoint(timestamp: 0, depth: 0.0),
      DiveProfilePoint(timestamp: 60, depth: 12.0),
      DiveProfilePoint(timestamp: 120, depth: 6.0),
    ],
  );

  List<ProfileSeriesRevision> twoRevisions(String diveId) => [
    ProfileSeriesRevision(
      seriesId: 'series-edit',
      diveId: diveId,
      parentSeriesId: 'series-import',
      rootSeriesId: 'series-import',
      contentHash: 'hash-edit',
      revisionKind: 'Edit: profile_editor',
      createdAt: 2000,
      isActive: true,
    ),
    ProfileSeriesRevision(
      seriesId: 'series-import',
      diveId: diveId,
      parentSeriesId: null,
      rootSeriesId: 'series-import',
      contentHash: 'hash-import',
      revisionKind: 'computer_import',
      createdAt: 1000,
      isActive: false,
    ),
  ];

  Future<MockDiveRepository> pumpEditor(
    WidgetTester tester, {
    required Size size,
    List<ProfileSeriesRevision> Function(String diveId)? revisions,
  }) async {
    final dive = diveWithProfile();
    final base = await getBaseOverrides();
    final mockRepo = MockDiveRepository();
    when(mockRepo.setActiveProfileSeries(any, any)).thenAnswer((_) async {});

    tester.view.physicalSize = size;
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          ...base,
          diveRepositoryProvider.overrideWithValue(mockRepo),
          diveProvider(dive.id).overrideWith((ref) async => dive),
          profileSeriesHistoryProvider(
            dive.id,
          ).overrideWith((ref) async => (revisions ?? twoRevisions)(dive.id)),
        ],
        child: MaterialApp(
          locale: const Locale('en'),
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: ProfileEditorPage(diveId: dive.id),
        ),
      ),
    );
    await tester.pump();
    await tester.pump(const Duration(seconds: 1));
    return mockRepo;
  }

  final appBar = find.byType(AppBar);
  Finder inAppBar(Finder finder) =>
      find.descendant(of: appBar, matching: finder);

  group('on a phone in portrait', () {
    const phone = Size(400, 800);

    testWidgets('the revision selector has its own row and switches', (
      tester,
    ) async {
      final repo = await pumpEditor(tester, size: phone);
      expect(tester.takeException(), isNull);

      final selector = inAppBar(find.textContaining('Edit: Profile editor'));
      expect(selector, findsOneWidget);
      final title = inAppBar(find.text('Edit Profile'));
      expect(
        tester.getRect(selector).top,
        greaterThanOrEqualTo(tester.getRect(title).bottom),
      );
      expect(tester.getSize(selector).width, greaterThan(100));

      await tester.tap(inAppBar(find.byIcon(Icons.history)));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Computer Import').last);
      await tester.pumpAndSettle();

      verify(repo.setActiveProfileSeries(any, 'series-import')).called(1);
    });

    testWidgets('the title, Undo and Save do not overlap', (tester) async {
      await pumpEditor(tester, size: phone);

      // Save is an icon, named by its tooltip.
      expect(inAppBar(find.text('Save')), findsNothing);
      final save = inAppBar(find.byTooltip('Save'));
      expect(save, findsOneWidget);

      final title = tester.getRect(inAppBar(find.text('Edit Profile')));
      final undo = tester.getRect(inAppBar(find.byIcon(Icons.undo)));
      expect(title.right, lessThanOrEqualTo(undo.left));
      expect(undo.right, lessThanOrEqualTo(tester.getRect(save).left));
    });

    testWidgets('no empty row is left when the dive has no revisions', (
      tester,
    ) async {
      await pumpEditor(tester, size: phone, revisions: (_) => const []);

      expect(tester.widget<AppBar>(appBar).bottom, isNull);
    });
  });

  testWidgets('a wide screen keeps the selector beside the title', (
    tester,
  ) async {
    await pumpEditor(tester, size: const Size(1200, 900));

    final selector = inAppBar(find.textContaining('Edit: Profile editor'));
    final title = inAppBar(find.text('Edit Profile'));
    expect(
      tester.getCenter(selector).dy,
      moreOrLessEquals(tester.getCenter(title).dy, epsilon: 2),
    );
    expect(tester.widget<AppBar>(appBar).bottom, isNull);
    expect(inAppBar(find.text('Save')), findsOneWidget);
  });
}
