import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import 'package:submersion/core/providers/provider.dart';
import 'package:submersion/core/services/logger_service.dart';
import 'package:submersion/core/utils/unit_formatter.dart';
import 'package:submersion/features/cylinder_passports/domain/entities/passport_usage.dart';
import 'package:submersion/features/cylinder_passports/presentation/providers/cylinder_passport_providers.dart';
import 'package:submersion/features/settings/presentation/providers/settings_providers.dart';
import 'package:submersion/l10n/l10n_extension.dart';

/// How the card is headed: a cylinder not in the diver's gear leads with
/// "You have used this cylinder N times"; the diver's own cylinder gets a
/// Dives section like the passport's other cards.
enum PassportUsageTitle { foreign, own }

/// The active diver's dives with a tank from the cylinder whose passport id
/// is [passportId] (issue #2650): how many, the last date, and the dives
/// themselves, each opening its dive. Shows nothing until the cylinder has
/// been used, so a first scan looks as it always did.
class PassportUsageCard extends ConsumerStatefulWidget {
  const PassportUsageCard({
    super.key,
    required this.passportId,
    required this.title,
    this.topGap = 0,
  });

  final String passportId;
  final PassportUsageTitle title;

  /// Space above the card, only while it shows: the page leaves no gap
  /// where a hidden card would be.
  final double topGap;

  /// Rows shown before "Show all".
  static const collapsedRows = 5;

  @override
  ConsumerState<PassportUsageCard> createState() => _PassportUsageCardState();
}

class _PassportUsageCardState extends ConsumerState<PassportUsageCard> {
  static final _log = LoggerService.forClass(PassportUsageCard);

  bool _expanded = false;

  /// The failure last logged, so a rebuild does not log it again.
  Object? _loggedError;

  @override
  Widget build(BuildContext context) {
    final usage = ref.watch(passportUsageProvider(widget.passportId));
    return usage.when(
      // Hidden while loading, like at zero uses: the page does not jump
      // when a cylinder turns out never to have been used.
      loading: () => const SizedBox.shrink(),
      error: (e, stackTrace) {
        if (!identical(e, _loggedError)) {
          _loggedError = e;
          _log.error(
            'Failed to load the dives of a cylinder',
            error: e,
            stackTrace: stackTrace,
          );
        }
        return _frame(
          ListTile(
            contentPadding: EdgeInsets.zero,
            leading: const Icon(Icons.error_outline),
            title: Text(context.l10n.passport_usage_loadFailed),
          ),
        );
      },
      data: (dives) => dives.isEmpty ? const SizedBox.shrink() : _usage(dives),
    );
  }

  Widget _frame(Widget child) => Padding(
    padding: EdgeInsets.only(top: widget.topGap),
    child: Card(
      child: Padding(padding: const EdgeInsets.all(16), child: child),
    ),
  );

  Widget _usage(List<PassportUsageDive> dives) {
    final l10n = context.l10n;
    final theme = Theme.of(context);
    final units = UnitFormatter(ref.watch(settingsProvider));
    final count = dives.length;
    final shown = _expanded
        ? dives
        : dives.take(PassportUsageCard.collapsedRows).toList();
    final lastUsed = Text(
      l10n.passport_usage_lastUsed(units.formatDate(dives.first.dateTime)),
      style: theme.textTheme.bodySmall,
    );
    return _frame(
      Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          ...switch (widget.title) {
            PassportUsageTitle.foreign => [
              Text(
                l10n.passport_usage_foreignTitle(count),
                style: theme.textTheme.titleMedium,
              ),
              const SizedBox(height: 4),
              lastUsed,
            ],
            PassportUsageTitle.own => [
              Text(
                l10n.passport_usage_title,
                style: theme.textTheme.titleMedium,
              ),
              const SizedBox(height: 8),
              Text(l10n.passport_usage_ownTitle(count)),
              lastUsed,
            ],
          },
          const SizedBox(height: 4),
          for (final dive in shown)
            ListTile(
              key: ValueKey('passport_usage_row_${dive.diveId}'),
              contentPadding: EdgeInsets.zero,
              dense: true,
              title: Text(dive.siteName ?? l10n.passport_usage_noSite),
              subtitle: Text(
                [
                  units.formatDate(dive.dateTime),
                  if (dive.diveNumber case final n?)
                    l10n.passport_usage_diveNumber(n),
                ].join(' · '),
              ),
              trailing: const Icon(Icons.chevron_right),
              onTap: () => context.push('/dives/${dive.diveId}'),
            ),
          if (!_expanded && count > PassportUsageCard.collapsedRows)
            TextButton(
              onPressed: () => setState(() => _expanded = true),
              child: Text(l10n.passport_usage_showAll(count)),
            ),
        ],
      ),
    );
  }
}
