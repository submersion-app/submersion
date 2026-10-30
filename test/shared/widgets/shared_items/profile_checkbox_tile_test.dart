import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:submersion/features/divers/domain/entities/diver.dart';
import 'package:submersion/shared/widgets/shared_items/profile_checkbox_tile.dart';
import 'package:submersion/shared/widgets/profile_photo/profile_avatar.dart';

/// One profile's checkbox in a profile picker (issues #2046, #2151).
void main() {
  final diver = Diver(
    id: 'son',
    name: 'Sam',
    createdAt: DateTime(2024),
    updatedAt: DateTime(2024),
  );

  testWidgets('shows the profile with its avatar and reports a tick', (
    tester,
  ) async {
    bool? ticked;
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: ProfileCheckboxTile(
            diver: diver,
            value: false,
            onChanged: (v) => ticked = v,
          ),
        ),
      ),
    );
    expect(find.text('Sam'), findsOneWidget);
    expect(find.byType(ProfileAvatar), findsOneWidget);
    await tester.tap(find.text('Sam'));
    expect(ticked, isTrue);
  });
}
