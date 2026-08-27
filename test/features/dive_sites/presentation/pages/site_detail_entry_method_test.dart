import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:submersion/core/constants/enums.dart';
import 'package:submersion/features/dive_sites/domain/entities/dive_site.dart';
import 'package:submersion/features/dive_sites/presentation/pages/site_detail_page.dart';
import 'package:submersion/features/dive_sites/presentation/providers/site_providers.dart';
import 'package:submersion/l10n/arb/app_localizations.dart';

import '../../../../helpers/mock_providers.dart';

void _setMobileTestSurfaceSize(WidgetTester tester) {
  tester.view.devicePixelRatio = 1.0;
  tester.view.physicalSize = const Size(600, 900);
  addTearDown(() {
    tester.view.resetPhysicalSize();
    tester.view.resetDevicePixelRatio();
  });
}

void main() {
  Future<void> pumpDetail(WidgetTester tester, DiveSite site) async {
    _setMobileTestSurfaceSize(tester);
    final overrides = await getBaseOverrides();
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          ...overrides,
          siteProvider(site.id).overrideWith((_) async => site),
          siteDiveCountProvider(site.id).overrideWith((_) async => 0),
        ],
        child: MaterialApp(
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: SiteDetailPage(siteId: site.id),
        ),
      ),
    );
    await tester.pumpAndSettle();
  }

  testWidgets('the access card renders when entry method is the only field', (
    tester,
  ) async {
    // Guards _hasAccessInfo: without entry/exit in that predicate the whole
    // card stays hidden and the value saves but never displays.
    await pumpDetail(
      tester,
      const DiveSite(
        id: 'em-only',
        name: 'Blue Hole',
        entryMethod: EntryMethod.boat,
      ),
    );

    expect(find.text('Boat Entry'), findsOneWidget);
  });

  testWidgets('the access card shows exit method when it differs', (
    tester,
  ) async {
    await pumpDetail(
      tester,
      const DiveSite(
        id: 'em-pair',
        name: 'Blue Hole',
        entryMethod: EntryMethod.giantStride,
        exitMethod: EntryMethod.ladder,
      ),
    );

    expect(find.text('Giant Stride'), findsOneWidget);
    expect(find.text('Ladder'), findsOneWidget);
  });

  testWidgets('a mirrored exit method is not shown twice', (tester) async {
    await pumpDetail(
      tester,
      const DiveSite(
        id: 'em-mirror',
        name: 'Blue Hole',
        entryMethod: EntryMethod.boat,
        exitMethod: EntryMethod.boat,
      ),
    );

    expect(find.text('Boat Entry'), findsOneWidget);
  });

  testWidgets('a site with no access data shows no entry method', (
    tester,
  ) async {
    await pumpDetail(tester, const DiveSite(id: 'em-none', name: 'Blue Hole'));

    for (final method in EntryMethod.values) {
      expect(find.text(method.displayName), findsNothing);
    }
  });
}
