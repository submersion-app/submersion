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

void main() {
  Dive diveWithProfile() => createTestDiveWithBottomTime().copyWith(
    profile: const [
      DiveProfilePoint(timestamp: 0, depth: 0.0),
      DiveProfilePoint(timestamp: 60, depth: 12.0),
      DiveProfilePoint(timestamp: 120, depth: 6.0),
    ],
  );

  testWidgets(
    'shows revision selector in appbar and switches to selected revision',
    (tester) async {
      final dive = diveWithProfile();
      final base = await getBaseOverrides();
      final mockRepo = MockDiveRepository();

      // Use larger viewport for popup menu visibility
      tester.view.physicalSize = const Size(1600, 4000);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      when(mockRepo.setActiveProfileSeries(any, any)).thenAnswer((_) async {});

      final revisions = [
        ProfileSeriesRevision(
          seriesId: 'series-edit',
          diveId: dive.id,
          parentSeriesId: 'series-import',
          rootSeriesId: 'series-import',
          contentHash: 'hash-edit',
          revisionKind: 'Edit: profile_editor',
          createdAt: 2000,
          isActive: true,
        ),
        ProfileSeriesRevision(
          seriesId: 'series-import',
          diveId: dive.id,
          parentSeriesId: null,
          rootSeriesId: 'series-import',
          contentHash: 'hash-import',
          revisionKind: 'computer_import',
          createdAt: 1000,
          isActive: false,
        ),
      ];

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            ...base,
            diveRepositoryProvider.overrideWithValue(mockRepo),
            diveProvider(dive.id).overrideWith((ref) async => dive),
            profileSeriesHistoryProvider(
              dive.id,
            ).overrideWith((ref) async => revisions),
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

      // Verify revision selector is in AppBar with history icon
      expect(find.byIcon(Icons.history), findsOneWidget);
      expect(find.textContaining('Edit: Profile editor'), findsOneWidget);

      // Tap history icon to open revision menu
      await tester.tap(find.byIcon(Icons.history));
      await tester.pumpAndSettle();

      // Verify alternative revision is shown in menu
      expect(find.text('Computer Import'), findsOneWidget);

      // Select different revision by tapping on the menu item widget
      final computerImportFinder = find.ancestor(
        of: find.text('Computer Import'),
        matching: find.byWidgetPredicate(
          (widget) =>
              widget.runtimeType.toString() == 'CheckedPopupMenuItem<String>',
        ),
      );
      if (computerImportFinder.evaluate().isEmpty) {
        // Fallback: try to tap the text with warnIfMissed: false
        await tester.tap(
          find.text('Computer Import').last,
          warnIfMissed: false,
        );
      } else {
        await tester.tap(computerImportFinder);
      }
      await tester.pumpAndSettle();

      // Verify setActiveProfileSeries was called
      verify(
        mockRepo.setActiveProfileSeries(dive.id, 'series-import'),
      ).called(1);
    },
  );

  testWidgets('hides selector when history is empty', (tester) async {
    final dive = diveWithProfile();
    final base = await getBaseOverrides();

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          ...base,
          diveProvider(dive.id).overrideWith((ref) async => dive),
          profileSeriesHistoryProvider(
            dive.id,
          ).overrideWith((ref) async => const <ProfileSeriesRevision>[]),
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

    // Verify history icon and selector are not shown when no revision history
    expect(find.byIcon(Icons.history), findsNothing);
  });
}
