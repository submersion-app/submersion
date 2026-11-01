import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'package:submersion/l10n/l10n_extension.dart';

/// One line for `claude mcp add`.
String claudeCodeSnippet({required String url, required String token}) =>
    'claude mcp add --transport http submersion $url '
    '--header "Authorization: Bearer $token"';

/// A `claude_desktop_config.json` entry that bridges stdio to the loopback
/// server with the community `mcp-remote` package. The token travels through
/// `env` because Claude Desktop mangles spaces inside `args`.
String claudeDesktopSnippet({required String url, required String token}) =>
    const JsonEncoder.withIndent('  ').convert({
      'mcpServers': {
        'submersion': {
          'command': 'npx',
          'args': [
            '-y',
            'mcp-remote',
            url,
            '--transport',
            'http-only',
            '--header',
            'Authorization:\${AUTH_HEADER}',
          ],
          'env': {'AUTH_HEADER': 'Bearer $token'},
        },
      },
    });

/// The two facts any other client needs.
String genericSnippet({required String url, required String token}) =>
    'URL: $url\nHeader: Authorization: Bearer $token';

/// Copies [text] and confirms it with a toast. The messenger is taken
/// before the await so an unmounted context cannot be read afterwards.
Future<void> copyWithToast(BuildContext context, String text) async {
  final messenger = ScaffoldMessenger.of(context);
  final copied = context.l10n.settings_agentAccess_copied;
  await Clipboard.setData(ClipboardData(text: text));
  messenger.showSnackBar(SnackBar(content: Text(copied)));
}

/// Three copy rows, one per client kind. Each snippet is copy-ready, so it
/// carries the token; the page itself keeps the token masked on screen.
class AgentAccessSnippets extends StatelessWidget {
  const AgentAccessSnippets({
    super.key,
    required this.url,
    required this.token,
  });

  final String url;
  final String token;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    Widget row(String title, String Function() snippet) => ListTile(
      leading: const Icon(Icons.content_copy),
      title: Text(title),
      onTap: () => copyWithToast(context, snippet()),
    );
    return Column(
      children: [
        row(
          l10n.settings_agentAccess_claudeCode,
          () => claudeCodeSnippet(url: url, token: token),
        ),
        row(
          l10n.settings_agentAccess_claudeDesktop,
          () => claudeDesktopSnippet(url: url, token: token),
        ),
        row(
          l10n.settings_agentAccess_generic,
          () => genericSnippet(url: url, token: token),
        ),
      ],
    );
  }
}
