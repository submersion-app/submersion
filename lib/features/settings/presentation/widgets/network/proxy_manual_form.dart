import 'dart:convert';

import 'package:flutter/material.dart';

import 'package:submersion/core/network/proxy/proxy_controller.dart';
import 'package:submersion/core/network/proxy/proxy_credentials.dart';
import 'package:submersion/core/network/proxy/proxy_settings.dart';
import 'package:submersion/core/providers/provider.dart';
import 'package:submersion/core/services/logger_service.dart';
import 'package:submersion/features/settings/presentation/providers/network_proxy_providers.dart';
import 'package:submersion/l10n/arb/app_localizations.dart';
import 'package:submersion/shared/widgets/forms/number_field.dart';
import 'package:submersion/shared/widgets/forms/number_input_validation.dart';
import 'package:submersion/l10n/l10n_extension.dart';

/// The manual proxy fields. Edits go to the draft provider as typed and take
/// effect only on Save, so a half-typed host never reroutes live traffic.
class ProxyManualForm extends ConsumerStatefulWidget {
  const ProxyManualForm({super.key, required this.controller});

  final ProxyController controller;

  @override
  ConsumerState<ProxyManualForm> createState() => _ProxyManualFormState();
}

class _ProxyManualFormState extends ConsumerState<ProxyManualForm> {
  static const _log = LoggerService('ProxySettings');

  late ProxyType _type;
  late final TextEditingController _host;
  late final TextEditingController _port;
  late final TextEditingController _username;
  late final TextEditingController _password;
  var _showPassword = false;
  var _saving = false;
  String? _hostError;
  String? _portError;
  String? _usernameError;
  String? _passwordError;

  @override
  void initState() {
    super.initState();
    final draft = ref.read(networkProxyDraftProvider);
    final saved = widget.controller.state.settings;
    _type = draft?.type ?? saved.type;
    _host = TextEditingController(text: draft?.host ?? saved.host);
    _port = TextEditingController(
      text: draft?.port ?? saved.port?.toString() ?? '',
    );
    _username = TextEditingController(text: draft?.username ?? saved.username);
    _password = TextEditingController(
      text: draft?.password ?? widget.controller.manualPassword ?? '',
    );
  }

  @override
  void dispose() {
    _host.dispose();
    _port.dispose();
    _username.dispose();
    _password.dispose();
    super.dispose();
  }

  void _recordDraft() {
    ref
        .read(networkProxyDraftProvider.notifier)
        .update(
          NetworkProxyDraft(
            type: _type,
            host: _host.text,
            port: _port.text,
            username: _username.text,
            password: _password.text,
          ),
        );
  }

  Future<void> _save() async {
    final l10n = context.l10n;
    final parsed = parseProxyHostInput(_host.text);
    final host = parsed.host;
    final port = readProxyPort(_port.text) ?? parsed.port;
    final username = _username.text;
    final password = _password.text;
    final problem = checkProxyCredentials(_type, username, password);
    // The SOCKS limit is in UTF-8 bytes, so the long value is found by bytes.
    final onUsername =
        problem != null &&
        (problem.isUsernameProblem ||
            (problem == ProxyCredentialsProblem.tooLong &&
                utf8.encode(username).length > 255));
    setState(() {
      _hostError = host.isEmpty
          ? l10n.settings_network_validation_hostRequired
          : null;
      _portError = port == null
          ? l10n.settings_network_validation_portInvalid
          : null;
      _usernameError = problem != null && onUsername
          ? credentialsMessage(l10n, problem)
          : null;
      _passwordError = problem != null && !onUsername
          ? credentialsMessage(l10n, problem)
          : null;
    });
    if (_hostError != null || _portError != null || problem != null) return;

    setState(() => _saving = true);
    final settings = widget.controller.state.settings.copyWith(
      type: _type,
      host: host,
      port: port,
      username: username,
    );
    final messenger = ScaffoldMessenger.maybeOf(context);
    try {
      await widget.controller.saveSettings(
        settings,
        password: username.isEmpty ? null : password,
        updatePassword: true,
      );
    } catch (e, st) {
      // A locked keychain or unwritable prefs: say so and keep the draft,
      // so Save can be retried.
      _log.error('Could not save the proxy settings', error: e, stackTrace: st);
      messenger?.showSnackBar(
        SnackBar(content: Text(l10n.settings_network_manual_saveFailed)),
      );
      return;
    } finally {
      if (mounted) setState(() => _saving = false);
    }
    if (!mounted) return;
    ref.read(networkProxyDraftProvider.notifier).clear();
    messenger?.showSnackBar(
      SnackBar(content: Text(l10n.settings_network_manual_saved)),
    );
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          SegmentedButton<ProxyType>(
            segments: [
              ButtonSegment(
                value: ProxyType.http,
                label: Text(l10n.settings_network_manual_typeHttp),
              ),
              ButtonSegment(
                value: ProxyType.socks5,
                label: Text(l10n.settings_network_manual_typeSocks),
              ),
            ],
            selected: {_type},
            onSelectionChanged: (selection) {
              setState(() => _type = selection.first);
              _recordDraft();
            },
          ),
          const SizedBox(height: 16),
          TextField(
            key: const ValueKey('proxy-host'),
            controller: _host,
            autocorrect: false,
            keyboardType: TextInputType.url,
            decoration: InputDecoration(
              labelText: l10n.settings_network_manual_host,
              errorText: _hostError,
            ),
            onChanged: (_) => _recordDraft(),
          ),
          const SizedBox(height: 12),
          TextField(
            key: const ValueKey('proxy-port'),
            controller: _port,
            keyboardType: TextInputType.number,
            inputFormatters: numberInputFormatters(),
            decoration: InputDecoration(
              labelText: l10n.settings_network_manual_port,
              hintText: _type == ProxyType.http ? '8080' : '1080',
              errorText: _portError,
            ),
            onChanged: (_) => _recordDraft(),
          ),
          const SizedBox(height: 12),
          TextField(
            key: const ValueKey('proxy-username'),
            controller: _username,
            autocorrect: false,
            decoration: InputDecoration(
              labelText: l10n.settings_network_manual_username,
              errorText: _usernameError,
            ),
            onChanged: (_) => _recordDraft(),
          ),
          const SizedBox(height: 12),
          TextField(
            key: const ValueKey('proxy-password'),
            controller: _password,
            obscureText: !_showPassword,
            autocorrect: false,
            enableSuggestions: false,
            decoration: InputDecoration(
              labelText: l10n.settings_network_manual_password,
              errorText: _passwordError,
              suffixIcon: IconButton(
                icon: Icon(
                  _showPassword ? Icons.visibility_off : Icons.visibility,
                ),
                tooltip: _showPassword
                    ? l10n.settings_network_manual_hidePassword
                    : l10n.settings_network_manual_showPassword,
                onPressed: () => setState(() => _showPassword = !_showPassword),
              ),
            ),
            onChanged: (_) => _recordDraft(),
          ),
          const SizedBox(height: 8),
          Text(
            l10n.settings_network_manual_nativeNote,
            style: theme.textTheme.bodySmall?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
          const SizedBox(height: 16),
          Align(
            alignment: AlignmentDirectional.centerEnd,
            child: FilledButton(
              onPressed: _saving ? null : _save,
              child: Text(l10n.settings_network_manual_save),
            ),
          ),
        ],
      ),
    );
  }
}

/// The host a user meant in [text], tolerating a pasted URL: a scheme, a
/// path and a `:port` are removed (the port is returned so an empty Port
/// field can take it). Empty when what is left cannot be a host name, so
/// `proxy corp` is refused rather than saved as a proxy that never connects,
/// and so is a list separator: `a;b` would break the proxy directive dart:io
/// parses for every request.
({String host, int? port}) parseProxyHostInput(String text) {
  var rest = text.trim();
  final scheme = rest.indexOf('://');
  if (scheme >= 0) rest = rest.substring(scheme + 3);
  final slash = rest.indexOf('/');
  if (slash >= 0) rest = rest.substring(0, slash);
  int? port;
  if (rest.startsWith('[')) {
    final close = rest.indexOf(']');
    if (close < 0) return (host: '', port: null);
    final after = rest.substring(close + 1);
    if (after.startsWith(':')) port = readProxyPort(after.substring(1));
    rest = rest.substring(1, close);
  } else if (':'.allMatches(rest).length == 1) {
    final colon = rest.indexOf(':');
    port = readProxyPort(rest.substring(colon + 1));
    rest = rest.substring(0, colon);
  }
  if (rest.isEmpty || RegExp(r'[\s@;,/\\?#\[\]]').hasMatch(rest)) {
    return (host: '', port: null);
  }
  return (host: rest, port: port);
}

/// The port in [text], or null when it is blank, unreadable, or outside
/// 1 to 65535.
int? readProxyPort(String text) => switch (readNumber(
  text,
  integer: true,
  allowNegative: false,
)) {
  NumberValue(:final value) when value >= 1 && value <= 65535 => value.toInt(),
  _ => null,
};

/// The field message for a credentials problem.
String credentialsMessage(
  AppLocalizations l10n,
  ProxyCredentialsProblem problem,
) => switch (problem) {
  ProxyCredentialsProblem.passwordRequired =>
    l10n.settings_network_validation_passwordRequired,
  ProxyCredentialsProblem.usernameHasColon =>
    l10n.settings_network_validation_usernameColon,
  ProxyCredentialsProblem.usernameHasSemicolon =>
    l10n.settings_network_validation_usernameSemicolon,
  ProxyCredentialsProblem.usernameHasEdgeWhitespace =>
    l10n.settings_network_validation_usernameWhitespace,
  ProxyCredentialsProblem.passwordHasSemicolon =>
    l10n.settings_network_validation_passwordSemicolon,
  ProxyCredentialsProblem.passwordHasEdgeWhitespace =>
    l10n.settings_network_validation_passwordWhitespace,
  ProxyCredentialsProblem.tooLong => l10n.settings_network_validation_tooLong,
};
