import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:submersion/core/providers/account_providers.dart';
import 'package:submersion/core/services/accounts/account_kind.dart';
import 'package:submersion/core/services/accounts/account_provider_adapter.dart';
import 'package:submersion/core/services/accounts/adapters/divelogs_account_adapter.dart';
import 'package:submersion/core/services/accounts/connected_account.dart';
import 'package:submersion/core/services/divelogs/divelogs_api_client.dart';
import 'package:submersion/core/services/divelogs/divelogs_auth_manager.dart';
import 'package:submersion/features/certifications/presentation/providers/certification_providers.dart';
import 'package:submersion/features/dive_log/domain/entities/dive_summary.dart';
import 'package:submersion/features/dive_log/presentation/providers/dive_repository_provider.dart';
import 'package:submersion/features/divelogs_sync/domain/services/divelogs_gear_cert_push_service.dart';
import 'package:submersion/features/divelogs_sync/domain/services/divelogs_push_service.dart';
import 'package:submersion/features/divelogs_sync/domain/services/divelogs_sync_planner.dart';
import 'package:submersion/features/divelogs_sync/domain/services/gear_cert_sync_planner.dart';
import 'package:submersion/features/equipment/presentation/providers/equipment_providers.dart';
import 'package:submersion/features/divers/presentation/providers/diver_providers.dart';
import 'package:submersion/features/import_wizard/data/adapters/divelogs_adapter.dart';
import 'package:submersion/l10n/l10n_extension.dart';

enum _PagePhase {
  loading,
  notConnected,
  wrongDiver,
  idle,
  comparing,
  plan,
  pushing,
  error,
}

/// Compare-and-push page for a connected divelogs.de account (spec: sync
/// page). Pull review is delegated to the Phase 1 import wizard; push has
/// its own per-dive selection here.
class DivelogsSyncPage extends ConsumerStatefulWidget {
  const DivelogsSyncPage({super.key});

  @override
  ConsumerState<DivelogsSyncPage> createState() => _DivelogsSyncPageState();
}

class _DivelogsSyncPageState extends ConsumerState<DivelogsSyncPage> {
  _PagePhase _phase = _PagePhase.loading;
  ConnectedAccount? _account;
  DivelogsSyncPlan? _plan;
  Set<String> _selectedPushIds = {};
  String? _errorMessage;
  int _pushDone = 0;
  int _pushTotal = 0;
  DivelogsPushResult? _lastPushResult;
  GearCertSyncPlan? _gearCertPlan;
  Map<int, String> _geartypes = const {};
  Map<String, String> _remoteGearIdByName = const {};
  String? _gearCertError;
  GearCertPushResult? _lastGearCertResult;
  bool _pushingGearCerts = false;

  @override
  void initState() {
    super.initState();
    Future.microtask(_init);
  }

  Future<void> _init() async {
    final repo = ref.read(connectedAccountsRepositoryProvider);
    final account = await repo.getByKind(AccountKind.divelogs);
    if (!mounted) return;
    if (account == null) {
      setState(() => _phase = _PagePhase.notConnected);
      return;
    }
    final status = await _adapter.status(account);
    if (!mounted) return;
    if (status != AccountStatus.signedIn) {
      setState(() => _phase = _PagePhase.notConnected);
      return;
    }
    final currentDiver = await ref.read(currentDiverProvider.future);
    if (!mounted) return;
    if (account.diverId != null &&
        currentDiver != null &&
        account.diverId != currentDiver.id) {
      setState(() => _phase = _PagePhase.wrongDiver);
      return;
    }
    setState(() {
      _account = account;
      _phase = _PagePhase.idle;
    });
  }

  DivelogsAccountAdapter get _adapter =>
      ref.read(accountProviderRegistryProvider).adapterFor(AccountKind.divelogs)
          as DivelogsAccountAdapter;

  DivelogsApiClient _api(ConnectedAccount account) {
    final manager = _adapter.authManagerFor(account);
    return DivelogsApiClient(
      getBearerToken: manager.getToken,
      onTokenRejected: manager.invalidateToken,
      httpClient: ref.read(divelogsHttpClientProvider),
    );
  }

  Future<void> _compare() async {
    final account = _account;
    if (account == null) return;
    setState(() {
      _phase = _PagePhase.comparing;
      _errorMessage = null;
    });
    try {
      final api = _api(account);
      final remote = await api.getDivelist();
      final currentDiver = await ref.read(currentDiverProvider.future);
      final diverId = account.diverId ?? currentDiver?.id;
      final local = await ref
          .read(diveRepositoryProvider)
          .getDiveSummaries(diverId: diverId, limit: 1000000);
      if (!mounted) return;
      final plan = const DivelogsSyncPlanner().plan(
        remote: remote.entries,
        local: local,
      );
      // Gear/certs compare independently: a failure here renders an inline
      // error line in that section and never breaks the dive compare.
      GearCertSyncPlan? gearCertPlan;
      String? gearCertError;
      var geartypes = const <int, String>{};
      var remoteGearIdByName = const <String, String>{};
      try {
        final remoteGear = await api.getGear();
        final remoteCerts = await api.getCertifications();
        try {
          geartypes = await api.getGeartypes();
        } on DivelogsApiException {
          // Geartype names only refine push mapping; ignore.
        }
        final localGear = await ref
            .read(equipmentRepositoryProvider)
            .getAllEquipment(diverId: diverId);
        final localCerts = await ref
            .read(certificationRepositoryProvider)
            .getAllCertifications(diverId: diverId);
        gearCertPlan = const GearCertSyncPlanner().plan(
          remoteGear: remoteGear,
          remoteCerts: remoteCerts,
          localGear: localGear,
          localCerts: localCerts,
        );
        remoteGearIdByName = {
          for (final g in remoteGear) g.name.trim().toLowerCase(): g.id,
        };
      } on DivelogsApiException catch (e) {
        gearCertError = e.message;
      }
      if (!mounted) return;
      setState(() {
        _plan = plan;
        _selectedPushIds = plan.pushCandidates.map((s) => s.id).toSet();
        _gearCertPlan = gearCertPlan;
        _gearCertError = gearCertError;
        _geartypes = geartypes;
        _remoteGearIdByName = remoteGearIdByName;
        _phase = _PagePhase.plan;
      });
    } on DivelogsApiException catch (e) {
      if (!mounted) return;
      setState(() {
        _phase = _PagePhase.error;
        _errorMessage = e.message;
      });
    } on DivelogsAuthException catch (e) {
      if (!mounted) return;
      setState(() {
        _phase = _PagePhase.error;
        _errorMessage = e.message;
      });
    }
  }

  Future<void> _push() async {
    final account = _account;
    final plan = _plan;
    if (account == null || plan == null || _selectedPushIds.isEmpty) return;
    setState(() {
      _phase = _PagePhase.pushing;
      _pushDone = 0;
      _pushTotal = _selectedPushIds.length;
    });
    final dives = await ref
        .read(diveRepositoryProvider)
        .getDivesByIds(_selectedPushIds.toList());
    if (!mounted) return;
    final result = await DivelogsPushService(api: _api(account)).push(
      dives,
      remoteGearIdByName: _remoteGearIdByName,
      onProgress: (done, total) {
        if (!mounted) return;
        setState(() {
          _pushDone = done;
          _pushTotal = total;
        });
      },
    );
    if (!mounted) return;
    _lastPushResult = result;
    // Stateless model: re-compare so pushed dives show up as matched.
    await _compare();
  }

  Future<void> _pushGearCerts() async {
    final account = _account;
    final gearCertPlan = _gearCertPlan;
    if (account == null || gearCertPlan == null || !gearCertPlan.hasPush) {
      return;
    }
    setState(() => _pushingGearCerts = true);
    final result = await DivelogsGearCertPushService(api: _api(account)).push(
      gear: gearCertPlan.pushGear,
      certs: gearCertPlan.pushCerts,
      geartypes: _geartypes,
    );
    if (!mounted) return;
    _lastGearCertResult = result;
    _pushingGearCerts = false;
    await _compare();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    return Scaffold(
      appBar: AppBar(title: Text(l10n.divelogsSync_title)),
      body: switch (_phase) {
        _PagePhase.loading => const Center(child: CircularProgressIndicator()),
        _PagePhase.notConnected => _buildNotConnected(context),
        _PagePhase.wrongDiver => _buildMessage(
          context,
          l10n.divelogs_fetch_wrongDiver,
        ),
        _PagePhase.idle => Center(
          child: FilledButton(
            onPressed: _compare,
            child: Text(l10n.divelogsSync_compare),
          ),
        ),
        _PagePhase.comparing => _buildProgress(l10n.divelogsSync_comparing),
        _PagePhase.plan => _buildPlan(context),
        _PagePhase.pushing => _buildPushing(context),
        _PagePhase.error => _buildError(context),
      },
    );
  }

  Widget _buildNotConnected(BuildContext context) {
    final l10n = context.l10n;
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(l10n.divelogsSync_notConnected, textAlign: TextAlign.center),
            const SizedBox(height: 16),
            FilledButton(
              onPressed: () => context.push('/transfer/divelogs-import'),
              child: Text(l10n.divelogsSync_openImport),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildProgress(String message) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const CircularProgressIndicator(),
          const SizedBox(height: 16),
          Text(message),
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

  Widget _buildPushing(BuildContext context) {
    final l10n = context.l10n;
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            LinearProgressIndicator(
              value: _pushTotal == 0 ? null : _pushDone / _pushTotal,
            ),
            const SizedBox(height: 16),
            Text(l10n.divelogsSync_pushing),
          ],
        ),
      ),
    );
  }

  Widget _buildError(BuildContext context) {
    final l10n = context.l10n;
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              _errorMessage ?? l10n.divelogs_fetch_error,
              textAlign: TextAlign.center,
              style: TextStyle(color: Theme.of(context).colorScheme.error),
            ),
            const SizedBox(height: 16),
            FilledButton(
              onPressed: _compare,
              child: Text(l10n.divelogs_fetch_retry),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildPlan(BuildContext context) {
    final l10n = context.l10n;
    final plan = _plan!;
    final push = _lastPushResult;
    final dateFormat = MaterialLocalizations.of(context);
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        if (push != null) ...[
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    push.failed
                        ? l10n.divelogsSync_pushFailedPartial(
                            push.pushed,
                            push.error!,
                          )
                        : l10n.divelogsSync_pushDone(push.pushed),
                  ),
                  if (push.skippedUnmappable > 0)
                    Text(l10n.divelogsSync_pushSkipped(push.skippedUnmappable)),
                ],
              ),
            ),
          ),
          const SizedBox(height: 12),
        ],
        Row(
          children: [
            Expanded(child: Text(l10n.divelogsSync_matched(plan.matchedCount))),
            TextButton(
              onPressed: _compare,
              child: Text(l10n.divelogsSync_compare),
            ),
          ],
        ),
        const Divider(),
        if (plan.pullCandidates.isEmpty && plan.pushCandidates.isEmpty)
          Padding(
            padding: const EdgeInsets.all(24),
            child: Text(
              l10n.divelogsSync_nothingToSync,
              textAlign: TextAlign.center,
            ),
          ),
        if (plan.pullCandidates.isNotEmpty) ...[
          Text(
            l10n.divelogsSync_pullHeader(plan.pullCandidates.length),
            style: Theme.of(context).textTheme.titleMedium,
          ),
          const SizedBox(height: 8),
          FilledButton.tonal(
            onPressed: () => context.push('/transfer/divelogs-import'),
            child: Text(l10n.divelogsSync_pullReview),
          ),
          const SizedBox(height: 16),
        ],
        if (plan.pushCandidates.isNotEmpty) ...[
          Text(
            l10n.divelogsSync_pushHeader(plan.pushCandidates.length),
            style: Theme.of(context).textTheme.titleMedium,
          ),
          for (final summary in plan.pushCandidates)
            CheckboxListTile(
              value: _selectedPushIds.contains(summary.id),
              onChanged: (checked) => setState(() {
                if (checked == true) {
                  _selectedPushIds = {..._selectedPushIds, summary.id};
                } else {
                  _selectedPushIds = {..._selectedPushIds}..remove(summary.id);
                }
              }),
              title: Text(_summaryTitle(summary)),
              subtitle: Text(
                dateFormat.formatShortDate(
                  summary.entryTime ?? summary.dateTime,
                ),
              ),
            ),
          const SizedBox(height: 8),
          FilledButton(
            onPressed: _selectedPushIds.isEmpty ? null : _push,
            child: Text(l10n.divelogsSync_pushSelected),
          ),
        ],
        const SizedBox(height: 16),
        ..._buildGearCertSection(context),
      ],
    );
  }

  List<Widget> _buildGearCertSection(BuildContext context) {
    final l10n = context.l10n;
    final plan = _gearCertPlan;
    final error = _gearCertError;
    final pushResult = _lastGearCertResult;
    return [
      Text(
        l10n.divelogsSync_gearCertHeader,
        style: Theme.of(context).textTheme.titleMedium,
      ),
      const SizedBox(height: 8),
      if (error != null)
        Text(
          l10n.divelogsSync_gearCertUnavailable(error),
          style: TextStyle(color: Theme.of(context).colorScheme.error),
        )
      else if (plan != null) ...[
        if (pushResult != null)
          Padding(
            padding: const EdgeInsets.only(bottom: 8),
            child: Text(
              pushResult.failed
                  ? l10n.divelogsSync_gearCertPushFailed(pushResult.error!)
                  : l10n.divelogsSync_gearCertPushDone(
                      pushResult.gearPushed,
                      pushResult.certsPushed,
                    ),
            ),
          ),
        Text(
          l10n.divelogsSync_gearCertMatched(
            plan.matchedGear,
            plan.matchedCerts,
          ),
        ),
        if (plan.certsMissingDate > 0)
          Text(
            l10n.divelogsSync_certsMissingDate(plan.certsMissingDate),
            style: Theme.of(context).textTheme.bodySmall,
          ),
        if (plan.hasPush) ...[
          const SizedBox(height: 8),
          Text(
            l10n.divelogsSync_gearCertPush(
              plan.pushGear.length,
              plan.pushCerts.length,
            ),
          ),
          const SizedBox(height: 8),
          FilledButton.tonal(
            onPressed: _pushingGearCerts ? null : _pushGearCerts,
            child: Text(l10n.divelogsSync_gearCertPushButton),
          ),
        ],
      ],
    ];
  }

  String _summaryTitle(DiveSummary summary) {
    final name = summary.name;
    if (name != null && name.isNotEmpty) return name;
    final number = summary.diveNumber;
    if (number != null) return '#$number';
    return summary.siteName ?? summary.id;
  }
}
