import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/features/buddies/presentation/widgets/buddy_favorite_button.dart';

import '../../../../helpers/test_app.dart';

void main() {
  group('BuddyFavoriteButton tap target', () {
    // Measured at the smallest icon any caller uses (the dense list tile).
    Future<Size> pumpAndMeasure(
      WidgetTester tester,
      TargetPlatform platform,
    ) async {
      debugDefaultTargetPlatformOverride = platform;
      addTearDown(() => debugDefaultTargetPlatformOverride = null);
      await tester.pumpWidget(
        testApp(
          child: const Center(
            child: BuddyFavoriteButton(
              buddyId: 'buddy-1',
              isFavorite: false,
              iconSize: 16,
            ),
          ),
        ),
      );
      final size = tester.getSize(find.byType(IconButton));
      debugDefaultTargetPlatformOverride = null;
      return size;
    }

    testWidgets('meets the 48x48 minimum on touch platforms', (tester) async {
      expect(
        await pumpAndMeasure(tester, TargetPlatform.android),
        const Size(48, 48),
      );
      expect(
        await pumpAndMeasure(tester, TargetPlatform.iOS),
        const Size(48, 48),
      );
    });

    testWidgets('keeps a 32x32 floor on pointer-driven desktop', (
      tester,
    ) async {
      expect(
        await pumpAndMeasure(tester, TargetPlatform.macOS),
        const Size(32, 32),
      );
      expect(
        await pumpAndMeasure(tester, TargetPlatform.windows),
        const Size(32, 32),
      );
    });
  });

  testWidgets('read only, a tap writes nothing', (tester) async {
    await tester.pumpWidget(
      testApp(
        child: const Center(
          child: BuddyFavoriteButton(
            buddyId: 'buddy-1',
            isFavorite: true,
            readOnly: true,
          ),
        ),
      ),
    );

    // No button: the star only shows the favourite, so a tap reaches no
    // notifier (none is overridden here, and reading it would fail).
    expect(find.byType(IconButton), findsNothing);
    expect(find.byIcon(Icons.star), findsOneWidget);
    await tester.tap(find.byIcon(Icons.star));
    await tester.pump();
    expect(tester.takeException(), isNull);
  });
}
