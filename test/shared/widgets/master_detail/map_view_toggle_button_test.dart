import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/shared/widgets/master_detail/map_view_toggle_button.dart';

void main() {
  testWidgets('shows map icon', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          appBar: AppBar(
            actions: [MapViewToggleButton(isActive: false, onToggle: () {})],
          ),
        ),
      ),
    );

    expect(find.byIcon(Icons.map), findsOneWidget);
  });

  testWidgets('shows highlighted style when active', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          appBar: AppBar(
            actions: [MapViewToggleButton(isActive: true, onToggle: () {})],
          ),
        ),
      ),
    );

    final iconButton = tester.widget<IconButton>(find.byType(IconButton));
    expect(iconButton.style?.backgroundColor, isNotNull);
  });

  testWidgets('calls onToggle when pressed', (tester) async {
    var toggleCount = 0;
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          appBar: AppBar(
            actions: [
              MapViewToggleButton(
                isActive: false,
                onToggle: () => toggleCount++,
              ),
            ],
          ),
        ),
      ),
    );

    await tester.tap(find.byIcon(Icons.map));
    expect(toggleCount, 1);
  });

  testWidgets('has Map View tooltip', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          appBar: AppBar(
            actions: [MapViewToggleButton(isActive: false, onToggle: () {})],
          ),
        ),
      ),
    );

    final iconButton = tester.widget<IconButton>(find.byType(IconButton));
    expect(iconButton.tooltip, 'Map View');
  });
}
