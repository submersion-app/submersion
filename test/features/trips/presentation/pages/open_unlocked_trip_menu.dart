import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

/// Opens the trip page's menu, unlocking the page first: Delete, Remove
/// from my profile and Unhide are whole-record operations, under the lock
/// (issue #4527). Every trip page has the lock, so its absence fails here.
Future<void> openUnlockedTripMenu(WidgetTester tester) async {
  final lock = find.byIcon(Icons.lock_outline);
  expect(lock, findsOneWidget);
  await tester.tap(lock);
  await tester.pumpAndSettle();
  await tester.tap(find.byIcon(Icons.more_vert).last);
}
