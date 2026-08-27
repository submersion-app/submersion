import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:submersion/core/constants/enums.dart';
import 'package:submersion/features/dive_sites/data/repositories/site_repository_impl.dart';
import 'package:submersion/features/dive_sites/domain/entities/dive_site.dart';
import 'package:submersion/features/dive_sites/presentation/pages/site_edit_page.dart';
import 'package:submersion/features/dive_sites/presentation/providers/site_providers.dart';
import 'package:submersion/features/settings/presentation/providers/settings_providers.dart';
import 'package:submersion/l10n/arb/app_localizations.dart';
import 'package:submersion/shared/widgets/forms/form_section.dart';

import '../../../../helpers/test_database.dart';

Widget _buildMergePageHarness({
  required SharedPreferences prefs,
  required SiteRepository siteRepository,
  required List<String> siteIds,
}) {
  return ProviderScope(
    overrides: [
      sharedPreferencesProvider.overrideWithValue(prefs),
      siteRepositoryProvider.overrideWithValue(siteRepository),
    ],
    child: MaterialApp(
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      home: SiteEditPage(mergeSiteIds: siteIds),
    ),
  );
}

void main() {
  late SharedPreferences prefs;
  late SiteRepository siteRepository;

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    prefs = await SharedPreferences.getInstance();
    await setUpTestDatabase();
    siteRepository = SiteRepository();
  });

  tearDown(tearDownTestDatabase);

  /// The cycle button inside the FormSection that owns [rowLabel].
  Finder cycleButtonFor(String rowLabel) => find.descendant(
    of: find.ancestor(
      of: find.text(rowLabel),
      matching: find.byType(FormSection),
    ),
    matching: find.byIcon(Icons.sync_alt),
  );

  testWidgets('merge mode cycles entry method when sites differ', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(900, 3600);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);

    final site1 = await siteRepository.createSite(
      const DiveSite(
        id: 'em-1',
        name: 'Boat Site',
        entryMethod: EntryMethod.boat,
      ),
    );
    final site2 = await siteRepository.createSite(
      const DiveSite(
        id: 'em-2',
        name: 'Boat Site',
        entryMethod: EntryMethod.shore,
      ),
    );

    await tester.pumpWidget(
      _buildMergePageHarness(
        prefs: prefs,
        siteRepository: siteRepository,
        siteIds: [site1.id, site2.id],
      ),
    );
    await tester.pumpAndSettle();
    await tester.scrollUntilVisible(
      find.text('Entry Method'),
      100,
      scrollable: find.byType(Scrollable).first,
    );

    // site1, the first non-empty candidate, wins initially.
    expect(find.text('Boat Entry'), findsOneWidget);

    // Only entry method differs, so exactly one cycle button sits in the
    // Access & safety section.
    final cycleButton = cycleButtonFor('Entry Method');
    expect(cycleButton, findsOneWidget);

    await tester.tap(cycleButton);
    await tester.pumpAndSettle();

    expect(find.text('Shore Entry'), findsOneWidget);
    expect(find.text('Boat Entry'), findsNothing);
  });

  testWidgets('merge mode cycles exit method independently', (tester) async {
    tester.view.physicalSize = const Size(900, 3600);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);

    final site1 = await siteRepository.createSite(
      const DiveSite(id: 'xm-1', name: 'Wall', exitMethod: EntryMethod.ladder),
    );
    final site2 = await siteRepository.createSite(
      const DiveSite(
        id: 'xm-2',
        name: 'Wall',
        exitMethod: EntryMethod.platform,
      ),
    );

    await tester.pumpWidget(
      _buildMergePageHarness(
        prefs: prefs,
        siteRepository: siteRepository,
        siteIds: [site1.id, site2.id],
      ),
    );
    await tester.pumpAndSettle();
    await tester.scrollUntilVisible(
      find.text('Exit Method'),
      100,
      scrollable: find.byType(Scrollable).first,
    );

    expect(find.text('Ladder'), findsOneWidget);

    await tester.tap(cycleButtonFor('Exit Method'));
    await tester.pumpAndSettle();

    expect(find.text('Platform'), findsOneWidget);
    expect(find.text('Ladder'), findsNothing);
  });

  testWidgets('no cycle button when both sites agree on entry method', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(900, 3600);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);

    final site1 = await siteRepository.createSite(
      const DiveSite(id: 'ag-1', name: 'Pier', entryMethod: EntryMethod.jetty),
    );
    final site2 = await siteRepository.createSite(
      const DiveSite(id: 'ag-2', name: 'Pier', entryMethod: EntryMethod.jetty),
    );

    await tester.pumpWidget(
      _buildMergePageHarness(
        prefs: prefs,
        siteRepository: siteRepository,
        siteIds: [site1.id, site2.id],
      ),
    );
    await tester.pumpAndSettle();
    await tester.scrollUntilVisible(
      find.text('Entry Method'),
      100,
      scrollable: find.byType(Scrollable).first,
    );

    expect(find.text('Jetty/Dock'), findsOneWidget);
    expect(cycleButtonFor('Entry Method'), findsNothing);
  });
}
