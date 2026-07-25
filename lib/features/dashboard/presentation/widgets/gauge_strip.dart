import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import 'package:submersion/core/providers/provider.dart';

import 'package:submersion/features/dashboard/presentation/providers/gauge_providers.dart';
import 'package:submersion/features/equipment/domain/entities/service_clock_status.dart';
import 'package:submersion/features/settings/presentation/providers/settings_providers.dart';
import 'package:submersion/l10n/l10n_extension.dart';

/// Dive-currency thresholds for the last-dive chip: quiet under 6 months,
/// amber past 6, red past 12 (typical agency refresher guidance).
const int kCurrencyWarnDays = 180;
const int kCurrencyAlertDays = 365;

/// Backup-age thresholds for the backup chip.
const int kBackupWarnDays = 7;
const int kBackupAlertDays = 30;

/// Always-on status chips: gear service clocks, insurance, no-fly, dive
/// currency, plus attention chips (certifications, trip, checklist,
/// course, uploads, backup, sync, data quality). Each chip type can be
/// hidden in Settings > Appearance > Home.
class GaugeStrip extends ConsumerWidget {
  const GaugeStrip({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final gaugesAsync = ref.watch(dashboardGaugesProvider);
    final hidden = ref.watch(settingsProvider.select((s) => s.hiddenHomeChips));
    return gaugesAsync.when(
      data: (g) => _buildStrip(context, g, hidden),
      loading: () => const SizedBox(height: 40),
      // Always-on block: contained error with a retry affordance instead
      // of vanishing.
      error: (_, _) => Align(
        alignment: Alignment.centerLeft,
        child: _chip(
          context,
          icon: Icons.refresh,
          label: context.l10n.dashboard_gauges_retry,
          tone: _Tone.neutral,
          onTap: () => ref.invalidate(dashboardGaugesProvider),
        ),
      ),
    );
  }

  bool _shown(Set<String> hidden, HomeChipType type) =>
      !hidden.contains(type.name);

  Widget _buildStrip(
    BuildContext context,
    DashboardGauges g,
    Set<String> hidden,
  ) {
    final l10n = context.l10n;
    final chips = <Widget>[];

    if (_shown(hidden, HomeChipType.gear)) {
      if (!g.hasGear) {
        chips.add(
          _chip(
            context,
            icon: Icons.add,
            label: l10n.dashboard_gauges_addGear,
            tone: _Tone.neutral,
            onTap: () => context.go('/gear'),
          ),
        );
      } else {
        for (final gauge in g.gearGauges) {
          final (label, tone) = switch (gauge.status.severity) {
            ServiceClockSeverity.overdue => (
              l10n.dashboard_gauges_gearOverdue(gauge.itemName),
              _Tone.alert,
            ),
            ServiceClockSeverity.dueSoon => (
              l10n.dashboard_gauges_gearDueIn(
                gauge.itemName,
                gauge.status.daysUntilDue ?? 0,
              ),
              _Tone.warn,
            ),
            ServiceClockSeverity.ok => (
              l10n.dashboard_gauges_gearOk(gauge.itemName),
              _Tone.ok,
            ),
          };
          chips.add(
            _chip(
              context,
              icon: Icons.build_outlined,
              label: label,
              tone: tone,
              onTap: () => context.go('/gear'),
            ),
          );
        }
      }
    }

    if (_shown(hidden, HomeChipType.insurance)) {
      final insurance = g.insurance;
      if (insurance == null || insurance.expiryDate == null) {
        chips.add(
          _chip(
            context,
            icon: Icons.health_and_safety_outlined,
            label: l10n.dashboard_gauges_noInsurance,
            tone: _Tone.neutral,
          ),
        );
      } else if (insurance.isExpired) {
        chips.add(
          _chip(
            context,
            icon: Icons.health_and_safety_outlined,
            label: l10n.dashboard_gauges_insuranceExpired,
            tone: _Tone.alert,
          ),
        );
      } else if (insurance.isExpiringSoon) {
        chips.add(
          _chip(
            context,
            icon: Icons.health_and_safety_outlined,
            label: l10n.dashboard_gauges_insuranceExpires(
              DateFormat.yMMMd(
                Localizations.localeOf(context).toString(),
              ).format(insurance.expiryDate!),
            ),
            tone: _Tone.warn,
          ),
        );
      } else {
        chips.add(
          _chip(
            context,
            icon: Icons.health_and_safety_outlined,
            label: l10n.dashboard_gauges_insuranceOk,
            tone: _Tone.ok,
          ),
        );
      }
    }

    if (_shown(hidden, HomeChipType.noFly)) {
      final noFly = g.noFlyStatus;
      final now = DateTime.now().toUtc();
      if (noFly != null && noFly.isActiveAt(now)) {
        final remaining = noFly.remaining(now);
        chips.add(
          _chip(
            context,
            icon: Icons.flight_outlined,
            label: l10n.dashboard_gauges_noFlyRemaining(
              remaining.inHours.toString(),
              (remaining.inMinutes % 60).toString().padLeft(2, '0'),
            ),
            tone: _Tone.warn,
          ),
        );
      } else {
        chips.add(
          _chip(
            context,
            icon: Icons.flight_outlined,
            label: l10n.dashboard_gauges_noFlyClear,
            tone: _Tone.ok,
          ),
        );
      }
    }

    if (_shown(hidden, HomeChipType.lastDive)) {
      final days = g.daysSinceLastDive;
      final tone = days == null
          ? _Tone.neutral
          : days >= kCurrencyAlertDays
          ? _Tone.alert
          : days >= kCurrencyWarnDays
          ? _Tone.warn
          : _Tone.neutral;
      chips.add(
        _chip(
          context,
          icon: Icons.scuba_diving,
          label: days == null
              ? l10n.dashboard_gauges_noDivesYet
              : days == 0
              ? l10n.dashboard_gauges_lastDiveToday
              : l10n.dashboard_gauges_lastDiveDays(days),
          tone: tone,
        ),
      );
    }

    if (_shown(hidden, HomeChipType.certifications) &&
        g.expiringCertCount > 0) {
      chips.add(
        _chip(
          context,
          icon: Icons.card_membership_outlined,
          label: l10n.dashboard_gauges_certsExpiring(g.expiringCertCount),
          tone: _Tone.warn,
          onTap: () => context.go('/certifications'),
        ),
      );
    }

    final trip = g.nextTrip;
    if (_shown(hidden, HomeChipType.trip) && trip != null) {
      chips.add(
        _chip(
          context,
          icon: Icons.flight_takeoff_outlined,
          label: l10n.dashboard_gauges_tripCountdown(
            trip.name,
            trip.daysUntilStart,
          ),
          tone: _Tone.ok,
          onTap: () => context.go('/trips'),
        ),
      );
    }

    final checklistId = g.activeChecklistId;
    if (_shown(hidden, HomeChipType.checklist) && checklistId != null) {
      chips.add(
        _chip(
          context,
          icon: Icons.checklist_outlined,
          label: l10n.dashboard_gauges_checklistActive,
          tone: _Tone.warn,
          onTap: () => context.push('/pre-dive-sessions/$checklistId'),
        ),
      );
    }

    final course = g.firstCourse;
    if (_shown(hidden, HomeChipType.course) && course != null) {
      chips.add(
        _chip(
          context,
          icon: Icons.school_outlined,
          label: l10n.dashboard_gauges_courseProgress(
            course.course.name,
            course.progress.satisfiedCount,
            course.progress.totalCount,
          ),
          tone: _Tone.neutral,
          onTap: () => context.go('/courses'),
        ),
      );
    }

    if (_shown(hidden, HomeChipType.uploads) && g.uploadsPending > 0) {
      chips.add(
        _chip(
          context,
          icon: Icons.cloud_upload_outlined,
          label: l10n.dashboard_gauges_uploadsPending(g.uploadsPending),
          tone: _Tone.warn,
        ),
      );
    }

    if (_shown(hidden, HomeChipType.backup)) {
      final lastBackup = g.lastBackupTime;
      if (lastBackup == null) {
        chips.add(
          _chip(
            context,
            icon: Icons.save_outlined,
            label: l10n.dashboard_gauges_backupNone,
            tone: _Tone.warn,
            onTap: () => context.push('/settings/backup'),
          ),
        );
      } else {
        final age = DateTime.now().difference(lastBackup).inDays;
        final tone = age >= kBackupAlertDays
            ? _Tone.alert
            : age >= kBackupWarnDays
            ? _Tone.warn
            : _Tone.ok;
        chips.add(
          _chip(
            context,
            icon: Icons.save_outlined,
            label: age == 0
                ? l10n.dashboard_gauges_backupToday
                : l10n.dashboard_gauges_backupDays(age),
            tone: tone,
            onTap: () => context.push('/settings/backup'),
          ),
        );
      }
    }

    if (_shown(hidden, HomeChipType.sync) && g.syncEnabled) {
      chips.add(
        _chip(
          context,
          icon: Icons.sync_outlined,
          label: g.syncPending > 0
              ? l10n.dashboard_gauges_syncPending(g.syncPending)
              : l10n.dashboard_gauges_synced,
          tone: g.syncPending > 0 ? _Tone.warn : _Tone.ok,
        ),
      );
    }

    if (_shown(hidden, HomeChipType.dataQuality) && g.dataQualityFindings > 0) {
      chips.add(
        _chip(
          context,
          icon: Icons.fact_check_outlined,
          label: l10n.dashboard_gauges_dataIssues(g.dataQualityFindings),
          tone: _Tone.warn,
          onTap: () => context.push('/settings/data-quality'),
        ),
      );
    }

    if (chips.isEmpty) return const SizedBox.shrink();
    return Wrap(spacing: 8, runSpacing: 8, children: chips);
  }

  Widget _chip(
    BuildContext context, {
    required IconData icon,
    required String label,
    required _Tone tone,
    VoidCallback? onTap,
  }) {
    final scheme = Theme.of(context).colorScheme;
    final (bg, fg) = switch (tone) {
      _Tone.alert => (scheme.errorContainer, scheme.onErrorContainer),
      _Tone.warn => (scheme.tertiaryContainer, scheme.onTertiaryContainer),
      _Tone.ok => (scheme.secondaryContainer, scheme.onSecondaryContainer),
      _Tone.neutral => (
        scheme.surfaceContainerHighest,
        scheme.onSurfaceVariant,
      ),
    };
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(999),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        decoration: BoxDecoration(
          color: bg,
          borderRadius: BorderRadius.circular(999),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 16, color: fg),
            const SizedBox(width: 6),
            Text(
              label,
              style: Theme.of(
                context,
              ).textTheme.labelMedium?.copyWith(color: fg),
            ),
          ],
        ),
      ),
    );
  }
}

enum _Tone { neutral, ok, warn, alert }
