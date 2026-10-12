import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:submersion/features/dive_import/domain/services/dive_matcher.dart';
import 'package:submersion/features/import_wizard/domain/adapters/import_source_adapter.dart';
import 'package:submersion/features/import_wizard/domain/models/duplicate_action.dart';
import 'package:submersion/features/import_wizard/domain/models/import_bundle.dart';
import 'package:submersion/features/import_wizard/domain/models/import_cancellation_token.dart';
import 'package:submersion/features/import_wizard/domain/models/import_phase.dart';
import 'package:submersion/features/import_wizard/domain/models/unified_import_result.dart';
import 'package:submersion/features/import_wizard/presentation/providers/import_wizard_providers.dart';
import 'package:submersion/features/import_wizard/presentation/widgets/entity_review_list.dart';
import 'package:submersion/features/import_wizard/presentation/widgets/review_step.dart';
import 'package:submersion/l10n/arb/app_localizations.dart';
import 'package:submersion/shared/widgets/wizard/wizard_step_def.dart';

// A DiveMate logbook on a phone (#3110): seven entity tabs, dive duplicates
// of dives the diver already downloaded from their computer, and a few
// sites, gear and buddies left over from an earlier import attempt.

class _TestAdapter implements ImportSourceAdapter {
  @override
  void resetState() {}

  @override
  ImportSourceType get sourceType => ImportSourceType.uddf;

  @override
  String get displayName => 'DiveMate.ddb';

  @override
  String get defaultTagName => 'DiveMate Import';

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

EntityGroup _group(String name, int count, Set<int> duplicates) => EntityGroup(
  items: [
    for (var i = 0; i < count; i++)
      EntityItem(title: '$name ${i + 1}', subtitle: name),
  ],
  duplicateIndices: duplicates,
);

ImportBundle _diveMateBundle({bool withDiveDuplicates = true}) {
  final diveDuplicates = withDiveDuplicates
      ? const {0, 1, 2, 3}
      : const <int>{};
  return ImportBundle(
    source: const ImportSourceInfo(
      type: ImportSourceType.uddf,
      displayName: 'DiveMate.ddb',
    ),
    groups: {
      ImportEntityType.dives: EntityGroup(
        items: [
          for (var i = 0; i < 12; i++)
            EntityItem(title: 'Dive ${i + 1}', subtitle: '18 m - 45 min'),
        ],
        duplicateIndices: diveDuplicates,
        matchResults: {
          for (final i in diveDuplicates)
            i: DiveMatchResult(
              diveId: 'computer-dive-$i',
              score: 0.9,
              timeDifferenceMs: 0,
            ),
        },
      ),
      ImportEntityType.sites: _group('Site', 10, {3, 7, 9}),
      ImportEntityType.equipment: _group('Gear', 6, {1}),
      ImportEntityType.buddies: _group('Buddy', 5, const {}),
      ImportEntityType.diveCenters: _group('Center', 4, const {}),
      ImportEntityType.diveTypes: _group('Type', 3, const {}),
      ImportEntityType.media: _group('Photo', 8, const {}),
    },
  );
}

void _usePhoneScreen(WidgetTester tester) {
  tester.view.physicalSize = const Size(375, 812);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);
}

Future<ProviderContainer> _pumpReview(
  WidgetTester tester, {
  Locale locale = const Locale('en'),
  bool withDiveDuplicates = true,
}) async {
  final container = ProviderContainer(
    overrides: [
      importWizardNotifierProvider.overrideWith(
        (ref) => ImportWizardNotifier(_TestAdapter()),
      ),
    ],
  );
  addTearDown(container.dispose);
  container
      .read(importWizardNotifierProvider.notifier)
      .setBundle(_diveMateBundle(withDiveDuplicates: withDiveDuplicates));
  await tester.pumpWidget(
    UncontrolledProviderScope(
      container: container,
      child: MaterialApp(
        locale: locale,
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: Scaffold(body: ReviewStep(onImport: () {})),
      ),
    ),
  );
  await tester.pumpAndSettle();
  return container;
}

/// The paragraph that paints [label] inside the tab bar.
RenderParagraph _tabLabel(WidgetTester tester, String label) =>
    tester.renderObject<RenderParagraph>(
      find.descendant(
        of: find.byType(TabBar),
        matching: find.text(label, findRichText: true),
      ),
    );

/// The tab whose label reads [label].
Finder _tab(String label) =>
    find.ancestor(of: find.text(label), matching: find.byType(Tab));

/// The count marked on [label]'s tab, or null when it carries no marker.
String? _markerOn(WidgetTester tester, String label) {
  final badge = find.descendant(of: _tab(label), matching: find.byType(Badge));
  if (badge.evaluate().isEmpty) return null;
  return tester
      .widget<Text>(find.descendant(of: badge, matching: find.byType(Text)))
      .data;
}

/// What a screen reader announces for [label]'s tab.
String _announced(WidgetTester tester, String label) =>
    tester.getSemantics(_tab(label)).getSemanticsData().label;

void main() {
  group('review tabs on a phone (#3110)', () {
    for (final locale in const [Locale('en'), Locale('de')]) {
      testWidgets('every tab label is readable in ${locale.languageCode}', (
        tester,
      ) async {
        _usePhoneScreen(tester);
        // No dive duplicates: the test font draws every glyph a full em
        // wide, which pushes the German "needs decision" pill on a dive card
        // past a phone-width card. Roboto keeps it inside, even at 2x text.
        await _pumpReview(tester, locale: locale, withDiveDuplicates: false);

        final labels = find.descendant(
          of: find.byType(TabBar),
          matching: find.byType(RichText),
        );
        final tabLabels = tester
            .widgetList<RichText>(labels)
            .map((t) => t.text.toPlainText())
            .where((t) => t.contains('('))
            .toList();
        expect(tabLabels, hasLength(7));
        for (final label in tabLabels) {
          final paragraph = _tabLabel(tester, label);
          final needed = paragraph.getMaxIntrinsicWidth(double.infinity);
          expect(
            paragraph.size.width,
            greaterThanOrEqualTo(needed - 0.5),
            reason: '"$label" is cut to ${paragraph.size.width} of $needed',
          );
        }
      });
    }

    testWidgets('a tab that holds undecided duplicates says how many', (
      tester,
    ) async {
      final semantics = tester.ensureSemantics();
      _usePhoneScreen(tester);
      await _pumpReview(tester);

      expect(_markerOn(tester, 'Dives (12)'), '4');
      expect(_markerOn(tester, 'Sites (10)'), '3');
      expect(_markerOn(tester, 'Equipment (6)'), '1');
      for (final undecided in ['Buddies (5)', 'Dive Centers (4)']) {
        expect(_markerOn(tester, undecided), isNull, reason: undecided);
      }
      expect(
        _announced(tester, 'Sites (10)'),
        contains('3 duplicate(s) need a decision'),
      );
      semantics.dispose();
    });

    testWidgets('the marker goes once the tab is decided', (tester) async {
      _usePhoneScreen(tester);
      final container = await _pumpReview(tester);

      container
          .read(importWizardNotifierProvider.notifier)
          .applyBulkAction(ImportEntityType.dives, DuplicateAction.skip);
      await tester.pumpAndSettle();

      expect(_markerOn(tester, 'Dives (12)'), isNull);
      expect(_markerOn(tester, 'Sites (10)'), '3');
      expect(_markerOn(tester, 'Equipment (6)'), '1');
    });
  });

  group('review list header on a phone (#3110)', () {
    testWidgets('the selection count may use the whole header width', (
      tester,
    ) async {
      _usePhoneScreen(tester);
      await _pumpReview(tester);

      final count = tester.renderObject<RenderParagraph>(
        find.descendant(
          of: find.byType(EntityReviewList).first,
          matching: find.textContaining('selected', findRichText: true),
        ),
      );
      // The header pads 16 on each side of a 375-wide screen.
      expect(count.constraints.maxWidth, greaterThanOrEqualTo(375 - 32));
    });

    testWidgets('on a wide screen the count and buttons share one line', (
      tester,
    ) async {
      tester.view.physicalSize = const Size(1200, 900);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);
      await _pumpReview(tester);

      final list = find.byType(EntityReviewList).first;
      final count = tester.getRect(
        find.descendant(of: list, matching: find.textContaining('selected')),
      );
      final selectAll = tester.getRect(
        find.descendant(of: list, matching: find.text('Select All')),
      );
      expect(selectAll.left, greaterThan(count.right));
      expect(
        selectAll.center.dy,
        moreOrLessEquals(count.center.dy, epsilon: 8),
      );
    });
  });
}
