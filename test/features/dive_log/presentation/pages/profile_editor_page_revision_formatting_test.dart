import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/features/dive_log/domain/entities/dive.dart';
import 'package:submersion/features/dive_log/domain/entities/profile_series_revision.dart';
import 'package:submersion/features/dive_log/presentation/pages/profile_editor_page.dart';
import 'package:submersion/features/dive_log/presentation/providers/dive_providers.dart';
import 'package:submersion/l10n/arb/app_localizations.dart';
import '../../../../helpers/mock_providers.dart';

void main() {
  ProfileSeriesRevision createRevision({
    required String seriesId,
    required String diveId,
    required String revisionKind,
    required int createdAt,
    bool isActive = false,
  }) => ProfileSeriesRevision(
    seriesId: seriesId,
    diveId: diveId,
    parentSeriesId: null,
    rootSeriesId: seriesId,
    contentHash: 'hash-$seriesId',
    revisionKind: revisionKind,
    createdAt: createdAt,
    isActive: isActive,
  );

  group('ProfileEditorPage - Revision Formatting Coverage Tests', () {
    testWidgets('formats create revision', (tester) async {
      final dive = createTestDiveWithBottomTime().copyWith(
        profile: [
          const DiveProfilePoint(timestamp: 0, depth: 0.0),
          const DiveProfilePoint(timestamp: 60, depth: 12.0),
        ],
      );
      final base = await getBaseOverrides();
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            ...base,
            diveProvider(dive.id).overrideWith((ref) => dive),
            profileSeriesHistoryProvider(dive.id).overrideWith(
              (ref) => [
                createRevision(
                  seriesId: 's1',
                  diveId: dive.id,
                  revisionKind: 'create',
                  createdAt: 1696104000000,
                  isActive: true,
                ),
              ],
            ),
          ],
          child: MaterialApp(
            localizationsDelegates: AppLocalizations.localizationsDelegates,
            supportedLocales: AppLocalizations.supportedLocales,
            home: ProfileEditorPage(diveId: dive.id),
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.byIcon(Icons.history), findsWidgets);
    });

    testWidgets('formats computer_import revision', (tester) async {
      final dive = createTestDiveWithBottomTime().copyWith(
        profile: [
          const DiveProfilePoint(timestamp: 0, depth: 0.0),
          const DiveProfilePoint(timestamp: 60, depth: 12.0),
        ],
      );
      final base = await getBaseOverrides();
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            ...base,
            diveProvider(dive.id).overrideWith((ref) => dive),
            profileSeriesHistoryProvider(dive.id).overrideWith(
              (ref) => [
                createRevision(
                  seriesId: 's1',
                  diveId: dive.id,
                  revisionKind: 'computer_import',
                  createdAt: 1696104000000,
                  isActive: true,
                ),
              ],
            ),
          ],
          child: MaterialApp(
            localizationsDelegates: AppLocalizations.localizationsDelegates,
            supportedLocales: AppLocalizations.supportedLocales,
            home: ProfileEditorPage(diveId: dive.id),
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.byIcon(Icons.history), findsWidgets);
    });

    testWidgets('formats legacy revision', (tester) async {
      final dive = createTestDiveWithBottomTime().copyWith(
        profile: [
          const DiveProfilePoint(timestamp: 0, depth: 0.0),
          const DiveProfilePoint(timestamp: 60, depth: 12.0),
        ],
      );
      final base = await getBaseOverrides();
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            ...base,
            diveProvider(dive.id).overrideWith((ref) => dive),
            profileSeriesHistoryProvider(dive.id).overrideWith(
              (ref) => [
                createRevision(
                  seriesId: 's1',
                  diveId: dive.id,
                  revisionKind: 'legacy',
                  createdAt: 1696104000000,
                  isActive: true,
                ),
              ],
            ),
          ],
          child: MaterialApp(
            localizationsDelegates: AppLocalizations.localizationsDelegates,
            supportedLocales: AppLocalizations.supportedLocales,
            home: ProfileEditorPage(diveId: dive.id),
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.byIcon(Icons.history), findsWidgets);
    });

    testWidgets('formats edit with single edit type', (tester) async {
      final dive = createTestDiveWithBottomTime().copyWith(
        profile: [
          const DiveProfilePoint(timestamp: 0, depth: 0.0),
          const DiveProfilePoint(timestamp: 60, depth: 12.0),
        ],
      );
      final base = await getBaseOverrides();
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            ...base,
            diveProvider(dive.id).overrideWith((ref) => dive),
            profileSeriesHistoryProvider(dive.id).overrideWith(
              (ref) => [
                createRevision(
                  seriesId: 's1',
                  diveId: dive.id,
                  revisionKind: 'Edit: profile_editor',
                  createdAt: 1696104000000,
                  isActive: true,
                ),
              ],
            ),
          ],
          child: MaterialApp(
            localizationsDelegates: AppLocalizations.localizationsDelegates,
            supportedLocales: AppLocalizations.supportedLocales,
            home: ProfileEditorPage(diveId: dive.id),
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.byIcon(Icons.history), findsWidgets);
    });

    testWidgets('formats edit with multiple edit types', (tester) async {
      final dive = createTestDiveWithBottomTime().copyWith(
        profile: [
          const DiveProfilePoint(timestamp: 0, depth: 0.0),
          const DiveProfilePoint(timestamp: 60, depth: 12.0),
        ],
      );
      final base = await getBaseOverrides();
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            ...base,
            diveProvider(dive.id).overrideWith((ref) => dive),
            profileSeriesHistoryProvider(dive.id).overrideWith(
              (ref) => [
                createRevision(
                  seriesId: 's1',
                  diveId: dive.id,
                  revisionKind: 'edit:smooth_all+remove_all_outliers',
                  createdAt: 1696104000000,
                  isActive: true,
                ),
              ],
            ),
          ],
          child: MaterialApp(
            localizationsDelegates: AppLocalizations.localizationsDelegates,
            supportedLocales: AppLocalizations.supportedLocales,
            home: ProfileEditorPage(diveId: dive.id),
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.byIcon(Icons.history), findsWidgets);
    });

    testWidgets('handles empty revision history', (tester) async {
      final dive = createTestDiveWithBottomTime().copyWith(
        profile: [
          const DiveProfilePoint(timestamp: 0, depth: 0.0),
          const DiveProfilePoint(timestamp: 60, depth: 12.0),
        ],
      );
      final base = await getBaseOverrides();
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            ...base,
            diveProvider(dive.id).overrideWith((ref) => dive),
            profileSeriesHistoryProvider(dive.id).overrideWith((ref) => []),
          ],
          child: MaterialApp(
            localizationsDelegates: AppLocalizations.localizationsDelegates,
            supportedLocales: AppLocalizations.supportedLocales,
            home: ProfileEditorPage(diveId: dive.id),
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.byIcon(Icons.history), findsNothing);
    });

    testWidgets('handles revision history error', (tester) async {
      final dive = createTestDiveWithBottomTime().copyWith(
        profile: [
          const DiveProfilePoint(timestamp: 0, depth: 0.0),
          const DiveProfilePoint(timestamp: 60, depth: 12.0),
        ],
      );
      final base = await getBaseOverrides();
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            ...base,
            diveProvider(dive.id).overrideWith((ref) => dive),
            profileSeriesHistoryProvider(
              dive.id,
            ).overrideWith((ref) => throw Exception('error')),
          ],
          child: MaterialApp(
            localizationsDelegates: AppLocalizations.localizationsDelegates,
            supportedLocales: AppLocalizations.supportedLocales,
            home: ProfileEditorPage(diveId: dive.id),
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.byIcon(Icons.history_toggle_off), findsWidgets);
    });

    testWidgets('handles unknown edit type', (tester) async {
      final dive = createTestDiveWithBottomTime().copyWith(
        profile: [
          const DiveProfilePoint(timestamp: 0, depth: 0.0),
          const DiveProfilePoint(timestamp: 60, depth: 12.0),
        ],
      );
      final base = await getBaseOverrides();
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            ...base,
            diveProvider(dive.id).overrideWith((ref) => dive),
            profileSeriesHistoryProvider(dive.id).overrideWith(
              (ref) => [
                createRevision(
                  seriesId: 's1',
                  diveId: dive.id,
                  revisionKind: 'edit:unknown_type',
                  createdAt: 1696104000000,
                  isActive: true,
                ),
              ],
            ),
          ],
          child: MaterialApp(
            localizationsDelegates: AppLocalizations.localizationsDelegates,
            supportedLocales: AppLocalizations.supportedLocales,
            home: ProfileEditorPage(diveId: dive.id),
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.byIcon(Icons.history), findsWidgets);
    });
  });
}
