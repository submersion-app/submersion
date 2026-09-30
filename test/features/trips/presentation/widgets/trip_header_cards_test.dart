import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:submersion/features/trips/presentation/widgets/trip_header_cards.dart';

/// The trip page's header cards share one height budget (issue #2338), so a
/// full set on a phone still leaves the story room.
void main() {
  /// A card capped the way the real ones are, full of content.
  Widget capped(double fraction) => Builder(
    builder: (context) => ConstrainedBox(
      constraints: BoxConstraints(
        maxHeight: MediaQuery.sizeOf(context).height * fraction,
      ),
      child: const SingleChildScrollView(child: SizedBox(height: 2000)),
    ),
  );

  testWidgets('full cards on a phone leave the story room', (tester) async {
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          appBar: AppBar(title: const Text('Bonaire')),
          body: Column(
            children: [
              TripHeaderCards(
                children: [capped(0.4), capped(0.3), capped(0.25)],
              ),
              const Expanded(child: SizedBox.expand(key: Key('story'))),
            ],
          ),
        ),
      ),
    );
    expect(tester.takeException(), isNull);
    expect(
      tester.getSize(find.byKey(const Key('story'))).height,
      greaterThanOrEqualTo(844 * 0.3),
    );
  });

  testWidgets('short cards take only their own height', (tester) async {
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(
          body: Column(
            children: [
              TripHeaderCards(children: [SizedBox(height: 40)]),
              Expanded(child: SizedBox.expand(key: Key('story'))),
            ],
          ),
        ),
      ),
    );
    expect(tester.getSize(find.byKey(const Key('story'))).height, 844 - 40);
  });
}
