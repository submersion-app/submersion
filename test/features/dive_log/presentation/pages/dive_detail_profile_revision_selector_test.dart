import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mockito/mockito.dart';
import 'package:submersion/features/dive_log/domain/entities/dive.dart';
import 'package:submersion/features/dive_log/domain/entities/dive_data_source.dart';
import 'package:submersion/features/dive_log/domain/entities/profile_series_revision.dart';
import 'package:submersion/features/dive_log/presentation/pages/dive_detail_page.dart';
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
    'shows revision selector label and switches to selected revision',
    (tester) async {
      final dive = diveWithProfile();
      final base = await getBaseOverrides();
      final mockRepo = MockDiveRepository();

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
            diveDataSourcesProvider(
              dive.id,
            ).overrideWith((ref) async => <DiveDataSource>[]),
            profileSeriesHistoryProvider(
              dive.id,
            ).overrideWith((ref) async => revisions),
          ],
          child: MaterialApp(
            locale: const Locale('en'),
            localizationsDelegates: AppLocalizations.localizationsDelegates,
            supportedLocales: AppLocalizations.supportedLocales,
            home: DiveDetailPage(diveId: dive.id, embedded: true),
          ),
        ),
      );

      await tester.pump();
      await tester.pump(const Duration(seconds: 1));

      expect(find.textContaining('Edit: Profile editor'), findsOneWidget);

      await tester.tap(find.byIcon(Icons.history));
      await tester.pumpAndSettle();

      expect(find.text('Computer Import'), findsOneWidget);

      await tester.tap(find.text('Computer Import').last);
      await tester.pumpAndSettle();

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
          diveDataSourcesProvider(
            dive.id,
          ).overrideWith((ref) async => <DiveDataSource>[]),
          profileSeriesHistoryProvider(
            dive.id,
          ).overrideWith((ref) async => const <ProfileSeriesRevision>[]),
        ],
        child: MaterialApp(
          locale: const Locale('en'),
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: DiveDetailPage(diveId: dive.id, embedded: true),
        ),
      ),
    );

    await tester.pump();
    await tester.pump(const Duration(seconds: 1));

    expect(find.byIcon(Icons.history), findsNothing);
  });
}
