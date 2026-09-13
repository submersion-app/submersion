import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:submersion/core/providers/provider.dart';
import 'package:submersion/core/services/log_file_service.dart';
import 'package:submersion/features/settings/presentation/providers/debug_log_providers.dart';
import 'package:submersion/features/settings/presentation/providers/settings_providers.dart';
import 'package:submersion/features/settings/presentation/widgets/diagnostics_card.dart';
import 'package:submersion/l10n/arb/app_localizations.dart';

/// Drive a flow that mixes fake-clock waits (the version lookup's timeout)
/// with real file IO, which only advances outside the fake-async zone.
/// Alternates the two until [done] holds, with a bound so a regression fails
/// instead of hanging. A fixed round count was flaky on a loaded machine.
Future<void> pumpUntil(WidgetTester tester, bool Function() done) async {
  for (var i = 0; i < 50 && !done(); i++) {
    await tester.pump(const Duration(milliseconds: 500));
    await tester.runAsync(
      () => Future<void>.delayed(const Duration(milliseconds: 20)),
    );
  }
}

void main() {
  late Directory tempDir;
  late LogFileService service;
  late SharedPreferences prefs;
  late List<MethodCall> clipboardCalls;

  setUp(() async {
    tempDir = Directory.systemTemp.createTempSync('diagnostics_card_test_');
    service = LogFileService(logDirectory: tempDir.path);
    await service.initialize();
    SharedPreferences.setMockInitialValues({});
    prefs = await SharedPreferences.getInstance();

    clipboardCalls = [];
    TestWidgetsFlutterBinding.ensureInitialized();
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(SystemChannels.platform, (call) async {
          clipboardCalls.add(call);
          return null;
        });
  });

  tearDown(() {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(SystemChannels.platform, null);
    tempDir.deleteSync(recursive: true);
  });

  Widget buildCard({bool canOpenFolder = true, FolderLauncher? launcher}) {
    final router = GoRouter(
      routes: [
        GoRoute(
          path: '/',
          builder: (context, state) => Scaffold(
            body: DiagnosticsCard(
              canOpenFolder: canOpenFolder,
              folderLauncher: launcher,
            ),
          ),
        ),
        GoRoute(
          path: '/settings/debug-logs',
          builder: (context, state) => const Text('log viewer route'),
        ),
      ],
    );
    return ProviderScope(
      overrides: [
        logFileServiceProvider.overrideWithValue(service),
        sharedPreferencesProvider.overrideWithValue(prefs),
      ],
      child: MaterialApp.router(
        locale: const Locale('en'),
        routerConfig: router,
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
      ),
    );
  }

  testWidgets('offers view log and copy diagnostics', (tester) async {
    await tester.pumpWidget(buildCard());
    await tester.pumpAndSettle();

    expect(find.text('View log'), findsOneWidget);
    expect(find.text('Copy diagnostics'), findsOneWidget);
  });

  testWidgets('offers "Open log folder" only where a folder can be opened', (
    tester,
  ) async {
    await tester.pumpWidget(buildCard(canOpenFolder: false));
    await tester.pumpAndSettle();
    expect(find.text('Open log folder'), findsNothing);

    await tester.pumpWidget(buildCard());
    await tester.pumpAndSettle();
    expect(find.text('Open log folder'), findsOneWidget);
  });

  testWidgets('"View log" opens the log viewer route', (tester) async {
    await tester.pumpWidget(buildCard());
    await tester.pumpAndSettle();

    await tester.tap(find.text('View log'));
    await tester.pumpAndSettle();

    expect(find.text('log viewer route'), findsOneWidget);
  });

  testWidgets('"Copy diagnostics" copies the report and confirms it', (
    tester,
  ) async {
    File(
      service.logFilePath,
    ).writeAsStringSync('[2026-09-12T09:00:00.000] [APP] [ERROR] boom\n');

    await tester.pumpWidget(buildCard());
    await tester.pumpAndSettle();

    await tester.tap(find.text('Copy diagnostics'));
    await pumpUntil(
      tester,
      () => clipboardCalls.any((c) => c.method == 'Clipboard.setData'),
    );
    await tester.pumpAndSettle();

    final setData = clipboardCalls.where(
      (c) => c.method == 'Clipboard.setData',
    );
    expect(setData, hasLength(1));
    final text =
        (setData.single.arguments as Map<dynamic, dynamic>)['text'] as String;
    expect(text, startsWith('=== Submersion debug log ==='));
    expect(text, contains('verbose logging: off'));
    expect(text, contains('[APP] [ERROR] boom'));
    expect(find.text('Diagnostics copied to clipboard'), findsOneWidget);
  });

  testWidgets('a failed "Copy diagnostics" says so instead of confirming', (
    tester,
  ) async {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(SystemChannels.platform, (call) async {
          if (call.method == 'Clipboard.setData') {
            throw PlatformException(code: 'clipboard', message: 'denied');
          }
          return null;
        });

    await tester.pumpWidget(buildCard());
    await tester.pumpAndSettle();

    await tester.tap(find.text('Copy diagnostics'));
    await pumpUntil(
      tester,
      () => find
          .textContaining('Could not copy diagnostics:')
          .evaluate()
          .isNotEmpty,
    );
    await tester.pumpAndSettle();

    expect(find.text('Diagnostics copied to clipboard'), findsNothing);
    expect(find.textContaining('Could not copy diagnostics:'), findsOneWidget);
  });

  testWidgets('"Open log folder" hands the log directory to the launcher', (
    tester,
  ) async {
    final launched = <Uri>[];
    await tester.pumpWidget(
      buildCard(
        launcher: (uri) async {
          launched.add(uri);
          return true;
        },
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.text('Open log folder'));
    await tester.pumpAndSettle();

    expect(launched, [Uri.directory(service.logDirectory)]);
    expect(find.byType(SnackBar), findsNothing);
  });

  testWidgets('a refused "Open log folder" shows where the log lives', (
    tester,
  ) async {
    await tester.pumpWidget(buildCard(launcher: (_) async => false));
    await tester.pumpAndSettle();

    await tester.tap(find.text('Open log folder'));
    await tester.pumpAndSettle();

    expect(
      find.text(
        'Could not open the log folder. It is at: ${service.logDirectory}',
      ),
      findsOneWidget,
    );
  });
}
