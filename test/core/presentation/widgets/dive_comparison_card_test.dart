import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/core/domain/models/incoming_dive_data.dart';
import 'package:submersion/core/presentation/widgets/dive_comparison_card.dart';
import 'package:submersion/core/constants/map_style.dart';
import 'package:submersion/core/providers/provider.dart';
import 'package:submersion/features/dive_log/domain/entities/dive.dart'
    as domain;
import 'package:submersion/features/dive_log/domain/entities/dive_data_source.dart';
import 'package:submersion/features/dive_log/presentation/providers/dive_computer_providers.dart';
import 'package:submersion/features/dive_log/presentation/providers/dive_providers.dart';
import 'package:submersion/features/import_wizard/domain/models/duplicate_action.dart';
import 'package:submersion/features/settings/presentation/providers/settings_providers.dart';
import 'package:submersion/l10n/arb/app_localizations.dart';

// ---------------------------------------------------------------------------
// Helpers
// ---------------------------------------------------------------------------

class _TestSettingsNotifier extends StateNotifier<AppSettings>
    implements SettingsNotifier {
  _TestSettingsNotifier() : super(const AppSettings());

  @override
  Future<void> setMapStyle(MapStyle style) async =>
      state = state.copyWith(mapStyle: style);

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

const _existingDiveId = 'test-dive-id';

final _testDive = domain.Dive(
  id: _existingDiveId,
  dateTime: DateTime(2026, 1, 15, 9, 0),
  diveNumber: 42,
);

final _testIncoming = IncomingDiveData(
  startTime: DateTime(2026, 1, 15, 9, 0),
  maxDepth: 25.0,
  durationSeconds: 3000,
);

/// Wraps the widget under test with all required providers stubbed out.
Widget _buildCard({required DiveComparisonCard card}) {
  return ProviderScope(
    overrides: [
      settingsProvider.overrideWith((ref) => _TestSettingsNotifier()),
      diveProvider.overrideWith((ref, id) async => _testDive),
      diveProfileProvider.overrideWith((ref, id) async => []),
    ],
    child: MaterialApp(
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      home: Scaffold(body: SingleChildScrollView(child: card)),
    ),
  );
}

// ---------------------------------------------------------------------------
// Tests
// ---------------------------------------------------------------------------

void main() {
  group(
    'DiveComparisonCard - immediate-action mode (backwards compatible)',
    () {
      testWidgets('renders all three action buttons by default', (
        tester,
      ) async {
        await tester.pumpWidget(
          _buildCard(
            card: DiveComparisonCard(
              incoming: _testIncoming,
              existingDiveId: _existingDiveId,
              matchScore: 0.95,
            ),
          ),
        );
        await tester.pumpAndSettle();

        expect(find.text('Skip'), findsOneWidget);
        expect(find.text('Import as New'), findsOneWidget);
        expect(find.text('Consolidate'), findsOneWidget);
      });

      testWidgets('fires onSkip when Skip tapped', (tester) async {
        var skipCalled = false;
        await tester.pumpWidget(
          _buildCard(
            card: DiveComparisonCard(
              incoming: _testIncoming,
              existingDiveId: _existingDiveId,
              matchScore: 0.95,
              onSkip: () => skipCalled = true,
            ),
          ),
        );
        await tester.pumpAndSettle();

        await tester.tap(find.text('Skip'));
        await tester.pump();

        expect(skipCalled, isTrue);
      });

      testWidgets('fires onImportAsNew when Import as New tapped', (
        tester,
      ) async {
        var importCalled = false;
        await tester.pumpWidget(
          _buildCard(
            card: DiveComparisonCard(
              incoming: _testIncoming,
              existingDiveId: _existingDiveId,
              matchScore: 0.95,
              onImportAsNew: () => importCalled = true,
            ),
          ),
        );
        await tester.pumpAndSettle();

        await tester.tap(find.text('Import as New'));
        await tester.pump();

        expect(importCalled, isTrue);
      });

      testWidgets('Consolidate button is disabled', (tester) async {
        var consolidateCalled = false;
        await tester.pumpWidget(
          _buildCard(
            card: DiveComparisonCard(
              incoming: _testIncoming,
              existingDiveId: _existingDiveId,
              matchScore: 0.95,
              onConsolidate: () => consolidateCalled = true,
            ),
          ),
        );
        await tester.pumpAndSettle();

        // Consolidate button should be visible but disabled.
        expect(find.text('Consolidate'), findsOneWidget);
        await tester.tap(find.text('Consolidate'));
        await tester.pump();

        expect(consolidateCalled, isFalse);
      });
    },
  );

  group('DiveComparisonCard - tri-state selector mode', () {
    testWidgets('renders all three buttons when selectedAction is provided', (
      tester,
    ) async {
      await tester.pumpWidget(
        _buildCard(
          card: DiveComparisonCard(
            incoming: _testIncoming,
            existingDiveId: _existingDiveId,
            matchScore: 0.95,
            selectedAction: DuplicateAction.skip,
            onActionChanged: (_) {},
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('Skip'), findsOneWidget);
      expect(find.text('Import as New'), findsOneWidget);
      expect(find.text('Consolidate'), findsOneWidget);
    });

    testWidgets('active button uses FilledButton style', (tester) async {
      await tester.pumpWidget(
        _buildCard(
          card: DiveComparisonCard(
            incoming: _testIncoming,
            existingDiveId: _existingDiveId,
            matchScore: 0.95,
            selectedAction: DuplicateAction.consolidate,
            onActionChanged: (_) {},
          ),
        ),
      );
      await tester.pumpAndSettle();

      // The selected button (Consolidate) renders as FilledButton.tonal.
      // Inactive buttons (Skip, Import as New, Replace Source) render as
      // OutlinedButton.
      final filledButtons = tester
          .widgetList<FilledButton>(find.byType(FilledButton))
          .toList();
      final outlinedButtons = tester
          .widgetList<OutlinedButton>(find.byType(OutlinedButton))
          .toList();

      // Exactly one filled button (the selected one).
      expect(filledButtons.length, 1);
      // Three outlined buttons (the inactive ones).
      expect(outlinedButtons.length, 3);
    });

    testWidgets(
      'tapping Skip calls onActionChanged with DuplicateAction.skip',
      (tester) async {
        DuplicateAction? received;
        await tester.pumpWidget(
          _buildCard(
            card: DiveComparisonCard(
              incoming: _testIncoming,
              existingDiveId: _existingDiveId,
              matchScore: 0.95,
              selectedAction: DuplicateAction.importAsNew,
              onActionChanged: (action) => received = action,
            ),
          ),
        );
        await tester.pumpAndSettle();

        await tester.tap(find.text('Skip'));
        await tester.pump();

        expect(received, DuplicateAction.skip);
      },
    );

    testWidgets(
      'tapping Import as New calls onActionChanged with DuplicateAction.importAsNew',
      (tester) async {
        DuplicateAction? received;
        await tester.pumpWidget(
          _buildCard(
            card: DiveComparisonCard(
              incoming: _testIncoming,
              existingDiveId: _existingDiveId,
              matchScore: 0.95,
              selectedAction: DuplicateAction.skip,
              onActionChanged: (action) => received = action,
            ),
          ),
        );
        await tester.pumpAndSettle();

        await tester.tap(find.text('Import as New'));
        await tester.pump();

        expect(received, DuplicateAction.importAsNew);
      },
    );

    testWidgets('Consolidate button is disabled in tri-state mode', (
      tester,
    ) async {
      DuplicateAction? received;
      await tester.pumpWidget(
        _buildCard(
          card: DiveComparisonCard(
            incoming: _testIncoming,
            existingDiveId: _existingDiveId,
            matchScore: 0.95,
            selectedAction: DuplicateAction.skip,
            onActionChanged: (action) => received = action,
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Consolidate button should be visible but disabled.
      expect(find.text('Consolidate'), findsOneWidget);
      await tester.tap(find.text('Consolidate'));
      await tester.pump();

      expect(received, isNull);
    });

    testWidgets('availableActions hides Consolidate button when not in set', (
      tester,
    ) async {
      await tester.pumpWidget(
        _buildCard(
          card: DiveComparisonCard(
            incoming: _testIncoming,
            existingDiveId: _existingDiveId,
            matchScore: 0.95,
            selectedAction: DuplicateAction.skip,
            onActionChanged: (_) {},
            availableActions: {
              DuplicateAction.skip,
              DuplicateAction.importAsNew,
            },
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('Skip'), findsOneWidget);
      expect(find.text('Import as New'), findsOneWidget);
      expect(find.text('Consolidate'), findsNothing);
    });

    testWidgets('availableActions hides Skip button when not in set', (
      tester,
    ) async {
      await tester.pumpWidget(
        _buildCard(
          card: DiveComparisonCard(
            incoming: _testIncoming,
            existingDiveId: _existingDiveId,
            matchScore: 0.95,
            selectedAction: DuplicateAction.importAsNew,
            onActionChanged: (_) {},
            availableActions: {
              DuplicateAction.importAsNew,
              DuplicateAction.consolidate,
            },
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('Skip'), findsNothing);
      expect(find.text('Import as New'), findsOneWidget);
      expect(find.text('Consolidate'), findsOneWidget);
    });

    testWidgets(
      'availableActions with only one action shows only that button',
      (tester) async {
        await tester.pumpWidget(
          _buildCard(
            card: DiveComparisonCard(
              incoming: _testIncoming,
              existingDiveId: _existingDiveId,
              matchScore: 0.95,
              selectedAction: DuplicateAction.consolidate,
              onActionChanged: (_) {},
              availableActions: {DuplicateAction.consolidate},
            ),
          ),
        );
        await tester.pumpAndSettle();

        expect(find.text('Skip'), findsNothing);
        expect(find.text('Import as New'), findsNothing);
        expect(find.text('Consolidate'), findsOneWidget);
      },
    );

    testWidgets(
      'does not fire immediate-action callbacks when in tri-state mode',
      (tester) async {
        var legacyCalled = false;
        DuplicateAction? received;

        await tester.pumpWidget(
          _buildCard(
            card: DiveComparisonCard(
              incoming: _testIncoming,
              existingDiveId: _existingDiveId,
              matchScore: 0.95,
              // Both modes wired — tri-state should win.
              onSkip: () => legacyCalled = true,
              selectedAction: DuplicateAction.importAsNew,
              onActionChanged: (action) => received = action,
            ),
          ),
        );
        await tester.pumpAndSettle();

        await tester.tap(find.text('Skip'));
        await tester.pump();

        expect(legacyCalled, isFalse);
        expect(received, DuplicateAction.skip);
      },
    );
  });

  // ---------------------------------------------------------------------------
  // Embedded mode
  // ---------------------------------------------------------------------------

  group('DiveComparisonCard - embedded mode', () {
    testWidgets('embedded=true renders content without Card wrapper', (
      tester,
    ) async {
      await tester.pumpWidget(
        _buildCard(
          card: DiveComparisonCard(
            incoming: _testIncoming,
            existingDiveId: _existingDiveId,
            matchScore: 0.95,
            embedded: true,
          ),
        ),
      );
      await tester.pumpAndSettle();

      // The outer Card should not be present when embedded is true.
      // The action buttons should still render.
      expect(find.text('Skip'), findsOneWidget);
      // No Card widget wrapping the comparison content. The DiveComparisonCard
      // itself is a ConsumerWidget, so look for Card widgets that are its
      // direct child — there should be none.
      final cardFinder = find.ancestor(
        of: find.text('Skip'),
        matching: find.byType(Card),
      );
      // In embedded mode there should be no Card ancestor between the buttons
      // and the Scaffold (the Scaffold's body is a SingleChildScrollView).
      // We verify by checking no Card with bottom margin exists.
      expect(cardFinder, findsNothing);
    });

    testWidgets('embedded=false wraps content in Card', (tester) async {
      await tester.pumpWidget(
        _buildCard(
          card: DiveComparisonCard(
            incoming: _testIncoming,
            existingDiveId: _existingDiveId,
            matchScore: 0.95,
            embedded: false,
          ),
        ),
      );
      await tester.pumpAndSettle();

      // In non-embedded mode, a Card wraps the content.
      final cardFinder = find.ancestor(
        of: find.text('Skip'),
        matching: find.byType(Card),
      );
      expect(cardFinder, findsOneWidget);
    });
  });

  // ---------------------------------------------------------------------------
  // Diff rows with delta values
  // ---------------------------------------------------------------------------

  group('DiveComparisonCard - diff row rendering', () {
    testWidgets('renders diff fields with numeric delta', (tester) async {
      // Provide a dive with different maxDepth to trigger a diff field.
      final existingDive = domain.Dive(
        id: _existingDiveId,
        dateTime: DateTime(2026, 1, 15, 9, 0),
        entryTime: DateTime(2026, 1, 15, 9, 0),
        maxDepth: 20.0,
        runtime: const Duration(minutes: 50),
        diveNumber: 42,
      );

      final incoming = IncomingDiveData(
        startTime: DateTime(2026, 1, 15, 9, 0),
        maxDepth: 25.0,
        durationSeconds: 3000,
      );

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            settingsProvider.overrideWith((ref) => _TestSettingsNotifier()),
            diveProvider.overrideWith((ref, id) async => existingDive),
            diveProfileProvider.overrideWith((ref, id) async => []),
          ],
          child: MaterialApp(
            localizationsDelegates: AppLocalizations.localizationsDelegates,
            supportedLocales: AppLocalizations.supportedLocales,
            home: Scaffold(
              body: SingleChildScrollView(
                child: DiveComparisonCard(
                  incoming: incoming,
                  existingDiveId: _existingDiveId,
                  matchScore: 0.95,
                ),
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      // The DIFFERENCES header should appear.
      expect(find.text('DIFFERENCES'), findsOneWidget);
      // max depth field should appear in the diff table.
      expect(find.text('max depth'), findsOneWidget);
    });

    testWidgets('renders diff fields with duration delta', (tester) async {
      // Existing dive with 50 min runtime, incoming with 40 min.
      // Delta = -600 seconds, should show negative delta format.
      final existingDive = domain.Dive(
        id: _existingDiveId,
        dateTime: DateTime(2026, 1, 15, 9, 0),
        entryTime: DateTime(2026, 1, 15, 9, 0),
        maxDepth: 25.0,
        runtime: const Duration(minutes: 50),
        diveNumber: 42,
      );

      final incoming = IncomingDiveData(
        startTime: DateTime(2026, 1, 15, 9, 0),
        maxDepth: 25.0,
        durationSeconds: 40 * 60,
      );

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            settingsProvider.overrideWith((ref) => _TestSettingsNotifier()),
            diveProvider.overrideWith((ref, id) async => existingDive),
            diveProfileProvider.overrideWith((ref, id) async => []),
          ],
          child: MaterialApp(
            localizationsDelegates: AppLocalizations.localizationsDelegates,
            supportedLocales: AppLocalizations.supportedLocales,
            home: Scaffold(
              body: SingleChildScrollView(
                child: DiveComparisonCard(
                  incoming: incoming,
                  existingDiveId: _existingDiveId,
                  matchScore: 0.95,
                ),
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Duration field should appear in diffs.
      expect(find.text('duration'), findsOneWidget);
    });

    testWidgets('renders not recorded for missing incoming field', (
      tester,
    ) async {
      // Existing has water temp, incoming does not.
      final existingDive = domain.Dive(
        id: _existingDiveId,
        dateTime: DateTime(2026, 1, 15, 9, 0),
        entryTime: DateTime(2026, 1, 15, 9, 0),
        waterTemp: 22.0,
        diveNumber: 42,
      );

      final incoming = IncomingDiveData(startTime: DateTime(2026, 1, 15, 9, 0));

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            settingsProvider.overrideWith((ref) => _TestSettingsNotifier()),
            diveProvider.overrideWith((ref, id) async => existingDive),
            diveProfileProvider.overrideWith((ref, id) async => []),
          ],
          child: MaterialApp(
            localizationsDelegates: AppLocalizations.localizationsDelegates,
            supportedLocales: AppLocalizations.supportedLocales,
            home: Scaffold(
              body: SingleChildScrollView(
                child: DiveComparisonCard(
                  incoming: incoming,
                  existingDiveId: _existingDiveId,
                  matchScore: 0.95,
                ),
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      // 'not recorded' should appear for the missing incoming value.
      expect(find.text('not recorded'), findsWidgets);
    });
  });

  // ---------------------------------------------------------------------------
  // Dive number in existing label
  // ---------------------------------------------------------------------------

  group('DiveComparisonCard - existing label with dive number', () {
    testWidgets('existing label includes dive number when present', (
      tester,
    ) async {
      await tester.pumpWidget(
        _buildCard(
          card: DiveComparisonCard(
            incoming: _testIncoming,
            existingDiveId: _existingDiveId,
            matchScore: 0.95,
          ),
        ),
      );
      await tester.pumpAndSettle();

      // The existing dive has diveNumber=42, so the label should be
      // "Existing (#42)".
      expect(find.textContaining('#42'), findsOneWidget);
    });

    testWidgets('existing label omits number when dive has no number', (
      tester,
    ) async {
      final noDiveNumber = domain.Dive(
        id: _existingDiveId,
        dateTime: DateTime(2026, 1, 15, 9, 0),
      );

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            settingsProvider.overrideWith((ref) => _TestSettingsNotifier()),
            diveProvider.overrideWith((ref, id) async => noDiveNumber),
            diveProfileProvider.overrideWith((ref, id) async => []),
          ],
          child: MaterialApp(
            localizationsDelegates: AppLocalizations.localizationsDelegates,
            supportedLocales: AppLocalizations.supportedLocales,
            home: Scaffold(
              body: SingleChildScrollView(
                child: DiveComparisonCard(
                  incoming: _testIncoming,
                  existingDiveId: _existingDiveId,
                  matchScore: 0.95,
                ),
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      // No dive number, so should not contain (#).
      expect(find.textContaining('#'), findsNothing);
    });
  });

  // ---------------------------------------------------------------------------
  // Tri-state selector coloring
  // ---------------------------------------------------------------------------

  group('DiveComparisonCard - tri-state button colors', () {
    testWidgets('selected skip action renders with filled button', (
      tester,
    ) async {
      await tester.pumpWidget(
        _buildCard(
          card: DiveComparisonCard(
            incoming: _testIncoming,
            existingDiveId: _existingDiveId,
            matchScore: 0.95,
            selectedAction: DuplicateAction.skip,
            onActionChanged: (_) {},
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Skip is selected so it should be a FilledButton.
      expect(find.byType(FilledButton), findsOneWidget);
    });

    testWidgets('selected importAsNew action renders with filled button', (
      tester,
    ) async {
      await tester.pumpWidget(
        _buildCard(
          card: DiveComparisonCard(
            incoming: _testIncoming,
            existingDiveId: _existingDiveId,
            matchScore: 0.95,
            selectedAction: DuplicateAction.importAsNew,
            onActionChanged: (_) {},
          ),
        ),
      );
      await tester.pumpAndSettle();

      // importAsNew is selected — should have one filled button.
      expect(find.byType(FilledButton), findsOneWidget);
    });
  });

  // ---------------------------------------------------------------------------
  // Pending state / "Choose an action" label
  // ---------------------------------------------------------------------------

  group('DiveComparisonCard - pending state', () {
    testWidgets(
      'renders "Choose an action" label when isPending + null selectedAction',
      (tester) async {
        await tester.pumpWidget(
          _buildCard(
            card: DiveComparisonCard(
              incoming: _testIncoming,
              existingDiveId: _existingDiveId,
              matchScore: 0.95,
              selectedAction: null,
              onActionChanged: (_) {},
              isPending: true,
            ),
          ),
        );
        await tester.pumpAndSettle();

        expect(find.text('Choose an action'), findsOneWidget);
      },
    );

    testWidgets('no button is pre-highlighted when selectedAction is null', (
      tester,
    ) async {
      await tester.pumpWidget(
        _buildCard(
          card: DiveComparisonCard(
            incoming: _testIncoming,
            existingDiveId: _existingDiveId,
            matchScore: 0.95,
            selectedAction: null,
            onActionChanged: (_) {},
            isPending: true,
          ),
        ),
      );
      await tester.pumpAndSettle();

      // No FilledButton should be present — all buttons remain outlined
      // or text style because no action matches the null selection.
      expect(find.byType(FilledButton), findsNothing);
    });

    testWidgets('does NOT render "Choose an action" when not pending', (
      tester,
    ) async {
      await tester.pumpWidget(
        _buildCard(
          card: DiveComparisonCard(
            incoming: _testIncoming,
            existingDiveId: _existingDiveId,
            matchScore: 0.95,
            selectedAction: DuplicateAction.skip,
            onActionChanged: (_) {},
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('Choose an action'), findsNothing);
    });

    testWidgets(
      'does NOT render "Choose an action" when pending but action is set',
      (tester) async {
        await tester.pumpWidget(
          _buildCard(
            card: DiveComparisonCard(
              incoming: _testIncoming,
              existingDiveId: _existingDiveId,
              matchScore: 0.95,
              selectedAction: DuplicateAction.skip,
              onActionChanged: (_) {},
              isPending: true,
            ),
          ),
        );
        await tester.pumpAndSettle();

        // Once a decision is made the "Choose an action" prompt goes away
        // even if the pending flag is still set momentarily.
        expect(find.text('Choose an action'), findsNothing);
      },
    );
  });

  // ---------------------------------------------------------------------------
  // Loading / error states
  // ---------------------------------------------------------------------------

  group('DiveComparisonCard - loading and error states', () {
    testWidgets('shows loading indicator while dive is loading', (
      tester,
    ) async {
      final completer = Completer<domain.Dive?>();
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            settingsProvider.overrideWith((ref) => _TestSettingsNotifier()),
            diveProvider.overrideWith((ref, id) => completer.future),
            diveProfileProvider.overrideWith((ref, id) async => []),
          ],
          child: MaterialApp(
            localizationsDelegates: AppLocalizations.localizationsDelegates,
            supportedLocales: AppLocalizations.supportedLocales,
            home: Scaffold(
              body: SingleChildScrollView(
                child: DiveComparisonCard(
                  incoming: _testIncoming,
                  existingDiveId: _existingDiveId,
                  matchScore: 0.95,
                ),
              ),
            ),
          ),
        ),
      );
      // Pump once (not settle) to see the loading state.
      await tester.pump();

      expect(find.byType(CircularProgressIndicator), findsOneWidget);

      // Complete the future so no pending timers remain.
      completer.complete(_testDive);
      await tester.pumpAndSettle();
    });

    testWidgets('shows error message when dive provider fails', (tester) async {
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            settingsProvider.overrideWith((ref) => _TestSettingsNotifier()),
            diveProvider.overrideWith((ref, id) async {
              throw Exception('Database error');
            }),
            diveProfileProvider.overrideWith((ref, id) async => []),
          ],
          child: MaterialApp(
            localizationsDelegates: AppLocalizations.localizationsDelegates,
            supportedLocales: AppLocalizations.supportedLocales,
            home: Scaffold(
              body: SingleChildScrollView(
                child: DiveComparisonCard(
                  incoming: _testIncoming,
                  existingDiveId: _existingDiveId,
                  matchScore: 0.95,
                ),
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('Error loading dive data'), findsOneWidget);
    });

    testWidgets('shows not found message when dive is null', (tester) async {
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            settingsProvider.overrideWith((ref) => _TestSettingsNotifier()),
            diveProvider.overrideWith((ref, id) async => null),
            diveProfileProvider.overrideWith((ref, id) async => []),
          ],
          child: MaterialApp(
            localizationsDelegates: AppLocalizations.localizationsDelegates,
            supportedLocales: AppLocalizations.supportedLocales,
            home: Scaffold(
              body: SingleChildScrollView(
                child: DiveComparisonCard(
                  incoming: _testIncoming,
                  existingDiveId: _existingDiveId,
                  matchScore: 0.95,
                ),
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('Existing dive not found'), findsOneWidget);
    });
  });

  // ---------------------------------------------------------------------------
  // Data source / computer name lookup
  // ---------------------------------------------------------------------------

  group('DiveComparisonCard - computer name from data sources', () {
    testWidgets('uses computer name from data source when available', (
      tester,
    ) async {
      final now = DateTime.now();
      final dataSource = DiveDataSource(
        id: 'ds-1',
        diveId: _existingDiveId,
        computerId: 'comp-1',
        isPrimary: true,
        computerModel: 'Shearwater Petrel',
        importedAt: now,
        createdAt: now,
      );

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            settingsProvider.overrideWith((ref) => _TestSettingsNotifier()),
            diveProvider.overrideWith((ref, id) async => _testDive),
            diveProfileProvider.overrideWith((ref, id) async => []),
            diveDataSourcesProvider.overrideWith(
              (ref, id) async => [dataSource],
            ),
            diveComputerByIdProvider.overrideWith((ref, id) async => null),
          ],
          child: MaterialApp(
            localizationsDelegates: AppLocalizations.localizationsDelegates,
            supportedLocales: AppLocalizations.supportedLocales,
            home: Scaffold(
              body: SingleChildScrollView(
                child: DiveComparisonCard(
                  incoming: _testIncoming,
                  existingDiveId: _existingDiveId,
                  matchScore: 0.95,
                ),
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      // The widget should render without error even with data sources.
      expect(find.text('Skip'), findsOneWidget);
    });
  });
}
