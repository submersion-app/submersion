import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:submersion/features/dive_sites/presentation/pages/site_map_page.dart';
import 'package:submersion/features/dive_sites/presentation/providers/built_in_sites_providers.dart';
import 'package:submersion/features/dive_sites/presentation/widgets/built_in_overlay_view.dart';
import 'package:submersion/features/site_scape/presentation/site_scape_view.dart';

import '../built_in_map_contract.dart';

void _usePhoneSurface(WidgetTester tester) {
  tester.view.devicePixelRatio = 1.0;
  tester.view.physicalSize = const Size(600, 900);
  addTearDown(() {
    tester.view.resetPhysicalSize();
    tester.view.resetDevicePixelRatio();
  });
}

/// The phone's map page and the built-in catalogue: what it shares with
/// the split pane's map (see `built_in_map_contract.dart`), and the one
/// thing that is its own.
void main() {
  builtInMapContract(map: () => const SiteMapPage(), surface: _usePhoneSurface);

  testWidgets('the zoom-in caption wraps beside the map controls on a phone, '
      'however long its language makes it', (tester) async {
    tester.view.devicePixelRatio = 1.0;
    tester.view.physicalSize = const Size(360, 700);
    addTearDown(() {
      tester.view.resetPhysicalSize();
      tester.view.resetDevicePixelRatio();
    });

    await pumpBuiltInMap(
      tester,
      map: () => const SiteMapPage(),
      // Hungarian's caption is twice the length of the English one.
      locale: const Locale('hu'),
      extraOverrides: [
        visibleBuiltInSitesProvider.overrideWith((ref) async => [builtInA]),
        builtInOverlayTruncatedProvider.overrideWithValue(true),
      ],
    );
    final caption = tester.getRect(
      find.descendant(
        of: find.byType(BuiltInOverlayCaption),
        matching: find.byType(Material),
      ),
    );
    final controls = tester.getRect(find.byType(SiteScapeModeToggle));
    expect(caption.right, lessThanOrEqualTo(controls.left));
    expect(caption.left, greaterThanOrEqualTo(0));
    expect(tester.takeException(), isNull);
  });
}
