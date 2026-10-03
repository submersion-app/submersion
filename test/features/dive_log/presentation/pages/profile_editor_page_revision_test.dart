import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/features/dive_log/domain/entities/dive.dart';
import 'package:submersion/features/dive_log/domain/entities/profile_series_revision.dart';
import 'package:submersion/features/dive_log/presentation/pages/profile_editor_page.dart';
import 'package:submersion/features/dive_log/presentation/providers/dive_providers.dart';
import 'package:submersion/features/dive_log/presentation/providers/profile_editor_provider.dart';
import 'package:submersion/l10n/arb/app_localizations.dart';

import '../../../../helpers/mock_providers.dart';

void main() {
  Dive diveWithProfile({required List<DiveProfilePoint> profile}) =>
      createTestDiveWithBottomTime().copyWith(profile: profile);

  group('ProfileEditorPage Revision Selector UI', () {
    testWidgets(
      'revision selector is positioned in AppBar next to Edit Profile title',
      (tester) async {
        final dive = diveWithProfile(
          profile: [
            const DiveProfilePoint(timestamp: 0, depth: 0.0),
            const DiveProfilePoint(timestamp: 60, depth: 12.0),
          ],
        );

        final base = await getBaseOverrides();
        final revisions = [
          ProfileSeriesRevision(
            seriesId: 'series-1',
            diveId: dive.id,
            parentSeriesId: null,
            rootSeriesId: 'series-1',
            contentHash: 'hash-1',
            revisionKind: 'create',
            createdAt: 1000,
            isActive: true,
          ),
        ];

        await tester.pumpWidget(
          ProviderScope(
            overrides: [
              ...base,
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

        // Find AppBar
        final appBar = find.byType(AppBar);
        expect(appBar, findsOneWidget);

        // Verify "Edit Profile" title is in AppBar
        expect(
          find.descendant(of: appBar, matching: find.text('Edit Profile')),
          findsOneWidget,
        );

        // Verify history icon is in AppBar (right of title)
        expect(
          find.descendant(of: appBar, matching: find.byIcon(Icons.history)),
          findsOneWidget,
        );
      },
    );

    testWidgets(
      'unsaved edits survive a dive reload and lock the revision selector',
      (tester) async {
        // A spike, so smoothing really changes the samples.
        const profile = [
          DiveProfilePoint(timestamp: 0, depth: 0.0),
          DiveProfilePoint(timestamp: 10, depth: 10.0),
          DiveProfilePoint(timestamp: 20, depth: 30.0),
          DiveProfilePoint(timestamp: 30, depth: 10.0),
          DiveProfilePoint(timestamp: 40, depth: 10.0),
          DiveProfilePoint(timestamp: 50, depth: 0.0),
        ];
        final dive = diveWithProfile(profile: profile);

        final base = await getBaseOverrides();
        final revisions = [
          ProfileSeriesRevision(
            seriesId: 'series-1',
            diveId: dive.id,
            parentSeriesId: null,
            rootSeriesId: 'series-1',
            contentHash: 'hash-1',
            revisionKind: 'create',
            createdAt: 1000,
            isActive: true,
          ),
        ];

        await tester.pumpWidget(
          ProviderScope(
            overrides: [
              ...base,
              // A fresh list on every load, as the real provider returns
              // after any dive-detail table tick.
              diveProvider(dive.id).overrideWith(
                (ref) async => dive.copyWith(profile: List.of(profile)),
              ),
              profileSeriesHistoryProvider(
                dive.id,
              ).overrideWith((ref) async => revisions),
            ],
            child: MaterialApp(
              locale: const Locale('en'),
              localizationsDelegates: AppLocalizations.localizationsDelegates,
              supportedLocales: AppLocalizations.supportedLocales,
              home: ProfileEditorPage(
                diveId: dive.id,
                initialMode: EditorMode.smooth,
              ),
            ),
          ),
        );
        await tester.pump();
        await tester.pump(const Duration(seconds: 1));

        PopupMenuButton<String> selector() => tester.widget(
          find.byWidgetPredicate((w) => w is PopupMenuButton<String>),
        );
        IconButton undoButton() =>
            tester.widget(find.widgetWithIcon(IconButton, Icons.undo));

        expect(selector().enabled, isTrue);

        await tester.tap(find.text('Apply to All'));
        await tester.pump();
        expect(undoButton().onPressed, isNotNull);
        expect(selector().enabled, isFalse);

        final container = ProviderScope.containerOf(
          tester.element(find.byType(ProfileEditorPage)),
        );
        container.invalidate(diveProvider(dive.id));
        await tester.pump();
        await tester.pump(const Duration(seconds: 1));

        expect(undoButton().onPressed, isNotNull);
        expect(selector().enabled, isFalse);
      },
    );

    testWidgets('revision selector hides when no history available', (
      tester,
    ) async {
      final dive = diveWithProfile(
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

      // Verify history icon is not shown
      expect(find.byIcon(Icons.history), findsNothing);
    });
  });
}
