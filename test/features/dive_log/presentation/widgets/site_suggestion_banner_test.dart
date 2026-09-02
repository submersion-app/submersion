import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/features/dive_log/presentation/widgets/site_suggestion_banner.dart';
import 'package:submersion/features/dive_sites/data/services/site_matching_service.dart';

import '../../../../helpers/test_app.dart';

void main() {
  Widget banner({
    required ProposalStatus status,
    required bool hasSite,
    PointSource source = PointSource.photo,
    int candidateCount = 1,
    double? distance,
    VoidCallback? onAssign,
    VoidCallback? onChooseNearby,
    VoidCallback? onCreate,
    VoidCallback? onAddLocation,
    VoidCallback? onDismiss,
    Locale? locale,
  }) => testApp(
    locale: locale ?? const Locale('en'),
    child: SiteSuggestionBanner(
      pointSource: source,
      coordinates: '20.5000, -87.2500',
      status: status,
      hasSite: hasSite,
      siteName: 'Blue Hole',
      candidateCount: candidateCount,
      recommendedDistanceMeters: distance,
      onAssign: onAssign,
      onChooseNearby: onChooseNearby,
      onCreate: onCreate,
      onAddLocation: onAddLocation,
      onDismiss: onDismiss ?? () {},
    ),
  );

  testWidgets('siteless clear: Assign primary, Create secondary', (
    tester,
  ) async {
    var assigned = false;
    var created = false;
    await tester.pumpWidget(
      banner(
        status: ProposalStatus.clear,
        hasSite: false,
        distance: 40,
        onAssign: () => assigned = true,
        onCreate: () => created = true,
      ),
    );
    expect(find.text('Location found in photos'), findsOneWidget);
    expect(find.textContaining('Assign Blue Hole'), findsOneWidget);
    expect(find.textContaining('40 m away'), findsOneWidget);
    await tester.tap(find.textContaining('Assign Blue Hole'));
    expect(assigned, isTrue);
    await tester.tap(find.text('Create Site'));
    expect(created, isTrue);
  });

  testWidgets('siteless review: Choose nearby primary, Create secondary', (
    tester,
  ) async {
    var chose = false;
    await tester.pumpWidget(
      banner(
        status: ProposalStatus.review,
        hasSite: false,
        candidateCount: 3,
        onChooseNearby: () => chose = true,
        onCreate: () {},
      ),
    );
    await tester.tap(find.text('Choose nearby site (3)'));
    expect(chose, isTrue);
    expect(find.text('Create Site'), findsOneWidget);
  });

  testWidgets('siteless none: Create only', (tester) async {
    await tester.pumpWidget(
      banner(status: ProposalStatus.none, hasSite: false, onCreate: () {}),
    );
    expect(find.text('Create Site'), findsOneWidget);
    expect(find.byType(OutlinedButton), findsNothing);
  });

  testWidgets('site without coordinates, clear: Add location only', (
    tester,
  ) async {
    var added = false;
    await tester.pumpWidget(
      banner(
        status: ProposalStatus.clear,
        hasSite: true,
        source: PointSource.diveComputer,
        onAddLocation: () => added = true,
      ),
    );
    expect(find.text('Location from dive computer'), findsOneWidget);
    await tester.tap(find.text('Add location to Blue Hole'));
    expect(added, isTrue);
    expect(find.byType(OutlinedButton), findsNothing);
  });

  testWidgets(
    'site without coordinates, review: Add location + Choose nearby',
    (tester) async {
      await tester.pumpWidget(
        banner(
          status: ProposalStatus.review,
          hasSite: true,
          candidateCount: 3,
          onAddLocation: () {},
          onChooseNearby: () {},
        ),
      );
      expect(find.text('Add location to Blue Hole'), findsOneWidget);
      expect(find.text('Choose nearby site (2)'), findsOneWidget);
    },
  );

  testWidgets('dismiss fires', (tester) async {
    var dismissed = false;
    await tester.pumpWidget(
      banner(
        status: ProposalStatus.none,
        hasSite: false,
        onCreate: () {},
        onDismiss: () => dismissed = true,
      ),
    );
    await tester.tap(find.byIcon(Icons.close));
    expect(dismissed, isTrue);
  });

  testWidgets('German at 360 dp does not overflow', (tester) async {
    tester.view.physicalSize = const Size(360, 800);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    await tester.pumpWidget(
      banner(
        status: ProposalStatus.review,
        hasSite: true,
        candidateCount: 3,
        onAddLocation: () {},
        onChooseNearby: () {},
        locale: const Locale('de'),
      ),
    );
    expect(tester.takeException(), isNull);
    expect(find.textContaining('Blue Hole'), findsWidgets);
  });
}
