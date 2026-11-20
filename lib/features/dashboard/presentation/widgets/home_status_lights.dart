import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:submersion/core/providers/provider.dart';
import 'package:submersion/core/utils/elapsed_duration_format.dart';
import 'package:submersion/core/utils/unit_formatter.dart';
import 'package:submersion/features/certifications/presentation/certification_attention_navigation.dart';
import 'package:submersion/features/dashboard/presentation/providers/gauge_providers.dart';
import 'package:submersion/features/demo_mode/presentation/providers/demo_mode_providers.dart';
import 'package:submersion/features/documents/domain/document_expiry.dart';
import 'package:submersion/features/documents/domain/entities/document.dart';
import 'package:submersion/features/documents/presentation/document_l10n.dart';
import 'package:submersion/features/equipment/domain/models/equipment_filter_state.dart';
import 'package:submersion/features/equipment/presentation/equipment_service_navigation.dart';
import 'package:submersion/features/safety/domain/services/no_fly_service.dart';
import 'package:submersion/features/settings/presentation/providers/sync_providers.dart';
import 'package:submersion/features/settings/presentation/widgets/sync_now_action.dart';
import 'package:submersion/l10n/l10n_extension.dart';

/// Dive-currency thresholds for the last-dive light: quiet under 6 months,
/// amber past 6, red past 12 (typical agency refresher guidance).
const int kCurrencyWarnDays = 180;
const int kCurrencyAlertDays = 365;

/// Backup-age thresholds for the backup light.
const int kBackupWarnDays = 7;
const int kBackupAlertDays = 30;

/// Shared by the no-fly and flight-window lights: both explain themselves on
/// the same flight-safety page.
const String _noFlyRoute = '/planning/no-fly';

enum HomeLightTone { neutral, ok, warn, alert }

/// One status light in the Home header: what the old gauge-strip chip said,
/// as data, so the header can lay lights out differently by width.
@immutable
class HomeStatusLight {
  /// The chip type this light speaks for; null for the strip's own pills
  /// (the retry and the all-clear count), which are not chips.
  final HomeChipType? type;
  final HomeLightTone tone;
  final String label;
  final IconData icon;

  /// Rendered through the diver's hide because it is a dive-safety fact:
  /// overdue gear, an expired policy, a shut flight window, or a hardened
  /// certification or medical-clearance lapse.
  final bool safety;

  /// Required: a light with no action looks identical to a live one, so an
  /// un-wired light would be invisible to the diver and the compiler alike.
  final VoidCallback onTap;
  final VoidCallback? onLongPress;

  const HomeStatusLight({
    this.type,
    required this.tone,
    required this.label,
    required this.icon,
    required this.onTap,
    this.safety = false,
    this.onLongPress,
  });
}

/// Alerts first, then warnings, then everything else, each group in the
/// order the lights were built.
List<HomeStatusLight> orderLightsBySeverity(List<HomeStatusLight> lights) {
  int rank(HomeLightTone t) => switch (t) {
    HomeLightTone.alert => 0,
    HomeLightTone.warn => 1,
    _ => 2,
  };
  final indexed = [for (var i = 0; i < lights.length; i++) (i, lights[i])]
    ..sort((a, b) {
      final byTone = rank(a.$2.tone) - rank(b.$2.tone);
      return byTone != 0 ? byTone : a.$1 - b.$1;
    });
  return [for (final e in indexed) e.$2];
}

/// What the phone strip names (every amber or red light) and how many quiet
/// lights it folds into one "all clear" count.
({List<HomeStatusLight> attention, int clear}) splitForPhone(
  List<HomeStatusLight> lights,
) {
  final attention = [
    for (final l in lights)
      if (l.tone == HomeLightTone.alert || l.tone == HomeLightTone.warn) l,
  ];
  return (attention: attention, clear: lights.length - attention.length);
}

/// The lights for [g], in the strip's declaration order. Each light type can
/// be hidden in Settings ([hidden] holds HomeChipType names), except the
/// safety lights, which render through the hide.
List<HomeStatusLight> buildHomeStatusLights(
  BuildContext context,
  WidgetRef ref,
  DashboardGauges g,
  Set<String> hidden,
) {
  final l10n = context.l10n;
  final units = ref.watch(unitFormatterProvider);
  final lights = <HomeStatusLight>[];
  bool shown(HomeChipType type) => !hidden.contains(type.name);

  // The one light that speaks for a severity bucket. A bucket of one names
  // its item and opens that item (issue #816); more than one counts the
  // items and opens the equipment list narrowed to the same severity.
  HomeStatusLight gearLight(GearSeverityGroup group, ServiceDueFilter sev) {
    final worst = group.worst;
    final overdue = sev == ServiceDueFilter.overdue;
    final days = worst.status.daysUntilDue ?? 0;
    final String label;
    if (group.count == 1) {
      label = overdue
          ? l10n.dashboard_gauges_gearOverdue(worst.itemName)
          : l10n.dashboard_gauges_gearDueIn(worst.itemName, days);
    } else {
      label = overdue
          ? l10n.dashboard_gauges_gearOverdueCount(group.count)
          : l10n.dashboard_gauges_gearDueSoonCount(group.count, days);
    }
    return HomeStatusLight(
      type: HomeChipType.gear,
      icon: Icons.build_outlined,
      label: label,
      tone: overdue ? HomeLightTone.alert : HomeLightTone.warn,
      safety: overdue,
      onTap: group.count == 1
          ? () => context.push('/equipment/${worst.itemId}')
          : () => openEquipmentWithServiceDue(context, ref, sev),
    );
  }

  // Gear, insurance and the flight window are hardened: an alert from any of
  // the three is a dive-safety fact, so it renders even when the diver has
  // hidden that light. What they say when they are not red stays hideable.
  final gearShown = shown(HomeChipType.gear);
  if (!g.hasGear) {
    if (gearShown) {
      lights.add(
        HomeStatusLight(
          type: HomeChipType.gear,
          icon: Icons.add,
          label: l10n.dashboard_gauges_addGear,
          tone: HomeLightTone.neutral,
          onTap: () => context.push('/equipment/new'),
        ),
      );
    }
  } else {
    // At most one light per severity, however much gear is behind it.
    final overdue = g.gearOverdue;
    if (overdue != null) {
      lights.add(gearLight(overdue, ServiceDueFilter.overdue));
    }
    final dueSoon = g.gearDueSoon;
    if (gearShown && dueSoon != null) {
      lights.add(gearLight(dueSoon, ServiceDueFilter.dueSoon));
    }
  }

  // Emptiness keys off the provider, not the expiry date: expiry is optional
  // on an insurance document, so a policy recorded without a renewal date is
  // complete and falls through to the OK branch.
  final insurance = g.insurance;
  final policy = insurance != null && insurance.providerLabel != null
      ? insurance
      : null;
  void insuranceLight(
    String label,
    HomeLightTone tone, {
    bool safety = false,
  }) => lights.add(
    HomeStatusLight(
      type: HomeChipType.insurance,
      icon: Icons.health_and_safety_outlined,
      label: label,
      tone: tone,
      safety: safety,
      onTap: () => context.push('/documents?type=insurance'),
    ),
  );
  if (policy != null && policy.isExpired) {
    insuranceLight(
      l10n.dashboard_gauges_insuranceExpired,
      HomeLightTone.alert,
      safety: true,
    );
  } else if (shown(HomeChipType.insurance)) {
    if (policy == null) {
      insuranceLight(l10n.dashboard_gauges_noInsurance, HomeLightTone.neutral);
    } else if (policy.isExpiringSoon) {
      insuranceLight(
        l10n.dashboard_gauges_insuranceExpires(
          units.formatDate(policy.expiryDate),
        ),
        HomeLightTone.warn,
      );
    } else {
      insuranceLight(l10n.dashboard_gauges_insuranceOk, HomeLightTone.ok);
    }
  }

  final now = DateTime.now().toUtc();
  if (shown(HomeChipType.noFly)) {
    final noFly = g.noFlyStatus;
    final active = noFly != null && noFly.isActiveAt(now);
    final remaining = active ? noFly.remaining(now) : Duration.zero;
    lights.add(
      HomeStatusLight(
        type: HomeChipType.noFly,
        icon: Icons.flight_outlined,
        label: active
            ? l10n.dashboard_gauges_noFlyRemaining(
                remaining.inHours.toString(),
                (remaining.inMinutes % 60).toString().padLeft(2, '0'),
              )
            : l10n.dashboard_gauges_noFlyClear,
        tone: active ? HomeLightTone.warn : HomeLightTone.ok,
        onTap: () => context.push(_noFlyRoute),
      ),
    );
  }

  final flight = g.flightWindow;
  if (flight != null) {
    switch (flight.state) {
      case FlightWindowState.open:
        if (shown(HomeChipType.flightWindow)) {
          final remaining = flight.remaining(now);
          lights.add(
            HomeStatusLight(
              type: HomeChipType.flightWindow,
              icon: Icons.flight_takeoff_outlined,
              label: l10n.dashboard_gauges_flightWindow(
                remaining.inHours.toString(),
                (remaining.inMinutes % 60).toString().padLeft(2, '0'),
              ),
              tone: HomeLightTone.warn,
              onTap: () => context.push(_noFlyRoute),
            ),
          );
        }
      case FlightWindowState.closed:
      case FlightWindowState.conflict:
        // Hardened: a shut flight window means the diver should not be
        // diving before their flight, so it is not theirs to hide.
        lights.add(
          HomeStatusLight(
            type: HomeChipType.flightWindow,
            icon: Icons.flight_takeoff_outlined,
            label: l10n.dashboard_gauges_flightWindowClosed,
            tone: HomeLightTone.alert,
            safety: true,
            onTap: () => context.push(_noFlyRoute),
          ),
        );
    }
  }

  if (shown(HomeChipType.lastDive)) {
    final days = g.daysSinceLastDive;
    final tone = days == null
        ? HomeLightTone.neutral
        : days >= kCurrencyAlertDays
        ? HomeLightTone.alert
        : days >= kCurrencyWarnDays
        ? HomeLightTone.warn
        : HomeLightTone.neutral;
    // From a year on the bare day count stops being readable.
    final longGap = days == null ? null : formatElapsedDays(l10n, days);
    lights.add(
      HomeStatusLight(
        type: HomeChipType.lastDive,
        icon: Icons.scuba_diving,
        label: days == null
            ? l10n.dashboard_gauges_noDivesYet
            : days == 0
            ? l10n.dashboard_gauges_lastDiveToday
            : longGap != null
            ? l10n.dashboard_gauges_lastDiveSpan(longGap)
            : l10n.dashboard_gauges_lastDiveDays(days),
        tone: tone,
        onTap: () => context.push('/dives'),
      ),
    );
  }

  // Certification currency (issue #2267). A lapse on a date the diver
  // entered renders through the hide; an inferred lapse stays hideable.
  // Through a hide the light names only the hardened certifications.
  final cert = g.certCurrency;
  final certShown = shown(HomeChipType.certifications);
  final certCount = certShown ? cert.count : cert.hardenedCount;
  if (certCount > 0) {
    lights.add(
      HomeStatusLight(
        type: HomeChipType.certifications,
        icon: Icons.card_membership_outlined,
        label: l10n.dashboard_gauges_certsNeedAttention(certCount),
        tone: cert.anyLapsed || !certShown
            ? HomeLightTone.alert
            : HomeLightTone.warn,
        safety: !certShown,
        onTap: () => openCertificationsNeedingAttention(context, ref),
      ),
    );
  }

  // Documents (issue #2613). An expired medical clearance is hardened like
  // insurance; everything else follows the hide.
  final docsShown = shown(HomeChipType.documents);
  final docs = [
    for (final e in g.attentionDocuments)
      if (docsShown ||
          (e.$1.type == DocumentType.medicalClearance &&
              e.$2.kind == DocumentExpiryKind.expired))
        e,
  ];
  if (docs.isNotEmpty) {
    final anyExpired = docs.any((e) => e.$2.kind == DocumentExpiryKind.expired);
    final single = docs.length == 1 ? docs.single : null;
    final label = switch (single) {
      null => l10n.dashboard_gauges_documentsNeedAttention(docs.length),
      (final doc, DocumentExpiryStatus(kind: DocumentExpiryKind.expired)) =>
        l10n.dashboard_gauges_documentExpired(documentDisplayTitle(l10n, doc)),
      (final doc, _) => l10n.dashboard_gauges_documentExpires(
        documentDisplayTitle(l10n, doc),
        units.formatDate(doc.expiryDate),
      ),
    };
    lights.add(
      HomeStatusLight(
        type: HomeChipType.documents,
        icon: Icons.folder_copy_outlined,
        label: label,
        tone: anyExpired || !docsShown
            ? HomeLightTone.alert
            : HomeLightTone.warn,
        safety: !docsShown,
        onTap: () => context.push(
          single == null
              ? '/documents?filter=expiring'
              : '/documents/${single.$1.id}',
        ),
      ),
    );
  }

  final trip = g.nextTrip;
  if (shown(HomeChipType.trip) && trip != null) {
    lights.add(
      HomeStatusLight(
        type: HomeChipType.trip,
        icon: Icons.flight_takeoff_outlined,
        label: l10n.dashboard_gauges_tripCountdown(
          trip.name,
          trip.daysUntilStart,
        ),
        tone: HomeLightTone.ok,
        // The light names one trip, so it opens that trip (#3350).
        onTap: () => context.push('/trips/${trip.id}'),
      ),
    );
  }

  final checklistId = g.activeChecklistId;
  if (shown(HomeChipType.checklist) && checklistId != null) {
    lights.add(
      HomeStatusLight(
        type: HomeChipType.checklist,
        icon: Icons.checklist_outlined,
        label: l10n.dashboard_gauges_checklistActive,
        tone: HomeLightTone.warn,
        onTap: () => context.push('/pre-dive-sessions/$checklistId'),
      ),
    );
  }

  final course = g.firstCourse;
  if (shown(HomeChipType.course) && course != null) {
    lights.add(
      HomeStatusLight(
        type: HomeChipType.course,
        icon: Icons.school_outlined,
        label: l10n.dashboard_gauges_courseProgress(
          course.course.name,
          course.progress.satisfiedCount,
          course.progress.totalCount,
        ),
        tone: HomeLightTone.neutral,
        onTap: () => context.push('/courses/${course.course.id}'),
      ),
    );
  }

  if (shown(HomeChipType.uploads) && g.uploadsPending > 0) {
    lights.add(
      HomeStatusLight(
        type: HomeChipType.uploads,
        icon: Icons.cloud_upload_outlined,
        label: l10n.dashboard_gauges_uploadsPending(g.uploadsPending),
        tone: HomeLightTone.warn,
        onTap: () => context.push('/settings/photos-media/uploads'),
      ),
    );
  }

  // Backups are sealed in demo mode (#3708), so the light would only point
  // at a page that cannot be used.
  if (shown(HomeChipType.backup) && !ref.watch(demoModeActiveProvider)) {
    final lastBackup = g.lastBackupTime;
    final age = lastBackup == null
        ? null
        : DateTime.now().difference(lastBackup).inDays;
    lights.add(
      HomeStatusLight(
        type: HomeChipType.backup,
        icon: Icons.save_outlined,
        label: age == null
            ? l10n.dashboard_gauges_backupNone
            : age == 0
            ? l10n.dashboard_gauges_backupToday
            : l10n.dashboard_gauges_backupDays(age),
        tone: age == null
            ? HomeLightTone.warn
            : age >= kBackupAlertDays
            ? HomeLightTone.alert
            : age >= kBackupWarnDays
            ? HomeLightTone.warn
            : HomeLightTone.ok,
        onTap: () => context.push('/settings/backup'),
      ),
    );
  }

  if (shown(HomeChipType.sync) && g.syncEnabled) {
    final syncing = ref.watch(isSyncingProvider);
    lights.add(
      HomeStatusLight(
        type: HomeChipType.sync,
        icon: Icons.sync_outlined,
        label: syncing
            ? l10n.settings_cloudSync_status_syncing
            : g.syncPending > 0
            ? l10n.dashboard_gauges_syncPending(g.syncPending)
            : l10n.dashboard_gauges_synced,
        tone: syncing
            ? HomeLightTone.neutral
            : g.syncPending > 0
            ? HomeLightTone.warn
            : HomeLightTone.ok,
        // Tap syncs (runSyncNow keeps the first-contact and replaced-library
        // confirmations). Mid-sync it opens the Cloud Sync page instead of
        // queuing a redundant run, which keeps the action real.
        onTap: syncing
            ? () => context.push('/settings/cloud-sync')
            : () => runSyncNow(context, ref),
        onLongPress: () => context.push('/settings/cloud-sync'),
      ),
    );
  }

  // A paired nearby device that cannot sync (issue #3731).
  final nearby = g.nearbyAttention;
  if (shown(HomeChipType.nearby) && nearby != null) {
    lights.add(
      HomeStatusLight(
        type: HomeChipType.nearby,
        icon: Icons.bluetooth_outlined,
        label: nearby.more == 0
            ? l10n.dashboard_gauges_nearby(nearby.name)
            : l10n.dashboard_gauges_nearbyMore(nearby.name),
        tone: HomeLightTone.warn,
        onTap: () => context.push('/settings/cloud-sync'),
      ),
    );
  }

  if (shown(HomeChipType.dataQuality) && g.dataQualityFindings > 0) {
    lights.add(
      HomeStatusLight(
        type: HomeChipType.dataQuality,
        icon: Icons.fact_check_outlined,
        label: l10n.dashboard_gauges_dataIssues(g.dataQualityFindings),
        tone: HomeLightTone.warn,
        onTap: () => context.push('/dives/quality'),
      ),
    );
  }

  return lights;
}
