import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'package:submersion/core/providers/provider.dart';
import 'package:submersion/features/agent_access/domain/agent_access_settings.dart';
import 'package:submersion/features/agent_access/presentation/providers/agent_access_providers.dart';
import 'package:submersion/features/agent_access/presentation/widgets/agent_access_snippets.dart';
import 'package:submersion/features/agent_access/presentation/widgets/agent_access_status_card.dart';
import 'package:submersion/features/settings/presentation/widgets/settings_section_helpers.dart';
import 'package:submersion/shared/widgets/forms/number_field.dart';
import 'package:submersion/shared/widgets/forms/number_input_validation.dart';
import 'package:submersion/l10n/l10n_extension.dart';

/// Settings > Data > Advanced > Data tools > Agent access: the switch, the
/// listener's status, the port, the token and the client snippets.
class AgentAccessPage extends ConsumerStatefulWidget {
  const AgentAccessPage({super.key});

  @override
  ConsumerState<AgentAccessPage> createState() => _AgentAccessPageState();
}

class _AgentAccessPageState extends ConsumerState<AgentAccessPage> {
  String? _token;
  bool _revealed = false;

  @override
  void initState() {
    super.initState();
    ref.read(agentAccessTokenStoreProvider).ensure().then((token) {
      if (mounted) setState(() => _token = token);
    });
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final settings = ref.watch(agentAccessSettingsProvider);
    final notifier = ref.read(agentAccessSettingsProvider.notifier);
    final status = ref.watch(agentAccessStatusProvider).value;
    final url = status?.listening == true
        ? status!.url
        : 'http://127.0.0.1:${settings.port}/mcp';
    final token = _token;
    return Scaffold(
      appBar: AppBar(title: Text(l10n.settings_agentAccess_title)),
      body: ListView(
        padding: const EdgeInsets.symmetric(vertical: 8),
        children: [
          SwitchListTile(
            title: Text(l10n.settings_agentAccess_enable),
            subtitle: Text(l10n.settings_agentAccess_subtitle),
            value: settings.enabled,
            onChanged: notifier.setEnabled,
          ),
          AgentAccessStatusCard(status: status),
          ListTile(
            title: Text(l10n.settings_agentAccess_port),
            subtitle: Text('${settings.port}'),
            trailing: const Icon(Icons.edit_outlined),
            onTap: () => _editPort(settings),
          ),
          ListTile(
            title: Text(l10n.settings_agentAccess_token),
            subtitle: Text(
              token == null
                  ? ''
                  : _revealed
                  ? token
                  : '•' * 24,
            ),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Wrap(
              spacing: 8,
              children: [
                TextButton(
                  onPressed: token == null
                      ? null
                      : () => setState(() => _revealed = !_revealed),
                  child: Text(
                    _revealed
                        ? l10n.settings_agentAccess_hide
                        : l10n.settings_agentAccess_reveal,
                  ),
                ),
                TextButton(
                  onPressed: token == null ? null : () => _copyToken(token),
                  child: Text(l10n.settings_agentAccess_copy),
                ),
                TextButton(
                  onPressed: token == null ? null : _regenerate,
                  child: Text(l10n.settings_agentAccess_regenerate),
                ),
              ],
            ),
          ),
          SwitchListTile(
            title: Text(l10n.settings_agentAccess_confirmWrites),
            subtitle: Text(l10n.settings_agentAccess_confirmWritesSubtitle),
            value: settings.confirmWrites,
            onChanged: notifier.setConfirmWrites,
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
            child: Text(
              l10n.settings_agentAccess_scopeNote,
              style: Theme.of(context).textTheme.bodySmall,
            ),
          ),
          const Divider(height: 1),
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 24, 16, 8),
            child: buildSettingsSectionHeader(
              context,
              l10n.settings_agentAccess_snippets,
            ),
          ),
          if (token != null) AgentAccessSnippets(url: url, token: token),
        ],
      ),
    );
  }

  Future<void> _copyToken(String token) async {
    final messenger = ScaffoldMessenger.of(context);
    final copied = context.l10n.settings_agentAccess_copied;
    await Clipboard.setData(ClipboardData(text: token));
    messenger.showSnackBar(SnackBar(content: Text(copied)));
  }

  Future<void> _regenerate() async {
    final l10n = context.l10n;
    final material = MaterialLocalizations.of(context);
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(l10n.settings_agentAccess_regenerate),
        content: Text(l10n.settings_agentAccess_regenerateConfirm),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: Text(material.cancelButtonLabel),
          ),
          FilledButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: Text(l10n.settings_agentAccess_regenerate),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;
    final token = await ref
        .read(agentAccessControllerProvider)
        .regenerateToken();
    if (mounted) setState(() => _token = token);
  }

  Future<void> _editPort(AgentAccessSettings settings) async {
    final port = await showDialog<int>(
      context: context,
      builder: (context) => _PortDialog(initialPort: settings.port),
    );
    if (!mounted || port == null || port == settings.port) return;
    await ref.read(agentAccessSettingsProvider.notifier).setPort(port);
  }
}

/// Owns its text controller so the closing route can finish animating
/// before the controller goes away.
class _PortDialog extends StatefulWidget {
  const _PortDialog({required this.initialPort});

  final int initialPort;

  @override
  State<_PortDialog> createState() => _PortDialogState();
}

class _PortDialogState extends State<_PortDialog> {
  late final TextEditingController _controller = TextEditingController(
    text: '${widget.initialPort}',
  );
  String? _error;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _submit() {
    final read = readNumber(
      _controller.text,
      integer: true,
      allowNegative: false,
    );
    final value = read is NumberValue ? read.value.toInt() : null;
    if (value == null ||
        value < kAgentAccessMinPort ||
        value > kAgentAccessMaxPort) {
      setState(() => _error = context.l10n.settings_agentAccess_portInvalid);
      return;
    }
    Navigator.of(context).pop(value);
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final material = MaterialLocalizations.of(context);
    return AlertDialog(
      title: Text(l10n.settings_agentAccess_port),
      content: TextField(
        controller: _controller,
        autofocus: true,
        keyboardType: TextInputType.number,
        inputFormatters: numberInputFormatters(),
        decoration: InputDecoration(errorText: _error),
        onSubmitted: (_) => _submit(),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: Text(material.cancelButtonLabel),
        ),
        FilledButton(onPressed: _submit, child: Text(material.okButtonLabel)),
      ],
    );
  }
}
