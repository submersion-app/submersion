import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:submersion/core/providers/account_providers.dart';
import 'package:submersion/core/services/accounts/account_kind.dart';
import 'package:submersion/core/services/accounts/account_provider_adapter.dart';
import 'package:submersion/core/services/accounts/adapters/divelogs_account_adapter.dart';
import 'package:submersion/core/services/accounts/connected_account.dart';
import 'package:submersion/core/services/divelogs/divelogs_api_client.dart';
import 'package:submersion/core/services/divelogs/divelogs_auth_manager.dart';
import 'package:submersion/core/services/divelogs/divelogs_credentials.dart';
import 'package:submersion/features/divers/presentation/providers/diver_providers.dart';
import 'package:submersion/features/import_wizard/data/adapters/divelogs_adapter.dart';
import 'package:submersion/features/universal_import/data/services/divelogs_import_service.dart';
import 'package:submersion/features/universal_import/presentation/providers/universal_import_providers.dart';
import 'package:submersion/l10n/l10n_extension.dart';

enum _StepPhase { loading, signIn, fetching, wrongDiver, error, done }

/// Acquisition step for the divelogs.de import source: signs the user in
/// (creating the connected account on first use) and fetches the full
/// logbook into the universal import notifier.
class DivelogsFetchStep extends ConsumerStatefulWidget {
  const DivelogsFetchStep({super.key});

  @override
  ConsumerState<DivelogsFetchStep> createState() => _DivelogsFetchStepState();
}

class _DivelogsFetchStepState extends ConsumerState<DivelogsFetchStep> {
  final _usernameController = TextEditingController();
  final _passwordController = TextEditingController();

  _StepPhase _phase = _StepPhase.loading;
  String? _errorMessage;
  String? _selectedDiverId;
  ConnectedAccount? _account;
  bool _connecting = false;

  @override
  void initState() {
    super.initState();
    Future.microtask(_init);
  }

  @override
  void dispose() {
    _usernameController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  Future<void> _init() async {
    final repo = ref.read(connectedAccountsRepositoryProvider);
    final account = await repo.getByKind(AccountKind.divelogs);
    if (!mounted) return;
    if (account == null) {
      final current = await ref.read(currentDiverProvider.future);
      if (!mounted) return;
      setState(() {
        _selectedDiverId = current?.id;
        _phase = _StepPhase.signIn;
      });
      return;
    }
    _account = account;
    final adapter = _adapter;
    final status = await adapter.status(account);
    if (!mounted) return;
    if (status != AccountStatus.signedIn) {
      _usernameController.text = account.accountIdentifier ?? '';
      setState(() {
        _selectedDiverId = account.diverId;
        _phase = _StepPhase.signIn;
      });
      return;
    }
    await _fetch(account);
  }

  DivelogsAccountAdapter get _adapter =>
      ref.read(accountProviderRegistryProvider).adapterFor(AccountKind.divelogs)
          as DivelogsAccountAdapter;

  Future<void> _connect() async {
    final username = _usernameController.text.trim();
    final password = _passwordController.text;
    if (username.isEmpty || password.isEmpty) return;
    setState(() {
      _connecting = true;
      _errorMessage = null;
    });
    try {
      final token = await DivelogsAuthManager.login(
        username: username,
        password: password,
        httpClient: ref.read(divelogsHttpClientProvider),
      );
      final repo = ref.read(connectedAccountsRepositoryProvider);
      final account =
          _account ??
          await repo.create(
            kind: AccountKind.divelogs,
            label: 'divelogs.de',
            accountIdentifier: username,
            diverId: _selectedDiverId,
          );
      await ref
          .read(accountCredentialsStoreProvider)
          .write(
            account.id,
            DivelogsCredentials(
              username: username,
              password: password,
              bearerToken: token,
            ).toJsonString(),
          );
      if (!mounted) return;
      _account = account;
      await _fetch(account);
    } on DivelogsAuthException catch (e) {
      if (!mounted) return;
      setState(() {
        _connecting = false;
        _errorMessage = e.message;
      });
    } finally {
      if (mounted && _connecting) {
        setState(() => _connecting = false);
      }
    }
  }

  Future<void> _fetch(ConnectedAccount account) async {
    final currentDiver = await ref.read(currentDiverProvider.future);
    if (!mounted) return;
    if (account.diverId != null &&
        currentDiver != null &&
        account.diverId != currentDiver.id) {
      setState(() => _phase = _StepPhase.wrongDiver);
      return;
    }
    setState(() => _phase = _StepPhase.fetching);
    try {
      final manager = _adapter.authManagerFor(account);
      final api = DivelogsApiClient(
        getBearerToken: manager.getToken,
        onTokenRejected: manager.invalidateToken,
        httpClient: ref.read(divelogsHttpClientProvider),
      );
      final payload = await DivelogsImportService(api: api).fetchAllDives();
      if (!mounted) return;
      await ref
          .read(universalImportNotifierProvider.notifier)
          .setExternalPayload(payload);
      if (!mounted) return;
      setState(() => _phase = _StepPhase.done);
    } on DivelogsApiException catch (e) {
      if (!mounted) return;
      setState(() {
        _phase = _StepPhase.error;
        _errorMessage = e.message;
      });
    } on DivelogsAuthException catch (e) {
      if (!mounted) return;
      setState(() {
        _phase = _StepPhase.error;
        _errorMessage = e.message;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return switch (_phase) {
      _StepPhase.loading => const Center(child: CircularProgressIndicator()),
      _StepPhase.signIn => _buildSignInForm(context),
      _StepPhase.fetching => _buildProgress(context),
      _StepPhase.done => _buildMessage(
        context,
        context.l10n.divelogs_fetch_done,
      ),
      _StepPhase.wrongDiver => _buildMessage(
        context,
        context.l10n.divelogs_fetch_wrongDiver,
      ),
      _StepPhase.error => _buildError(context),
    };
  }

  Widget _buildSignInForm(BuildContext context) {
    final divers = ref.watch(allDiversProvider);
    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            context.l10n.divelogs_signIn_title,
            style: Theme.of(context).textTheme.titleLarge,
          ),
          const SizedBox(height: 16),
          TextField(
            controller: _usernameController,
            decoration: InputDecoration(
              labelText: context.l10n.divelogs_signIn_username,
            ),
            autocorrect: false,
            enabled: !_connecting,
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _passwordController,
            decoration: InputDecoration(
              labelText: context.l10n.divelogs_signIn_password,
            ),
            obscureText: true,
            enabled: !_connecting,
            onSubmitted: (_) => _connect(),
          ),
          const SizedBox(height: 12),
          divers.when(
            data: (list) => DropdownButtonFormField<String>(
              initialValue: _selectedDiverId,
              decoration: InputDecoration(
                labelText: context.l10n.divelogs_signIn_diver,
              ),
              items: [
                for (final diver in list)
                  DropdownMenuItem(value: diver.id, child: Text(diver.name)),
              ],
              onChanged: _connecting || _account != null
                  ? null
                  : (value) => setState(() => _selectedDiverId = value),
            ),
            loading: () => const SizedBox.shrink(),
            error: (_, _) => const SizedBox.shrink(),
          ),
          if (_errorMessage != null) ...[
            const SizedBox(height: 12),
            Text(
              _errorMessage!,
              style: TextStyle(color: Theme.of(context).colorScheme.error),
            ),
          ],
          const SizedBox(height: 20),
          FilledButton(
            onPressed: _connecting ? null : _connect,
            child: _connecting
                ? const SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : Text(context.l10n.divelogs_signIn_connect),
          ),
        ],
      ),
    );
  }

  Widget _buildProgress(BuildContext context) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const CircularProgressIndicator(),
          const SizedBox(height: 16),
          Text(context.l10n.divelogs_fetch_inProgress),
        ],
      ),
    );
  }

  Widget _buildMessage(BuildContext context, String message) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Text(message, textAlign: TextAlign.center),
      ),
    );
  }

  Widget _buildError(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              _errorMessage ?? context.l10n.divelogs_fetch_error,
              textAlign: TextAlign.center,
              style: TextStyle(color: Theme.of(context).colorScheme.error),
            ),
            const SizedBox(height: 16),
            FilledButton(
              onPressed: () {
                final account = _account;
                if (account != null) {
                  _fetch(account);
                } else {
                  setState(() => _phase = _StepPhase.signIn);
                }
              },
              child: Text(context.l10n.divelogs_fetch_retry),
            ),
          ],
        ),
      ),
    );
  }
}
