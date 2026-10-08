import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:submersion/core/domain/models/incoming_dive_data.dart';
import 'package:submersion/features/dive_import/domain/services/dive_matcher.dart';
import 'package:submersion/features/dive_log/presentation/providers/dive_providers.dart';
import 'package:submersion/features/import_wizard/domain/adapters/import_source_adapter.dart';
import 'package:submersion/features/import_wizard/domain/models/duplicate_action.dart';
import 'package:submersion/features/import_wizard/domain/models/import_bundle.dart';
import 'package:submersion/features/import_wizard/domain/models/import_cancellation_token.dart';
import 'package:submersion/features/import_wizard/domain/models/import_phase.dart';
import 'package:submersion/features/import_wizard/domain/models/unified_import_result.dart';
import 'package:submersion/features/import_wizard/presentation/providers/import_wizard_providers.dart';
import 'package:submersion/features/import_wizard/presentation/widgets/review_step.dart';
import 'package:submersion/features/tags/presentation/providers/tag_providers.dart';
import 'package:submersion/l10n/arb/app_localizations.dart';
import 'package:submersion/shared/widgets/wizard/wizard_step_def.dart';

// Issue #2607: a diver reached the review step of a large download and could
// not find a way to start the import. Each test below pins one way the
// "Import Selected" button was hidden, disabled without a reachable fix, or
// disabled for no reason at all.

class _FakeAdapter implements ImportSourceAdapter {
  @override
  void resetState() {}

  @override
  ImportSourceType get sourceType => ImportSourceType.diveComputer;

  @override
  String get displayName => 'Teric';

  @override
  String get defaultTagName => 'Teric Import';

  @override
  List<WizardStepDef> get acquisitionSteps => const [];

  @override
  Set<DuplicateAction> get supportedDuplicateActions => const {
    DuplicateAction.skip,
    DuplicateAction.importAsNew,
    DuplicateAction.consolidate,
  };

  @override
  Set<DuplicateAction> duplicateActionsFor(ImportEntityType type) =>
      supportedDuplicateActions;

  @override
  Future<ImportBundle> buildBundle() => throw UnimplementedError();

  @override
  Future<ImportBundle> checkDuplicates(ImportBundle bundle) =>
      throw UnimplementedError();

  @override
  Future<UnifiedImportResult> performImport(
    ImportBundle bundle,
    Map<ImportEntityType, Set<int>> selections,
    Map<ImportEntityType, Map<int, DuplicateAction>> duplicateActions, {
    bool retainSourceDiveNumbers = false,
    ImportProgressCallback? onProgress,
    ImportCancellationToken? cancelToken,
  }) => throw UnimplementedError();
}

const _diveCount = 40;

EntityItem _dive(int i) => EntityItem(
  title: 'Dive ${i + 1}',
  subtitle: '',
  diveData: IncomingDiveData(
    startTime: DateTime.utc(2024, 1, 1).add(Duration(days: i)),
    diveNumber: i + 1,
  ),
);

ImportBundle _bundle({Map<int, DiveMatchResult>? matches}) {
  return ImportBundle(
    source: const ImportSourceInfo(
      type: ImportSourceType.diveComputer,
      displayName: 'Teric',
    ),
    groups: {
      ImportEntityType.dives: EntityGroup(
        items: [for (var i = 0; i < _diveCount; i++) _dive(i)],
        duplicateIndices: matches?.keys.toSet() ?? const {},
        matchResults: matches,
      ),
    },
  );
}

Map<int, DiveMatchResult> _allMatched({String? plannedPrefix}) => {
  for (var i = 0; i < _diveCount; i++)
    i: DiveMatchResult(
      diveId: 'existing-$i',
      score: 0.9,
      timeDifferenceMs: 0,
      plannedDiveId: plannedPrefix == null ? null : '$plannedPrefix$i',
    ),
};

Future<void> _pump(
  WidgetTester tester,
  ImportBundle bundle, {
  VoidCallback? onImport,
}) async {
  // Wide enough that the test font's full-width glyphs do not overflow the
  // review header; tall enough that a long list still needs scrolling.
  tester.view.physicalSize = const Size(700, 900);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);

  final notifier = ImportWizardNotifier(_FakeAdapter())..setBundle(bundle);
  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        importWizardNotifierProvider.overrideWith((_) => notifier),
        nextDiveNumberProvider.overrideWith((_) async => 1),
        tagsProvider.overrideWith((_) async => const []),
      ],
      child: MaterialApp(
        locale: const Locale('en'),
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: Scaffold(body: ReviewStep(onImport: onImport ?? () {})),
      ),
    ),
  );
  await tester.pumpAndSettle();
}

Finder get _importButton =>
    find.widgetWithText(FilledButton, 'Import Selected');

bool _importEnabled(WidgetTester tester) =>
    tester.widget<FilledButton>(_importButton).onPressed != null;

void main() {
  group('import options sheet', () {
    testWidgets('has a Done button that hands the Import button back', (
      tester,
    ) async {
      var imported = 0;
      await _pump(tester, _bundle(), onImport: () => imported++);

      await tester.tap(find.text('Options'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Retain source dive numbers'));
      await tester.pumpAndSettle();

      // The sheet sits over the review bar, so the import action is out of
      // reach until the sheet is dismissed.
      expect(_importButton.hitTestable(), findsNothing);

      await tester.tap(find.widgetWithText(FilledButton, 'Done'));
      await tester.pumpAndSettle();

      expect(find.text('Retain source dive numbers'), findsNothing);
      await tester.tap(_importButton.hitTestable());
      expect(imported, 1);
    });

    testWidgets('keeps Done on screen when its content has to scroll', (
      tester,
    ) async {
      await _pump(tester, _bundle());
      // Short enough that the sheet's content outgrows it.
      tester.view.physicalSize = const Size(700, 360);
      await tester.pumpAndSettle();

      await tester.tap(find.text('Options'));
      await tester.pumpAndSettle();

      expect(find.widgetWithText(FilledButton, 'Done').hitTestable(), findsOne);
    });

    testWidgets('shows a drag handle', (tester) async {
      await _pump(tester, _bundle());

      await tester.tap(find.text('Options'));
      await tester.pumpAndSettle();

      final sheet = tester.widget<BottomSheet>(find.byType(BottomSheet));
      expect(sheet.showDragHandle, isTrue);
    });
  });

  group('pending duplicates', () {
    testWidgets('are not counted as skipped while they await a decision', (
      tester,
    ) async {
      await _pump(tester, _bundle(matches: _allMatched()));

      expect(find.text('$_diveCount duplicate(s) need a decision'), findsOne);
      expect(find.text('$_diveCount skipped'), findsNothing);
      expect(_importEnabled(tester), isFalse);
    });

    testWidgets('Review scrolls back to the decision controls', (tester) async {
      await _pump(tester, _bundle(matches: _allMatched()));

      // Scroll the bulk "Skip all" row out of view, as a diver working
      // through a long list would have.
      await tester.drag(
        find.byType(SingleChildScrollView).first,
        const Offset(0, -2000),
      );
      await tester.pumpAndSettle();
      expect(find.text('Skip all ($_diveCount)').hitTestable(), findsNothing);

      await tester.tap(find.widgetWithText(TextButton, 'Review'));
      await tester.pumpAndSettle();

      expect(find.text('Skip all ($_diveCount)').hitTestable(), findsOne);
    });
  });

  // Pins the tab switch only. TabBarView rebuilds a page it brings back at
  // offset 0, so this cannot tell whether Review also scrolled that tab; the
  // single-tab test above covers the scroll itself.
  testWidgets('Review switches to the tab holding the undecided duplicates', (
    tester,
  ) async {
    await _pump(
      tester,
      ImportBundle(
        source: const ImportSourceInfo(
          type: ImportSourceType.uddf,
          displayName: 'logbook.uddf',
        ),
        groups: {
          ImportEntityType.dives: EntityGroup(items: [_dive(0)]),
          ImportEntityType.sites: EntityGroup(
            items: [
              for (var i = 0; i < _diveCount; i++)
                EntityItem(title: 'Site ${i + 1}', subtitle: ''),
            ],
            duplicateIndices: {for (var i = 0; i < _diveCount; i++) i},
          ),
        },
      ),
    );

    expect(find.text('Skip all ($_diveCount)').hitTestable(), findsNothing);

    await tester.tap(find.widgetWithText(TextButton, 'Review'));
    await tester.pumpAndSettle();

    expect(find.text('Skip all ($_diveCount)').hitTestable(), findsOne);
  });

  group('planned-dive fills', () {
    testWidgets('enable Import Selected and are counted in the review bar', (
      tester,
    ) async {
      var imported = 0;
      await _pump(
        tester,
        _bundle(matches: _allMatched(plannedPrefix: 'planned-')),
        onImport: () => imported++,
      );

      expect(find.text('Nothing selected'), findsNothing);
      expect(find.text('$_diveCount filling planned dives'), findsOne);
      expect(_importEnabled(tester), isTrue);

      await tester.tap(_importButton);
      expect(imported, 1);
    });
  });
}
