import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:image/image.dart' as img;
import 'package:submersion/core/providers/provider.dart';
import 'package:submersion/features/dive_centers/domain/entities/dive_center.dart';
import 'package:submersion/features/dive_centers/presentation/pages/dive_center_detail_page.dart';
import 'package:submersion/features/dive_centers/presentation/providers/dive_center_providers.dart';
import 'package:submersion/features/dive_centers/presentation/widgets/dive_center_avatar.dart';
import 'package:submersion/l10n/arb/app_localizations.dart';

import '../../../../helpers/mock_providers.dart';

/// The dive center detail page draws the center's logo (#4460).
void main() {
  final image = img.Image(width: 32, height: 32);
  img.fill(image, color: img.ColorRgb8(0, 90, 160));
  final logo = Uint8List.fromList(img.encodeJpg(image, quality: 80));

  final center = DiveCenter(
    id: 'center-logo',
    name: 'Toucan Diving',
    latitude: 12.15,
    longitude: -68.28,
    logo: logo,
    createdAt: DateTime(2026, 1, 1),
    updatedAt: DateTime(2026, 1, 1),
  );

  Finder glyphs({bool skipOffstage = true}) => find.byWidgetPredicate(
    (w) => w is DiveCenterMarkerGlyph && identical(w.logo, logo),
    skipOffstage: skipOffstage,
  );

  Future<void> pumpDetail(WidgetTester tester, {required bool embedded}) async {
    tester.view.devicePixelRatio = 1.0;
    tester.view.physicalSize = const Size(600, 1400);
    addTearDown(() {
      tester.view.resetPhysicalSize();
      tester.view.resetDevicePixelRatio();
    });
    final overrides = await getBaseOverrides();
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          ...overrides,
          diveCenterByIdProvider(center.id).overrideWith((ref) async => center),
          diveCenterDiveCountProvider(center.id).overrideWith((ref) async => 0),
        ].cast(),
        child: MaterialApp(
          locale: const Locale('en'),
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: Scaffold(
            body: DiveCenterDetailPage(centerId: center.id, embedded: embedded),
          ),
        ),
      ),
    );
    await tester.pump();
    await tester.pump(const Duration(seconds: 1));
  }

  testWidgets('the embedded header and the body header show the logo', (
    tester,
  ) async {
    await pumpDetail(tester, embedded: true);

    final avatars = find.byWidgetPredicate(
      (w) => w is DiveCenterAvatar && identical(w.logo, logo),
    );
    // The embedded bar's 40 px tile and the 64 px header tile.
    expect(avatars, findsAtLeastNWidgets(2));
    expect(find.byIcon(Icons.store), findsNothing);
  });

  testWidgets('the preview and full-screen map markers show the logo', (
    tester,
  ) async {
    await pumpDetail(tester, embedded: false);
    expect(glyphs(), findsOneWidget);

    await tester.tap(find.byIcon(Icons.fullscreen));
    await tester.pump();
    await tester.pump(const Duration(seconds: 1));

    // The full-screen route's marker on top, the preview's beneath it.
    expect(glyphs(), findsOneWidget);
    expect(glyphs(skipOffstage: false), findsNWidgets(2));
  });
}
