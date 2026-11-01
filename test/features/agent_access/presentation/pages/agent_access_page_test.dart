import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:submersion/core/providers/provider.dart';
import 'package:submersion/features/agent_access/data/agent_access_token_store.dart';
import 'package:submersion/features/agent_access/data/server/agent_access_server.dart';
import 'package:submersion/features/agent_access/presentation/pages/agent_access_page.dart';
import 'package:submersion/features/agent_access/presentation/providers/agent_access_providers.dart';
import 'package:submersion/features/agent_access/presentation/widgets/agent_access_snippets.dart';
import 'package:submersion/features/settings/presentation/providers/settings_providers.dart';

import '../../../../helpers/test_app.dart';
import '../../../../support/fake_keychain_storage.dart';

/// A controller that never touches the real server.
class _QuietController extends AgentAccessController {
  _QuietController(this.testRef) : super(testRef);
  final Ref testRef;
  int regenerations = 0;

  @override
  Future<void> sync() async {}

  @override
  Future<String> regenerateToken() async {
    regenerations++;
    return testRef.read(agentAccessTokenStoreProvider).regenerate();
  }
}

void main() {
  const token = 'tok_0123456789abcdefghijklmnopqrstuvwxyzABCDEF';
  late InMemoryKeychain keychain;
  late SharedPreferences prefs;
  late _QuietController controller;
  final clipboard = <String>[];

  setUp(() async {
    SharedPreferences.setMockInitialValues({'agent_access_enabled': true});
    prefs = await SharedPreferences.getInstance();
    keychain = InMemoryKeychain()..values[AgentAccessTokenStore.key] = token;
    clipboard.clear();
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(SystemChannels.platform, (call) async {
          if (call.method == 'Clipboard.setData') {
            clipboard.add((call.arguments as Map)['text'] as String);
          }
          return null;
        });
  });

  tearDown(() {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(SystemChannels.platform, null);
  });

  Future<void> pump(
    WidgetTester tester, {
    AgentAccessStatus status = const AgentAccessStatus(
      listening: true,
      port: 47831,
    ),
  }) async {
    await tester.binding.setSurfaceSize(const Size(500, 1400));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    await tester.pumpWidget(
      testApp(
        locale: const Locale('en'),
        overrides: [
          sharedPreferencesProvider.overrideWithValue(prefs),
          agentAccessTokenStoreProvider.overrideWithValue(
            AgentAccessTokenStore(storage: keychain),
          ),
          agentAccessStatusProvider.overrideWith((ref) => Stream.value(status)),
          agentAccessControllerProvider.overrideWith((ref) {
            controller = _QuietController(ref);
            return controller;
          }),
        ],
        child: const AgentAccessPage(),
      ),
    );
    await tester.pumpAndSettle();
  }

  group('AgentAccessPage', () {
    testWidgets('shows the URL and keeps the token masked', (tester) async {
      await pump(tester);
      expect(find.text('Agent access'), findsWidgets);
      expect(find.text('http://127.0.0.1:47831/mcp'), findsOneWidget);
      expect(find.text('Listening'), findsOneWidget);
      expect(find.textContaining(token), findsNothing);
      expect(
        find.text('Agents can see every diver profile on this computer.'),
        findsOneWidget,
      );
    });

    testWidgets('reveal shows the token', (tester) async {
      await pump(tester);
      await tester.tap(find.text('Reveal'));
      await tester.pumpAndSettle();
      expect(find.text(token), findsOneWidget);
    });

    testWidgets('copy puts the Claude Code snippet on the clipboard', (
      tester,
    ) async {
      await pump(tester);
      await tester.tap(find.text('Claude Code'));
      await tester.pumpAndSettle();
      expect(clipboard, hasLength(1));
      expect(
        clipboard.single,
        claudeCodeSnippet(url: 'http://127.0.0.1:47831/mcp', token: token),
      );
      expect(clipboard.single, contains('claude mcp add --transport http'));
      expect(find.text('Copied'), findsOneWidget);
    });

    testWidgets('toggling enable writes the setting', (tester) async {
      await pump(tester);
      final toggle = find.widgetWithText(SwitchListTile, 'Enable agent access');
      expect(tester.widget<SwitchListTile>(toggle).value, isTrue);
      await tester.tap(toggle);
      await tester.pumpAndSettle();
      expect(prefs.getBool('agent_access_enabled'), isFalse);
    });

    testWidgets('confirm-writes switch is on by default and persists', (
      tester,
    ) async {
      await pump(tester);
      final toggle = find.widgetWithText(
        SwitchListTile,
        'Ask before applying changes',
      );
      expect(tester.widget<SwitchListTile>(toggle).value, isTrue);
      await tester.ensureVisible(toggle);
      await tester.tap(toggle);
      await tester.pumpAndSettle();
      expect(prefs.getBool('agent_access_confirm_writes'), isFalse);
    });

    testWidgets('port in use error is shown', (tester) async {
      await pump(
        tester,
        status: const AgentAccessStatus(
          listening: false,
          port: 47831,
          error: 'Port 47831 is already in use (Address already in use).',
          portInUse: true,
        ),
      );
      expect(find.text('Stopped'), findsOneWidget);
      expect(find.text('Port 47831 is already in use'), findsOneWidget);
    });

    testWidgets('any other error is shown as written', (tester) async {
      await pump(
        tester,
        status: const AgentAccessStatus(
          listening: false,
          port: 47831,
          error: 'Could not read the access token: keychain down',
        ),
      );
      expect(find.text('Stopped'), findsOneWidget);
      expect(find.text('Port 47831 is already in use'), findsNothing);
      expect(
        find.text('Could not read the access token: keychain down'),
        findsOneWidget,
      );
    });

    testWidgets('regenerate asks first, then rotates the token', (
      tester,
    ) async {
      await pump(tester);
      await tester.ensureVisible(find.text('Regenerate'));
      await tester.tap(find.text('Regenerate'));
      await tester.pumpAndSettle();
      expect(
        find.text('Every connected agent will need the new token. Continue?'),
        findsOneWidget,
      );
      await tester.tap(find.text('Regenerate').last);
      await tester.pumpAndSettle();
      expect(controller.regenerations, 1);
      expect(keychain.values[AgentAccessTokenStore.key], isNot(token));
    });
  });

  group('snippets', () {
    test('Claude Desktop snippet carries the token through env', () {
      final s = claudeDesktopSnippet(
        url: 'http://127.0.0.1:47831/mcp',
        token: 'abc',
      );
      expect(s, contains('"mcp-remote"'));
      expect(s, contains('"http://127.0.0.1:47831/mcp"'));
      expect(s, contains('"--transport"'));
      expect(s, contains('"http-only"'));
      expect(s, contains('"Authorization:\${AUTH_HEADER}"'));
      expect(s, contains('"AUTH_HEADER": "Bearer abc"'));
    });

    test('generic snippet names URL and header', () {
      final s = genericSnippet(url: 'http://127.0.0.1:1/mcp', token: 'abc');
      expect(
        s,
        'URL: http://127.0.0.1:1/mcp\nHeader: Authorization: Bearer abc',
      );
    });
  });
}
