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
      bool? useSafariVC;
      bool? useWebView;

      const channel = MethodChannel('plugins.flutter.io/url_launcher');
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(channel, (MethodCall methodCall) async {
            if (methodCall.method == 'launch') {
              launchCalled = true;
              final args = methodCall.arguments as Map<dynamic, dynamic>;
              launchedUrl = args['url'] as String?;
              useSafariVC = args['useSafariVC'] as bool?;
              useWebView = args['useWebView'] as bool?;
              return true;
            }
            if (methodCall.method == 'canLaunch') return true;
            return null;
          });
      addTearDown(
        () => TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
            .setMockMethodCallHandler(channel, null),
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
      expect(useSafariVC, isFalse);
      expect(useWebView, isFalse);
      expect(find.byType(SnackBar), findsNothing);
    });

    testWidgets('shows snackbar fallback when launch fails', (tester) async {
      const channel = MethodChannel('plugins.flutter.io/url_launcher');
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(channel, (MethodCall methodCall) async {
            if (methodCall.method == 'launch') return false;
            if (methodCall.method == 'canLaunch') return false;
            return null;
          });
      addTearDown(
        () => TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
            .setMockMethodCallHandler(channel, null),
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
    });
    testWidgets('shows snackbar when launchUrl throws', (tester) async {
      const channel = MethodChannel('plugins.flutter.io/url_launcher');
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(channel, (MethodCall methodCall) async {
            if (methodCall.method == 'canLaunch') return true;
            if (methodCall.method == 'launch') {
              throw PlatformException(code: 'ERROR');
            }
            return null;
          });
      addTearDown(
        () => TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
            .setMockMethodCallHandler(channel, null),
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
    });
  });
}
