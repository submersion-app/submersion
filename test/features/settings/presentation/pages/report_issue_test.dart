import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/features/settings/presentation/pages/settings_page.dart';
import 'package:submersion/l10n/arb/app_localizations.dart';

void main() {
  group('launchReportIssue', () {
    test('reportIssueUrl points to correct repository', () {
      final uri = Uri.parse(reportIssueUrl);
      expect(uri.host, 'github.com');
      expect(uri.pathSegments, ['submersion-app', 'submersion', 'issues']);
    });

    testWidgets('opens URL via url_launcher when launch succeeds', (
      tester,
    ) async {
      bool launchCalled = false;
      String? launchedUrl;

      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(
            const MethodChannel('plugins.flutter.io/url_launcher'),
            (MethodCall methodCall) async {
              if (methodCall.method == 'launch') {
                launchCalled = true;
                launchedUrl =
                    (methodCall.arguments as Map<dynamic, dynamic>)['url']
                        as String?;
                return true;
              }
              if (methodCall.method == 'canLaunch') return true;
              return null;
            },
          );

      await tester.pumpWidget(
        MaterialApp(
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: Builder(
            builder: (context) => Scaffold(
              body: ElevatedButton(
                onPressed: () => launchReportIssue(context),
                child: const Text('Report'),
              ),
            ),
          ),
        ),
      );

      await tester.tap(find.text('Report'));
      await tester.pumpAndSettle();

      expect(launchCalled, isTrue);
      expect(launchedUrl, reportIssueUrl);
      expect(find.byType(SnackBar), findsNothing);

      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(
            const MethodChannel('plugins.flutter.io/url_launcher'),
            null,
          );
    });

    testWidgets('shows snackbar fallback when launch fails', (tester) async {
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(
            const MethodChannel('plugins.flutter.io/url_launcher'),
            (MethodCall methodCall) async {
              if (methodCall.method == 'launch') return false;
              if (methodCall.method == 'canLaunch') return false;
              return null;
            },
          );

      await tester.pumpWidget(
        MaterialApp(
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: Builder(
            builder: (context) => Scaffold(
              body: ElevatedButton(
                onPressed: () => launchReportIssue(context),
                child: const Text('Report'),
              ),
            ),
          ),
        ),
      );

      await tester.tap(find.text('Report'));
      await tester.pumpAndSettle();

      expect(find.byType(SnackBar), findsOneWidget);

      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(
            const MethodChannel('plugins.flutter.io/url_launcher'),
            null,
          );
    });
  });
}
