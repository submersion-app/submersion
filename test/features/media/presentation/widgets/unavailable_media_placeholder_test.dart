import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/features/media/domain/value_objects/media_source_data.dart';
import 'package:submersion/features/media/presentation/widgets/unavailable_media_placeholder.dart';

void main() {
  testWidgets('renders message for notFound', (tester) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(
          body: UnavailableMediaPlaceholder(
            data: UnavailableData(kind: UnavailableKind.notFound),
          ),
        ),
      ),
    );
    expect(find.textContaining('not found'), findsOneWidget);
  });

  testWidgets('renders origin device label for fromOtherDevice', (
    tester,
  ) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(
          body: UnavailableMediaPlaceholder(
            data: UnavailableData(
              kind: UnavailableKind.fromOtherDevice,
              originDeviceLabel: "Eric's iPhone",
            ),
          ),
        ),
      ),
    );
    expect(find.textContaining("Eric's iPhone"), findsOneWidget);
  });

  testWidgets('renders custom userMessage when provided', (tester) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(
          body: UnavailableMediaPlaceholder(
            data: UnavailableData(
              kind: UnavailableKind.unauthenticated,
              userMessage: 'Please sign in',
            ),
          ),
        ),
      ),
    );
    expect(find.text('Please sign in'), findsOneWidget);
  });

  testWidgets('renders signInRequired with default message', (tester) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(
          body: UnavailableMediaPlaceholder(
            data: UnavailableData(kind: UnavailableKind.signInRequired),
          ),
        ),
      ),
    );
    expect(find.textContaining('Sign in'), findsOneWidget);
  });

  testWidgets('renders networkError message', (tester) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(
          body: UnavailableMediaPlaceholder(
            data: UnavailableData(kind: UnavailableKind.networkError),
          ),
        ),
      ),
    );
    expect(find.textContaining('connect'), findsOneWidget);
  });
}
