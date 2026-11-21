import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/core/constants/enums.dart';
import 'package:submersion/features/buddies/domain/entities/buddy.dart';
import 'package:submersion/features/buddies/presentation/providers/buddy_providers.dart';
import 'package:submersion/features/buddies/presentation/widgets/dense_buddy_list_tile.dart';
import 'package:submersion/shared/widgets/record_list_chevron.dart';

import '../../../../helpers/test_app.dart';
import '../../helpers/fake_buddy_list_notifier.dart';
import '../../../../helpers/record_chevron_expectations.dart';

Buddy _makeBuddy({
  String id = 'test-id',
  String name = 'Alice Smith',
  String? certificationLevel = 'openWater',
  String? certificationAgency,
}) {
  final now = DateTime(2024, 1, 1);
  return Buddy(
    id: id,
    name: name,
    certificationLevel: certificationLevel,
    certificationAgency: certificationAgency,
    createdAt: now,
    updatedAt: now,
  );
}

void main() {
  group('DenseBuddyListTile', () {
    testWidgets('renders buddy name', (tester) async {
      await tester.pumpWidget(
        testApp(
          child: DenseBuddyListTile(buddy: _makeBuddy(name: 'Bob Jones')),
        ),
      );

      expect(find.text('Bob Jones'), findsOneWidget);
      expect(find.byIcon(Icons.chevron_right), findsOneWidget);
    });

    testWidgets('renders cert level when present', (tester) async {
      await tester.pumpWidget(
        testApp(
          child: DenseBuddyListTile(
            buddy: _makeBuddy(
              certificationLevel: CertificationLevel.advancedOpenWater.name,
            ),
          ),
        ),
      );

      expect(find.text('Advanced Open Water'), findsOneWidget);
    });

    testWidgets('renders dive count when provided', (tester) async {
      await tester.pumpWidget(
        testApp(child: DenseBuddyListTile(buddy: _makeBuddy(), diveCount: 42)),
      );

      expect(find.text('42'), findsOneWidget);
    });

    testWidgets('handles null cert level gracefully', (tester) async {
      await tester.pumpWidget(
        testApp(
          child: DenseBuddyListTile(
            buddy: _makeBuddy(certificationLevel: null),
          ),
        ),
      );

      expect(find.text('Alice Smith'), findsOneWidget);
      // Cert level placeholder is empty — no cert text present
      expect(find.text('Open Water'), findsNothing);
    });

    testWidgets('handles null dive count gracefully', (tester) async {
      await tester.pumpWidget(
        testApp(
          child: DenseBuddyListTile(buddy: _makeBuddy(), diveCount: null),
        ),
      );

      expect(find.text('Alice Smith'), findsOneWidget);
    });

    testWidgets('applies selection highlight when isSelected is true', (
      tester,
    ) async {
      await tester.pumpWidget(
        testApp(
          child: DenseBuddyListTile(buddy: _makeBuddy(), isSelected: true),
        ),
      );

      final decoratedBox = tester.widget<DecoratedBox>(
        find.byType(DecoratedBox),
      );
      final decoration = decoratedBox.decoration as BoxDecoration;
      expect(decoration.color, isNotNull);
    });

    testWidgets('no selection highlight when isSelected is false', (
      tester,
    ) async {
      await tester.pumpWidget(
        testApp(
          child: DenseBuddyListTile(buddy: _makeBuddy(), isSelected: false),
        ),
      );

      final decoratedBox = tester.widget<DecoratedBox>(
        find.byType(DecoratedBox),
      );
      final decoration = decoratedBox.decoration as BoxDecoration;
      expect(decoration.color, isNull);
    });

    testWidgets('calls onTap when tapped', (tester) async {
      var tapped = false;
      await tester.pumpWidget(
        testApp(
          child: DenseBuddyListTile(
            buddy: _makeBuddy(),
            onTap: () => tapped = true,
          ),
        ),
      );

      // The favorite star's own IconButton also builds an InkWell, so the
      // row's is disambiguated by position: it wraps the whole tile and is
      // therefore built first.
      await tester.tap(find.byType(InkWell).first);
      expect(tapped, isTrue);
    });

    group('favorite star (issue #1336)', () {
      testWidgets('shows a filled star for a favorite buddy', (tester) async {
        await tester.pumpWidget(
          testApp(
            child: DenseBuddyListTile(
              buddy: _makeBuddy().copyWith(isFavorite: true),
            ),
          ),
        );

        expect(find.byIcon(Icons.star), findsOneWidget);
        expect(find.byIcon(Icons.star_border), findsNothing);
      });

      testWidgets('tapping the star writes nothing and opens the buddy', (
        tester,
      ) async {
        final notifier = FakeBuddyListNotifier();
        var tapped = false;
        await tester.pumpWidget(
          testApp(
            overrides: [
              buddyListNotifierProvider.overrideWith((ref) => notifier),
            ],
            child: DenseBuddyListTile(
              buddy: _makeBuddy(id: 'dense-1'),
              onTap: () => tapped = true,
            ),
          ),
        );

        await tester.tap(find.byIcon(Icons.star_border));
        await tester.pump();

        // The star only shows the favourite (issue #4527, plan 12): a
        // tap on it is the row's.
        expect(notifier.calls, isEmpty);
        expect(tapped, isTrue);
      });
    });
  });

  testWidgets('chevron ends one row padding from the edge (#4639)', (
    tester,
  ) async {
    await tester.pumpWidget(
      testApp(
        child: DenseBuddyListTile(buddy: _makeBuddy(name: 'Bob Jones')),
      ),
    );

    expectChevronAtEndPadding(
      tester,
      bounds: tester.getRect(find.byType(DenseBuddyListTile)),
      padding: kRecordRowDenseHorizontalPadding,
    );
  });
}
