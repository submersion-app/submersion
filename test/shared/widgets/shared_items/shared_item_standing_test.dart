import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:submersion/core/providers/provider.dart';
import 'package:submersion/features/divers/presentation/providers/diver_providers.dart';
import 'package:submersion/shared/widgets/shared_items/shared_item_standing.dart';

import '../../../helpers/shared_items_fixture.dart';

/// The active profile's standing on a shared item, unknown until the
/// profile has settled (issue #2677 review).
void main() {
  late GatedActiveProfile active;

  setUp(() => active = GatedActiveProfile());

  Future<void> pump(WidgetTester tester, {required String? ownerId}) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          validatedCurrentDiverIdProvider.overrideWith((_) => active.read()),
        ],
        child: MaterialApp(
          home: Consumer(
            builder: (context, ref, _) =>
                Text(watchSharedItemStanding(ref, ownerId: ownerId).name),
          ),
        ),
      ),
    );
    await tester.pump();
  }

  ProviderContainer container(WidgetTester tester) =>
      ProviderScope.containerOf(tester.element(find.byType(Consumer)));

  testWidgets('is unknown until the active profile is read', (tester) async {
    await pump(tester, ownerId: 'a');
    expect(find.text('unknown'), findsOneWidget);
    active.settle('a');
    await tester.pump();
    expect(find.text('owner'), findsOneWidget);
  });

  testWidgets('another profile\'s item stands as other', (tester) async {
    await pump(tester, ownerId: 'a');
    active.settle('b');
    await tester.pump();
    expect(find.text('other'), findsOneWidget);
  });

  testWidgets('is unknown again while a switch re-reads the profile, though '
      'the provider still holds the previous one', (tester) async {
    await pump(tester, ownerId: 'a');
    active.settle('a');
    await tester.pump();
    expect(find.text('owner'), findsOneWidget);

    container(tester).invalidate(validatedCurrentDiverIdProvider);
    await tester.pump();
    expect(container(tester).read(validatedCurrentDiverIdProvider).value, 'a');
    expect(find.text('unknown'), findsOneWidget);

    active.settle('b');
    await tester.pump();
    expect(find.text('other'), findsOneWidget);
  });

  testWidgets('is unknown when the profile cannot be read', (tester) async {
    await pump(tester, ownerId: 'a');
    active.reads.last.completeError(StateError('database unavailable'));
    await tester.pump();
    expect(find.text('unknown'), findsOneWidget);
  });

  testWidgets('no profile or no owner stands as owner, as before sharing', (
    tester,
  ) async {
    await pump(tester, ownerId: null);
    active.settle('a');
    await tester.pump();
    expect(find.text('owner'), findsOneWidget);
  });
}
