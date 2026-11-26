import 'package:flutter/foundation.dart' show listEquals;
import 'package:flutter/material.dart';

import 'package:submersion/core/providers/provider.dart';
import 'package:submersion/core/theme/status_colors.dart';
import 'package:submersion/core/utils/unit_formatter.dart';
import 'package:submersion/features/certification_agencies/presentation/providers/certification_catalog_providers.dart';
import 'package:submersion/features/certifications/domain/entities/certification.dart';
import 'package:submersion/features/certifications/domain/entities/credential_currency.dart';
import 'package:submersion/features/certifications/domain/entities/currency_event.dart';
import 'package:submersion/features/certifications/domain/entities/currency_pref.dart';
import 'package:submersion/features/certifications/domain/entities/currency_rule.dart';
import 'package:submersion/features/certifications/domain/services/certification_currency_engine.dart';
import 'package:submersion/features/certifications/presentation/certification_title_l10n.dart';
import 'package:submersion/features/certifications/presentation/currency_rule_display.dart';
import 'package:submersion/features/certifications/presentation/editing/certification_currency_sitting.dart';
import 'package:submersion/features/certifications/presentation/providers/certification_currency_providers.dart';
import 'package:submersion/features/certifications/presentation/utils/currency_severity_colors.dart';
import 'package:submersion/features/certifications/presentation/widgets/currency_event_dialog.dart';
import 'package:submersion/features/certifications/presentation/widgets/currency_interval_dialog.dart';
import 'package:submersion/features/certifications/presentation/widgets/currency_mapping_dialog.dart';
import 'package:submersion/l10n/arb/app_localizations.dart';
import 'package:submersion/l10n/l10n_extension.dart';
import 'package:submersion/shared/widgets/record_editing/edit_session.dart';
import 'package:submersion/shared/widgets/record_editing/record_card_header.dart';
import 'package:submersion/shared/widgets/record_editing/record_card_pencil.dart';
import 'package:submersion/shared/widgets/record_editing/sitting_load_failed.dart';
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
///
/// It offers nothing outside the open Currency card (issue #4527, phase 3);
/// in the page's sitting ([editing]) what it logs, deletes and sets is held
/// until Save.
class CertificationCurrencySection extends ConsumerWidget {
  final Certification certification;

  /// The sitting its changes are held in: it is the Currency card's
  /// editor, drawn inside the open card.
  final EditSession<Certification>? editing;

  /// The sitting whose events and preferences a closed card shows.
  final EditSession<Certification>? shown;

  const CertificationCurrencySection({
    super.key,
    required this.certification,
    this.editing,
    this.shown,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final sitting = editing ?? shown;
    if (sitting == null) return _build(context, ref);
    // What the sitting holds is drawn as it changes.
    return ListenableBuilder(
      listenable: sitting,
      builder: (context, _) => _build(context, ref),
    );
  }

  Widget _build(BuildContext context, WidgetRef ref) {
    final groups =
        ref
            .watch(certificationCurrencyGroupsProvider(certification.id))
            .value ??
        const <CurrencyGroup>[];
    final storedEvents =
        ref
            .watch(certificationCurrencyEventsProvider(certification.id))
            .value ??
        const <CurrencyEvent>[];
    final editing = this.editing;
    final sitting = editing ?? shown;
    final events = sitting == null
        ? storedEvents
        : newestEventsFirst(
            certificationEventsList.current(sitting) ?? storedEvents,
          );
    if (groups.isEmpty && events.isEmpty) return const SizedBox.shrink();

    final l10n = context.l10n;
    final theme = Theme.of(context);
    final units = ref.watch(unitFormatterProvider);
    // Before the sitting's read answers, or when it failed, the events are
    // those stored, and none of them is a change.
    final loadedIds = sitting == null
        ? null
        : {
            for (final e
                in certificationEventsList.loaded(sitting) ?? storedEvents)
              e.id,
          };
    final title = l10n.certifications_detail_sectionTitle_currency;
    // The rules that apply follow the credential as stored: while the
    // sitting changes the agency or level, the rows are those of the old
    // one, so they take no action until the credential is saved.
    final credentialHeld =
        editing != null &&
        !listEquals(editing.working.credentials, editing.stored.credentials);
    final rowsReadOnly = editing == null || credentialHeld;
    final rows = <Widget>[
      if (credentialHeld)
        Padding(
          padding: const EdgeInsets.only(bottom: 8),
          child: Text(
            l10n.recordEdit_saveOrCancelFirst,
            key: const ValueKey('currency-credential-held'),
            style: theme.textTheme.bodySmall,
          ),
        ),
      for (final group in groups)
        _CurrencyRow(
          certification: certification,
          group: group,
          units: units,
          editing: editing,
          sitting: sitting,
          readOnly: rowsReadOnly,
        ),
      if (events.isNotEmpty) ...[
        const Divider(),
        Text(
          l10n.certifications_currency_history,
          style: theme.textTheme.titleSmall,
        ),
        for (final event in events)
          _EventTile(
            event: event,
            units: units,
            editing: editing,
            readOnly: rowsReadOnly,
            held: loadedIds != null && !loadedIds.contains(event.id),
          ),
      ],
    ];
    // The open card draws its own frame and title. A read of the events
    // that failed says so; an action reads them again.
    if (editing != null) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (certificationEventsList.failed(editing))
            SittingLoadFailed(
              onRetry: () => certificationEventsList.load(editing),
            ),
          ...rows,
        ],
      );
    }
    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: Card(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Expanded(
                    child: Text(
                      title,
                      style: theme.textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                  RecordCardPencil(cardTitle: title),
                ],
              ),
              const SizedBox(height: 4),
              ...rows,
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
  final EditSession<Certification>? editing;

  /// The sitting the row shows, open or closed.
  final EditSession<Certification>? sitting;
  final bool readOnly;

  const _CurrencyRow({
    required this.certification,
    required this.group,
    required this.units,
    this.editing,
    this.sitting,
    this.readOnly = false,
  });

  /// The preferences the sitting holds for this row's cards.
  List<CurrencyPref> _held() {
    final sitting = this.sitting;
    if (sitting == null) return const [];
    final held = currencyPrefsInSitting(sitting);
    return [
      for (final m in group.members)
        ?held[(certificationId: m.certification.id, ruleId: m.rule.id)],
    ];
  }

  /// Whether the row is muted, as the sitting holds it.
  bool get _muted {
    final held = _held();
    return held.isEmpty ? group.muted : held.first.muted;
  }

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
    final catalog = ref.watch(certificationCatalogSyncProvider);
    final others = [
      for (final m in group.members)
        if (m.certification.id != certification.id)
          certificationTitleL10n(m.certification, l10n, catalog: catalog),
    ];
    final advisory = currencyRuleAdvisory(l10n, s.rule);
    final activity = s.rule.clockKind == CurrencyClockKind.activity;
    final muted = _muted;
    final changed = _held().isNotEmpty;

    return ListTile(
      contentPadding: EdgeInsets.zero,
      leading: Icon(
        muted ? Icons.notifications_off_outlined : Icons.circle,
        size: muted ? 20 : 14,
        color: muted
            ? theme.colorScheme.outline
            : currencySeveritySwatch(
                    StatusColors.of(context),
                    group.severity,
                  )?.accent ??
                  theme.colorScheme.surfaceContainerHighest,
      ),
      title: Row(
        children: [
          Flexible(child: Text(currencyRuleName(l10n, s.rule))),
          if (changed) ...[const SizedBox(width: 6), const RecordChangedDot()],
        ],
      ),
      subtitle: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(muted ? l10n.certifications_currency_muted : _dueText(l10n, s)),
          if (s.origin != CurrencyAnchorOrigin.noCountedDive)
            Text(_anchorText(l10n, s), style: small),
          if (advisory != null && advisory.isNotEmpty)
            Text(advisory, style: small),
          if (others.isNotEmpty)
            Text(
              l10n.certifications_currency_alsoCovers(others.join(', ')),
              style: small,
            ),
          if (muted && !readOnly)
            TileSubtitleAction(
              label: l10n.certifications_currency_action_unmute,
              onPressed: () => _setMuted(ref, false),
            ),
        ],
      ),
      trailing: readOnly
          ? null
          : PopupMenuButton<CurrencyRowAction>(
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
                    muted
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
        final editing = this.editing;
        if (logged == null || editing == null) return;
        final current = await _heldEvents(editing);
        if (current == null || editing.isDisposed) return;
        certificationEventsList.set(editing, [
          ...current,
          newCurrencyEvent(
            certificationId: certification.id,
            ruleId: s.rule.id,
            type: logged.type,
            date: logged.date,
            provider: logged.provider,
            notes: logged.notes,
          ),
        ]);
      case CurrencyRowAction.interval:
        final pref = await _currentPref(ref, s.rule.id);
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
          (p) => rebuildCurrencyPref(p, lapse: result.lapse, lead: result.lead),
        );
      case CurrencyRowAction.mapping:
        final pref = await _currentPref(ref, s.rule.id);
        if (!context.mounted) return;
        // A mapping this build cannot read starts from the rule's, which is
        // what the engine applies in its place (issue #4942).
        final own = pref == null || pref.unreadableMapping ? null : pref;
        final result = await showCurrencyMappingDialog(
          context,
          rule: s.rule,
          types: own?.countedDiveTypeIds,
          modes: own?.countedDiveModes,
        );
        if (result == null) return;
        await _writePrefs(
          ref,
          (p) =>
              rebuildCurrencyPref(p, types: result.types, modes: result.modes),
        );
      case CurrencyRowAction.mute:
        await _setMuted(ref, !_muted);
    }
  }

  Future<void> _setMuted(WidgetRef ref, bool muted) =>
      _writePrefs(ref, (p) => rebuildCurrencyPref(p, muted: muted));

  /// This card's preference for [ruleId], as the sitting holds it.
  Future<CurrencyPref?> _currentPref(WidgetRef ref, String ruleId) async {
    final editing = this.editing;
    if (editing != null) {
      final held = currencyPrefsInSitting(
        editing,
      )[(certificationId: certification.id, ruleId: ruleId)];
      if (held != null) return held;
    }
    return _pref(ref, certification.id, ruleId);
  }

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

  /// Holds [change] of each member's pref (or a fresh one) until Save, by
  /// full value, so every card the row stands for changes together.
  Future<void> _writePrefs(
    WidgetRef ref,
    CurrencyPref Function(CurrencyPref existing) change,
  ) async {
    final editing = this.editing;
    if (editing == null) return;
    final repo = ref.read(certificationCurrencyRepositoryProvider);
    final stored = await storedCurrencyPrefs(group, repository: repo);
    if (editing.isDisposed) return;
    holdCurrencyPrefs(editing, group, stored, change);
  }
}

class _EventTile extends StatelessWidget {
  final CurrencyEvent event;
  final UnitFormatter units;
  final EditSession<Certification>? editing;
  final bool readOnly;

  /// Logged in the sitting, not yet saved.
  final bool held;

  const _EventTile({
    required this.event,
    required this.units,
    this.editing,
    this.readOnly = false,
    this.held = false,
  });

  @override
  Widget build(BuildContext context) {
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
      title: Row(
        children: [
          Flexible(
            child: Text(
              '${event.eventType.label(l10n)} · '
              '${units.formatDate(event.eventDate)}',
            ),
          ),
          if (held) ...[const SizedBox(width: 6), const RecordChangedDot()],
        ],
      ),
      subtitle: details.isEmpty
          ? null
          : Text(
              details.join(' · '),
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
            ),
      trailing: readOnly
          ? null
          : IconButton(
              icon: const Icon(Icons.delete_outline),
              tooltip: l10n.common_action_delete,
              onPressed: _delete,
            ),
    );
  }

  /// Takes the event out of the sitting's held list, asking nothing:
  /// Cancel brings it back.
  Future<void> _delete() async {
    final editing = this.editing;
    if (editing == null) return;
    final current = await _heldEvents(editing);
    if (current == null || editing.isDisposed) return;
    certificationEventsList.set(editing, [
      for (final e in current)
        if (e.id != event.id) e,
    ]);
  }
}

/// The events [session] holds, read first when they have not been: an
/// action taken before the read answered, or after it failed, waits for it.
/// Null when they cannot be read.
Future<List<CurrencyEvent>?> _heldEvents(
  EditSession<Certification> session,
) async {
  final current = certificationEventsList.current(session);
  if (current != null) return current;
  await certificationEventsList.load(session);
  return certificationEventsList.current(session);
}
