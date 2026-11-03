import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/features/settings/presentation/about_links.dart';
import 'package:submersion/l10n/arb/app_localizations.dart';
import 'package:submersion/shared/utils/browser_launch.dart';

/// Routes url_launcher calls to [onLaunch] and restores the channel after.
void _mockUrlLauncher(Future<Object?> Function(MethodCall call) onLaunch) {
  const channel = MethodChannel('plugins.flutter.io/url_launcher');
  TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
      .setMockMethodCallHandler(channel, onLaunch);
  addTearDown(
    () => TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, null),
  );
}

Widget _guideButton({UrlLaunch? launch}) {
  return MaterialApp(
    locale: const Locale('en'),
    localizationsDelegates: AppLocalizations.localizationsDelegates,
    supportedLocales: AppLocalizations.supportedLocales,
    home: Builder(
      builder: (context) => Scaffold(
        body: ElevatedButton(
          onPressed: () => launch == null
              ? launchUserGuide(context)
              : launchUserGuide(context, launch: launch),
          child: const Text('Guide'),
        ),
      ),
    ),
  );
}

void main() {
  group('launchUserGuide (#4145)', () {
    test('userGuideUrl points to the published guide', () {
      final uri = Uri.parse(userGuideUrl);
      expect(uri.scheme, 'https');
      expect(uri.host, 'submersion.app');
      expect(uri.path, '/guide/');
    });

    testWidgets('opens the guide in an external browser', (tester) async {
      String? launchedUrl;
      bool? useWebView;
      _mockUrlLauncher((call) async {
        if (call.method == 'launch') {
          final args = call.arguments as Map<dynamic, dynamic>;
          launchedUrl = args['url'] as String?;
          useWebView = args['useWebView'] as bool?;
          return true;
        }
        return null;
      });

      await tester.pumpWidget(_guideButton());
      await tester.tap(find.text('Guide'));
      await tester.pumpAndSettle();

      expect(launchedUrl, userGuideUrl);
      expect(useWebView, isFalse);
      expect(find.byType(SnackBar), findsNothing);
    });

    testWidgets('a failed launch offers the guide link to copy', (
      tester,
    ) async {
      final platformCalls = <MethodCall>[];
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(SystemChannels.platform, (call) async {
            platformCalls.add(call);
            return null;
          });
      addTearDown(
        () => TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
            .setMockMethodCallHandler(SystemChannels.platform, null),
      );

      await tester.pumpWidget(_guideButton(launch: (_) async => false));
      await tester.tap(find.text('Guide'));
      await tester.pumpAndSettle();

      expect(find.text('Visit submersion.app/guide'), findsOneWidget);

      await tester.tap(find.byType(SnackBarAction));
      await tester.pump();

      final setData = platformCalls.firstWhere(
        (c) => c.method == 'Clipboard.setData',
      );
      expect((setData.arguments as Map)['text'], userGuideUrl);
    });

    testWidgets('a throwing launch still shows the fallback', (tester) async {
      await tester.pumpWidget(
        _guideButton(
          launch: (_) async => throw PlatformException(code: 'ERROR'),
        ),
      );
      await tester.tap(find.text('Guide'));
      await tester.pumpAndSettle();

      expect(find.text('Visit submersion.app/guide'), findsOneWidget);
    });
  });
}
