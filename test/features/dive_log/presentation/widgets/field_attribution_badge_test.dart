import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/features/dive_log/presentation/widgets/field_attribution_badge.dart';

void main() {
  group('FieldAttributionBadge', () {
    testWidgets('renders nothing when sourceName is null', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(body: FieldAttributionBadge(sourceName: null)),
        ),
      );

      // Should render a SizedBox.shrink() -- no text visible.
      expect(find.byType(Text), findsNothing);
      expect(find.byType(SizedBox), findsOneWidget);
    });

    testWidgets('renders source name text when provided', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(body: FieldAttributionBadge(sourceName: 'Perdix AI')),
        ),
      );

      expect(find.text('Perdix AI'), findsOneWidget);
    });

    testWidgets('renders as a decorated Container badge', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: FieldAttributionBadge(sourceName: 'UDDF Import'),
          ),
        ),
      );

      // Verify the Container with decoration is present.
      final container = tester.widget<Container>(find.byType(Container).first);
      expect(container.decoration, isA<BoxDecoration>());

      final decoration = container.decoration! as BoxDecoration;
      expect(decoration.borderRadius, BorderRadius.circular(4));
    });

    testWidgets('text style uses labelSmall with fontSize 10', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(body: FieldAttributionBadge(sourceName: 'Manual')),
        ),
      );

      final textWidget = tester.widget<Text>(find.text('Manual'));
      expect(textWidget.style?.fontSize, 10);
    });

    testWidgets('renders without sourceName constructor parameter', (
      tester,
    ) async {
      await tester.pumpWidget(
        const MaterialApp(home: Scaffold(body: FieldAttributionBadge())),
      );

      // Default is null, so it should be empty.
      expect(find.byType(Text), findsNothing);
    });
  });
}
