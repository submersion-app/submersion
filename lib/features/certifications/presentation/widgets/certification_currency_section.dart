import 'package:flutter/material.dart';

import 'package:submersion/core/constants/enums.dart';
import 'package:submersion/core/providers/provider.dart';
import 'package:submersion/core/theme/status_colors.dart';
import 'package:submersion/core/utils/unit_formatter.dart';
import 'package:submersion/features/certifications/domain/entities/certification.dart';
import 'package:submersion/features/certifications/domain/entities/credential_currency.dart';
import 'package:submersion/features/certifications/domain/entities/currency_event.dart';
import 'package:submersion/features/certifications/domain/entities/currency_pref.dart';
import 'package:submersion/features/certifications/domain/entities/currency_rule.dart';
import 'package:submersion/features/certifications/domain/services/certification_currency_engine.dart';
import 'package:submersion/features/certifications/presentation/currency_rule_display.dart';
import 'package:submersion/features/certifications/presentation/providers/certification_currency_providers.dart';
import 'package:submersion/features/certifications/presentation/utils/currency_severity_colors.dart';
import 'package:submersion/features/certifications/presentation/widgets/currency_event_dialog.dart';
import 'package:submersion/features/certifications/presentation/widgets/currency_interval_dialog.dart';
import 'package:submersion/features/certifications/presentation/widgets/currency_mapping_dialog.dart';
import 'package:submersion/features/settings/presentation/providers/settings_providers.dart';
import 'package:submersion/l10n/arb/app_localizations.dart';
import 'package:submersion/l10n/l10n_extension.dart';
import 'package:submersion/shared/widgets/tile_subtitle_action.dart';

/// What a currency row's menu can do.
enum CurrencyRowAction { log, interval, mapping, mute }

/// The Currency section of the certification detail page (issue #2267):
/// each rule that applies to this card with its severity, the date it counts
/// from in plain words and the advisory behind it, and the card's logged
/// refreshers and renewals. Absent when nothing applies and nothing is
/// logged, so an undated card gains no empty card.
///
/// A row stands for a collapsed group (OW, AOW and Rescue share one PADI
/// refresher row), so mute, interval and mapping changes write prefs for
/// every member, and the row means what it appears to mean.
class CertificationCurrencySection extends ConsumerWidget {
  final Certification certification;

  const CertificationCurrencySection({super.key, required this.certification});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final groups =
        ref
            .watch(certificationCurrencyGroupsProvider(certification.id))
            .value ??
        const <CurrencyGroup>[];
    final events =
        ref
            .watch(certificationCurrencyEventsProvider(certification.id))
            .value ??
        const <CurrencyEvent>[];
    if (groups.isEmpty && events.isEmpty) return const SizedBox.shrink();

    final l10n = context.l10n;
    final theme = Theme.of(context);
    final units = UnitFormatter(ref.watch(settingsProvider));
    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: Card(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                l10n.certifications_detail_sectionTitle_currency,
                style: theme.textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 4),
              for (final group in groups)
                _CurrencyRow(
                  certification: certification,
                  group: group,
                  units: units,
                ),
              if (events.isNotEmpty) ...[
                const Divider(),
                Text(
                  l10n.certifications_currency_history,
                  style: theme.textTheme.titleSmall,
                ),
                for (final event in events)
                  _EventTile(event: event, units: units),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

class _CurrencyRow extends ConsumerWidget {
  final Certification certification;
  final CurrencyGroup group;
  final UnitFormatter units;

  const _CurrencyRow({
    required this.certification,
    required this.group,
    required this.units,
  });

  CredentialCurrency get _status => group.members.firstWhere(
    (m) => m.certification.id == certification.id,
    orElse: () => group.representative,
  );

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = context.l10n;
    final theme = Theme.of(context);
    final s = _status;
    final small = theme.textTheme.bodySmall?.copyWith(
      color: theme.colorScheme.onSurfaceVariant,
    );
    final others = [
      for (final m in group.members)
        if (m.certification.id != certification.id) m.certification.name,
    ];
    final advisory = currencyRuleAdvisory(l10n, s.rule);
    final activity = s.rule.clockKind == CurrencyClockKind.activity;

    return ListTile(
      contentPadding: EdgeInsets.zero,
      leading: Icon(
        group.muted ? Icons.notifications_off_outlined : Icons.circle,
        size: group.muted ? 20 : 14,
        color: group.muted
            ? theme.colorScheme.outline
            : currencySeveritySwatch(
                    StatusColors.of(context),
                    group.severity,
                  )?.accent ??
                  theme.colorScheme.surfaceContainerHighest,
      ),
      title: Text(currencyRuleName(l10n, s.rule)),
      subtitle: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            group.muted
                ? l10n.certifications_currency_muted
                : _dueText(l10n, s),
          ),
          if (s.origin != CurrencyAnchorOrigin.noCountedDive)
            Text(_anchorText(l10n, s), style: small),
          if (advisory != null && advisory.isNotEmpty)
            Text(advisory, style: small),
          if (others.isNotEmpty)
            Text(
              l10n.certifications_currency_alsoCovers(others.join(', ')),
              style: small,
            ),
          if (group.muted)
            TileSubtitleAction(
              label: l10n.certifications_currency_action_unmute,
              onPressed: () => _setMuted(ref, false),
            ),
        ],
      ),
      trailing: PopupMenuButton<CurrencyRowAction>(
        onSelected: (action) => _onAction(context, ref, action),
        itemBuilder: (context) => [
          // A renewed card is a new expiry date on the card: the ledger
          // cannot move a printed date, so the card-expiry row logs nothing.
          if (s.rule.id != kCardExpiryRuleId)
            PopupMenuItem(
              value: CurrencyRowAction.log,
              child: Text(l10n.certifications_currency_action_log),
            ),
          PopupMenuItem(
            value: CurrencyRowAction.interval,
            child: Text(l10n.certifications_currency_action_interval),
          ),
          if (activity)
            PopupMenuItem(
              value: CurrencyRowAction.mapping,
              child: Text(l10n.certifications_currency_action_mapping),
            ),
          PopupMenuItem(
            value: CurrencyRowAction.mute,
            child: Text(
              group.muted
                  ? l10n.certifications_currency_action_unmute
                  : l10n.certifications_currency_action_mute,
            ),
          ),
        ],
      ),
    );
  }

  String _dueText(AppLocalizations l10n, CredentialCurrency s) {
    if (s.origin == CurrencyAnchorOrigin.noCountedDive) {
      return l10n.certifications_currency_noCountedDive;
    }
    final date = units.formatDate(s.dueDate);
    if (s.severity == CurrencySeverity.lapsed) {
      return l10n.certifications_currency_lapsedSince(date);
    }
    return '${s.severity.label(l10n)} · ${l10n.certifications_currency_dueOn(date)}';
  }

  String _anchorText(AppLocalizations l10n, CredentialCurrency s) {
    final date = units.formatDate(s.anchor);
    return switch (s.origin) {
      CurrencyAnchorOrigin.lastDive =>
        l10n.certifications_currency_anchor_lastDive(date),
      CurrencyAnchorOrigin.lastQualifyingDive =>
        l10n.certifications_currency_anchor_lastQualifyingDive(date),
      CurrencyAnchorOrigin.cardExpiry =>
        l10n.certifications_currency_anchor_cardExpiry(date),
      CurrencyAnchorOrigin.cardIssue =>
        l10n.certifications_currency_anchor_cardIssue(date),
      CurrencyAnchorOrigin.noCountedDive =>
        l10n.certifications_currency_noCountedDive,
      CurrencyAnchorOrigin.ledgerEvent =>
        l10n.certifications_currency_anchor_ledgerEvent(
          (s.anchorEventType ?? CurrencyEventType.other).label(l10n),
          date,
        ),
    };
  }

  Future<void> _onAction(
    BuildContext context,
    WidgetRef ref,
    CurrencyRowAction action,
  ) async {
    final s = _status;
    switch (action) {
      case CurrencyRowAction.log:
        final logged = await showCurrencyEventDialog(
          context,
          defaultType: s.rule.clockKind == CurrencyClockKind.activity
              ? CurrencyEventType.refresher
              : CurrencyEventType.renewal,
        );
        if (logged == null) return;
        final now = DateTime.now();
        await ref
            .read(certificationCurrencyRepositoryProvider)
            .createEvent(
              CurrencyEvent(
                id: '',
                certificationId: certification.id,
                ruleId: s.rule.id,
                eventType: logged.type,
                eventDate: logged.date,
                provider: logged.provider,
                notes: logged.notes,
                createdAt: now,
                updatedAt: now,
              ),
            );
      case CurrencyRowAction.interval:
        final pref = await _pref(ref, certification.id, s.rule.id);
        if (!context.mounted) return;
        final result = await showCurrencyIntervalDialog(
          context,
          rule: s.rule,
          lapseOverride: pref?.lapseDaysOverride,
          leadOverride: pref?.leadDaysOverride,
        );
        if (result == null) return;
        await _writePrefs(
          ref,
          (p) => _rebuild(p, lapse: result.lapse, lead: result.lead),
        );
      case CurrencyRowAction.mapping:
        final pref = await _pref(ref, certification.id, s.rule.id);
        if (!context.mounted) return;
        final result = await showCurrencyMappingDialog(
          context,
          rule: s.rule,
          types: pref?.countedDiveTypeIds,
          modes: pref?.countedDiveModes,
        );
        if (result == null) return;
        await _writePrefs(
          ref,
          (p) => _rebuild(p, types: result.types, modes: result.modes),
        );
      case CurrencyRowAction.mute:
        await _setMuted(ref, !group.muted);
    }
  }

  Future<void> _setMuted(WidgetRef ref, bool muted) =>
      _writePrefs(ref, (p) => _rebuild(p, muted: muted));

  static Future<CurrencyPref?> _pref(
    WidgetRef ref,
    String certificationId,
    String ruleId,
  ) async {
    final prefs = await ref
        .read(certificationCurrencyRepositoryProvider)
        .getPrefs(certificationId);
    return prefs.where((p) => p.ruleId == ruleId).firstOrNull;
  }

  /// Writes [change] of each member's pref (or a fresh one) by full value,
  /// so every card the row stands for changes together.
  Future<void> _writePrefs(
    WidgetRef ref,
    CurrencyPref Function(CurrencyPref existing) change,
  ) async {
    final repo = ref.read(certificationCurrencyRepositoryProvider);
    final now = DateTime.now();
    for (final m in group.members) {
      final existing =
          await _pref(ref, m.certification.id, m.rule.id) ??
          await _inheritedPref(ref, m) ??
          CurrencyPref(
            id: '',
            certificationId: m.certification.id,
            ruleId: m.rule.id,
            createdAt: now,
            updatedAt: now,
          );
      await repo.upsertPref(change(existing));
    }
  }

  /// The superseded built-in's pref for [m], carried onto the custom rule
  /// as a new row, so the first edit of a copied rule keeps the mute and
  /// overrides the engine was already applying through it.
  static Future<CurrencyPref?> _inheritedPref(
    WidgetRef ref,
    CredentialCurrency m,
  ) async {
    final supersedes = m.rule.supersedesRuleId;
    if (supersedes == null) return null;
    final inherited = await _pref(ref, m.certification.id, supersedes);
    if (inherited == null) return null;
    return _rebuild(
      CurrencyPref(
        id: '',
        certificationId: inherited.certificationId,
        ruleId: m.rule.id,
        muted: inherited.muted,
        createdAt: inherited.createdAt,
        updatedAt: inherited.updatedAt,
      ),
      lapse: inherited.lapseDaysOverride,
      lead: inherited.leadDaysOverride,
      types: inherited.countedDiveTypeIds,
      modes: inherited.countedDiveModes,
    );
  }
}

const _keep = Object();

/// [p] with the named fields replaced, each able to go back to null, which
/// copyWith cannot do. An omitted field keeps its value.
CurrencyPref _rebuild(
  CurrencyPref p, {
  Object? lapse = _keep,
  Object? lead = _keep,
  Object? types = _keep,
  Object? modes = _keep,
  bool? muted,
}) => CurrencyPref(
  id: p.id,
  certificationId: p.certificationId,
  ruleId: p.ruleId,
  lapseDaysOverride: identical(lapse, _keep)
      ? p.lapseDaysOverride
      : lapse as int?,
  leadDaysOverride: identical(lead, _keep) ? p.leadDaysOverride : lead as int?,
  countedDiveTypeIds: identical(types, _keep)
      ? p.countedDiveTypeIds
      : types as List<String>?,
  countedDiveModes: identical(modes, _keep)
      ? p.countedDiveModes
      : modes as List<DiveMode>?,
  muted: muted ?? p.muted,
  createdAt: p.createdAt,
  updatedAt: p.updatedAt,
);

class _EventTile extends ConsumerWidget {
  final CurrencyEvent event;
  final UnitFormatter units;

  const _EventTile({required this.event, required this.units});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = context.l10n;
    final theme = Theme.of(context);
    final details = [
      if (event.provider case final provider? when provider.isNotEmpty)
        provider,
      if (event.notes.isNotEmpty) event.notes,
    ];
    return ListTile(
      key: const ValueKey('currencyEventTile'),
      contentPadding: EdgeInsets.zero,
      leading: Icon(Icons.history_edu, color: theme.colorScheme.primary),
      title: Text(
        '${event.eventType.label(l10n)} · ${units.formatDate(event.eventDate)}',
      ),
      subtitle: details.isEmpty
          ? null
          : Text(
              details.join(' · '),
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
            ),
      trailing: IconButton(
        icon: const Icon(Icons.delete_outline),
        tooltip: l10n.common_action_delete,
        onPressed: () => _confirmDelete(context, ref),
      ),
    );
  }

  Future<void> _confirmDelete(BuildContext context, WidgetRef ref) async {
    final l10n = context.l10n;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(l10n.certifications_currency_deleteEvent_title),
        content: Text(
          l10n.certifications_currency_deleteEvent_content(
            event.eventType.label(l10n),
            units.formatDate(event.eventDate),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: Text(l10n.common_action_cancel),
          ),
          FilledButton(
            style: FilledButton.styleFrom(
              backgroundColor: Theme.of(context).colorScheme.error,
            ),
            onPressed: () => Navigator.of(context).pop(true),
            child: Text(l10n.common_action_delete),
          ),
        ],
      ),
    );
    if (confirmed ?? false) {
      await ref
          .read(certificationCurrencyRepositoryProvider)
          .deleteEvent(event.id);
    }
  }
}
