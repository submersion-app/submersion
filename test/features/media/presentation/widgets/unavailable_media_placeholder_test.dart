import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/features/media/domain/value_objects/media_source_data.dart';
import 'package:submersion/features/media/presentation/widgets/unavailable_media_placeholder.dart';
import 'package:submersion/l10n/arb/app_localizations.dart';

Widget _wrap(Widget child) => MaterialApp(
  localizationsDelegates: AppLocalizations.localizationsDelegates,
  supportedLocales: AppLocalizations.supportedLocales,
  home: Scaffold(body: child),
);

void main() {
  testWidgets('renders message for notFound', (tester) async {
    await tester.pumpWidget(
      _wrap(
        const UnavailableMediaPlaceholder(
          data: UnavailableData(kind: UnavailableKind.notFound),
        ),
      ),
    );
    expect(find.text('File not found'), findsOneWidget);
  });

  testWidgets('renders origin device label for fromOtherDevice', (
    tester,
  ) async {
    await tester.pumpWidget(
      _wrap(
        const UnavailableMediaPlaceholder(
          data: UnavailableData(
            kind: UnavailableKind.fromOtherDevice,
            originDeviceLabel: "Eric's iPhone",
          ),
        ),
      ),
    );
    expect(find.textContaining("Eric's iPhone"), findsOneWidget);
  });

  testWidgets('renders fromOtherDevice without label', (tester) async {
    await tester.pumpWidget(
      _wrap(
        const UnavailableMediaPlaceholder(
          data: UnavailableData(kind: UnavailableKind.fromOtherDevice),
        ),
      ),
    );
    expect(find.text('From another device'), findsOneWidget);
  });

  testWidgets('renders custom userMessage when provided', (tester) async {
    await tester.pumpWidget(
      _wrap(
        const UnavailableMediaPlaceholder(
          data: UnavailableData(
            kind: UnavailableKind.unauthenticated,
            userMessage: 'Please sign in',
          ),
        ),
      ),
    );
    expect(find.text('Please sign in'), findsOneWidget);
  });

  testWidgets('renders signInRequired with default message', (tester) async {
    await tester.pumpWidget(
      _wrap(
        const UnavailableMediaPlaceholder(
          data: UnavailableData(kind: UnavailableKind.signInRequired),
        ),
      ),
    );
    expect(find.text('Sign in to view'), findsOneWidget);
  });

  testWidgets('renders unauthenticated with default message', (tester) async {
    await tester.pumpWidget(
      _wrap(
        const UnavailableMediaPlaceholder(
          data: UnavailableData(kind: UnavailableKind.unauthenticated),
        ),
      ),
    );
    expect(find.text('Sign in to view'), findsOneWidget);
  });

  testWidgets('renders networkError message', (tester) async {
    await tester.pumpWidget(
      _wrap(
        const UnavailableMediaPlaceholder(
          data: UnavailableData(kind: UnavailableKind.networkError),
        ),
      ),
    );
    expect(find.text("Couldn't connect"), findsOneWidget);
  });
}
