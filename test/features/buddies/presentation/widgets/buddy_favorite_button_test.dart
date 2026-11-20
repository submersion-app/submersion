import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/features/buddies/presentation/widgets/buddy_favorite_button.dart';

import '../../../../helpers/test_app.dart';

void main() {
  testWidgets('a tap writes nothing', (tester) async {
    await tester.pumpWidget(
      testApp(
        child: const Center(child: BuddyFavoriteButton(isFavorite: true)),
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
