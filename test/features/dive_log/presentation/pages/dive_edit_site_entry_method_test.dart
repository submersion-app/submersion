import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:submersion/core/constants/enums.dart';
import 'package:submersion/core/providers/provider.dart';
import 'package:submersion/features/dive_log/data/repositories/dive_repository_impl.dart';
import 'package:submersion/features/dive_log/domain/entities/dive_prefill.dart';
import 'package:submersion/features/dive_log/presentation/pages/dive_edit_page.dart';
import 'package:submersion/features/dive_log/presentation/providers/dive_providers.dart';
import 'package:submersion/features/dive_sites/domain/entities/dive_site.dart';
import 'package:submersion/features/tank_presets/presentation/providers/tank_preset_providers.dart';
import 'package:submersion/l10n/arb/app_localizations.dart';

import '../../../../helpers/mock_providers.dart';
import '../../../../helpers/test_database.dart';

/// Covers the wiring of [entryExitAfterSiteAssign] into the dive editor.
///
/// Prefill is used as the vehicle because `_applyPrefill` and the site picker
/// share the one `_assignSite` funnel, and prefill needs no modal sheet
/// driving. The rule's own branches (sticky manual overrides, the no-op cases)
/// are covered exhaustively by
/// test/features/dive_log/presentation/utils/entry_exit_autofill_test.dart.
void main() {
  late DiveRepository repository;

  setUp(() async {
    await setUpTestDatabase();
    repository = DiveRepository();
  });

  tearDown(() async {
    await tearDownTestDatabase();
  });

  /// New-dive pages host a continuous animation, so pumpAndSettle never
  /// settles; a bounded pump loop drains async work and animations instead.
  Future<void> pumpFrames(WidgetTester tester) async {
    for (var i = 0; i < 8; i++) {
      await tester.pump(const Duration(milliseconds: 100));
    }
  }

  Future<void> pumpNewDivePage(
    WidgetTester tester, {
    required DiveSite site,
  }) async {
    tester.view.physicalSize = const Size(1200, 4000);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);
    final overrides = await getBaseOverrides();
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          ...overrides,
          diveRepositoryProvider.overrideWithValue(repository),
          diveListNotifierProvider.overrideWith(
            (ref) => DiveListNotifier(repository, ref),
          ),
          customTankPresetsProvider.overrideWith((ref) async => []),
        ],
        child: MaterialApp(
          locale: const Locale('en'),
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: Scaffold(
            body: DiveEditPage(
              embedded: true,
              prefill: DivePrefill(site: site),
            ),
          ),
        ),
      ),
    );
    await pumpFrames(tester);
  }

  /// The Conditions section is collapsed by default and its children are not
  /// mounted while collapsed. The whole header row is the toggle tap target.
  Future<void> expandConditions(WidgetTester tester) async {
    final header = find.text('Conditions');
    await tester.scrollUntilVisible(
      header,
      300,
      scrollable: find.byType(Scrollable).first,
    );
    await tester.tap(header);
    await pumpFrames(tester);
  }

  testWidgets('a site pair snaps onto both rows', (tester) async {
    await pumpNewDivePage(
      tester,
      site: const DiveSite(
        id: 'site-1',
        name: 'Blue Hole',
        entryMethod: EntryMethod.giantStride,
        exitMethod: EntryMethod.ladder,
      ),
    );
    await expandConditions(tester);

    expect(find.text('Giant Stride'), findsOneWidget);
    expect(find.text('Ladder'), findsOneWidget);
  });

  testWidgets('a site entry method alone mirrors onto exit', (tester) async {
    await pumpNewDivePage(
      tester,
      site: const DiveSite(
        id: 'site-1',
        name: 'Blue Hole',
        entryMethod: EntryMethod.boat,
      ),
    );
    await expandConditions(tester);

    // Entry row value + mirrored exit row value.
    expect(find.text('Boat Entry'), findsNWidgets(2));
  });

  testWidgets('a site with no methods leaves both rows unset', (tester) async {
    await pumpNewDivePage(
      tester,
      site: const DiveSite(id: 'site-1', name: 'Blue Hole'),
    );
    await expandConditions(tester);

    for (final method in EntryMethod.values) {
      expect(
        find.text(method.displayName),
        findsNothing,
        reason: '${method.name} must not appear when the site sets nothing',
      );
    }
  });
}
