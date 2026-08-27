import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:submersion/core/providers/provider.dart';
import 'package:submersion/features/dashboard/presentation/providers/media_ribbon_providers.dart';
import 'package:submersion/features/dashboard/presentation/widgets/media_ribbon_card.dart';
import 'package:submersion/features/dive_log/domain/entities/dive.dart'
    as domain;
import 'package:submersion/features/dive_log/presentation/providers/dive_providers.dart';
import 'package:submersion/features/media/domain/entities/media_item.dart';
import 'package:submersion/features/media/domain/entities/media_source_type.dart';
import 'package:submersion/features/media/presentation/pages/photo_viewer_page.dart';
import 'package:submersion/features/media/presentation/providers/media_providers.dart';
import 'package:submersion/l10n/arb/app_localizations.dart';

import '../../../../helpers/mock_providers.dart';

final _t0 = DateTime.utc(2026, 1, 1);

MediaItem _photo(String id, String diveId) => MediaItem(
  id: id,
  diveId: diveId,
  mediaType: MediaType.photo,
  sourceType: MediaSourceType.platformGallery,
  filePath: '/tmp/$id.jpg',
  takenAt: _t0,
  createdAt: _t0,
  updatedAt: _t0,
);

void main() {
  testWidgets('closing the viewer opened from the ribbon returns to the '
      'dashboard without error', (tester) async {
    final base = await getBaseOverrides();
    final gallery = [
      _photo('p1', 'd1'),
      _photo('p2', 'd1'),
      _photo('p3', 'd1'),
    ];

    final router = GoRouter(
      routes: [
        GoRoute(
          path: '/',
          builder: (_, _) => const Scaffold(
            body: SingleChildScrollView(child: MediaRibbonCard()),
          ),
        ),
      ],
    );

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          ...base,
          // The ribbon shows the newest photo first; tapping it opens the
          // viewer positioned at that photo inside its dive's gallery.
          recentMediaProvider.overrideWith((ref) async => [gallery.last]),
          mediaForDiveProvider('d1').overrideWith((ref) async => gallery),
          diveProvider('d1').overrideWith(
            (ref) async =>
                domain.Dive(id: 'd1', dateTime: DateTime.utc(2026, 1, 1, 9)),
          ),
        ].cast(),
        child: MaterialApp.router(
          locale: const Locale('en'),
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          routerConfig: router,
        ),
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.byType(ClipRRect).first);
    await tester.pumpAndSettle();
    expect(find.byType(PhotoViewerPage), findsOneWidget);

    // Exit via the toolbar close button.
    await tester.tap(find.byIcon(Icons.close));
    await tester.pumpAndSettle();

    expect(find.byType(PhotoViewerPage), findsNothing);
    expect(find.byType(MediaRibbonCard), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}
