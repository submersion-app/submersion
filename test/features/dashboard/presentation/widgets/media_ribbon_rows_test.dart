import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/features/dashboard/presentation/providers/media_ribbon_providers.dart';
import 'package:submersion/features/dashboard/presentation/widgets/media_ribbon_card.dart';
import 'package:submersion/features/dashboard/presentation/widgets/recent_sites_map_card.dart';
import 'package:submersion/features/media/data/services/media_source_resolver_registry.dart';
import 'package:submersion/features/media/domain/entities/media_item.dart';
import 'package:submersion/features/media/domain/entities/media_source_type.dart';
import 'package:submersion/features/media/domain/value_objects/media_source_data.dart';
import 'package:submersion/features/media/presentation/providers/media_resolver_providers.dart';
import 'package:submersion/features/media/presentation/widgets/media_item_view.dart';
import 'package:submersion/l10n/arb/app_localizations.dart';

import '../../../../helpers/mock_providers.dart';
import '../../../media_store/support/fake_local_file_resolver.dart';
import '../../../media/presentation/support/media_widget_harness.dart';

final _t0 = DateTime.utc(2026, 1, 1);

MediaItem _photo(String id) => MediaItem(
  id: id,
  diveId: 'd1',
  mediaType: MediaType.photo,
  sourceType: MediaSourceType.platformGallery,
  platformAssetId: 'asset-$id',
  takenAt: _t0,
  createdAt: _t0,
  updatedAt: _t0,
);

/// Paired beside the recent-sites map, the ribbon has a 220 pt tall neighbour
/// to fill, so it lays its tiles out in two rows instead of one. The pair only
/// exists at desktop widths: below 800 the grid dissolves it into a plain
/// stack, where a two-row ribbon would just be a taller card for no reason.
void main() {
  Future<void> pumpRibbon(
    WidgetTester tester, {
    required double width,
    required Widget card,
  }) async {
    final base = await getBaseOverrides();
    final resolver = FakeLocalFileResolver(BytesData(bytes: onePixelPng()));

    tester.view.physicalSize = Size(width, 2000);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          ...base,
          mediaSourceResolverRegistryProvider.overrideWithValue(
            MediaSourceResolverRegistry({
              MediaSourceType.platformGallery: resolver,
            }),
          ),
          recentMediaProvider.overrideWith(
            (ref) async => [for (var i = 0; i < 12; i++) _photo('p$i')],
          ),
        ],
        child: MaterialApp(
          locale: const Locale('en'),
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: Scaffold(body: SingleChildScrollView(child: card)),
        ),
      ),
    );
    await tester.pumpAndSettle();
  }

  /// Distinct tile top offsets: one per laid-out row.
  Set<double> tileRows(WidgetTester tester) => {
    for (final e in find.byType(MediaItemView).evaluate())
      tester.getRect(find.byWidget(e.widget)).top,
  };

  testWidgets('rows: 2 lays tiles out over two rows at desktop width', (
    tester,
  ) async {
    await pumpRibbon(tester, width: 1300, card: const MediaRibbonCard(rows: 2));
    expect(tileRows(tester), hasLength(2));
  });

  testWidgets('rows: 2 collapses to one row below the desktop breakpoint', (
    tester,
  ) async {
    await pumpRibbon(tester, width: 500, card: const MediaRibbonCard(rows: 2));
    expect(tileRows(tester), hasLength(1));
  });

  testWidgets('the default single-row ribbon is unchanged at desktop width', (
    tester,
  ) async {
    await pumpRibbon(tester, width: 1300, card: const MediaRibbonCard());
    expect(tileRows(tester), hasLength(1));
  });

  test('a row count below one is rejected rather than silently ignored', () {
    expect(() => MediaRibbonCard(rows: 0), throwsAssertionError);
    expect(() => MediaRibbonCard(rows: -1), throwsAssertionError);
  });

  testWidgets('two rows fill the height of the recent-sites map beside it', (
    tester,
  ) async {
    await pumpRibbon(tester, width: 1300, card: const MediaRibbonCard(rows: 2));
    final rects = [
      for (final e in find.byType(MediaItemView).evaluate())
        tester.getRect(find.byWidget(e.widget)),
    ];
    final top = rects.map((r) => r.top).reduce((a, b) => a < b ? a : b);
    final bottom = rects.map((r) => r.bottom).reduce((a, b) => a > b ? a : b);
    expect(bottom - top, closeTo(recentSitesMapHeight, 0.01));
  });
}
