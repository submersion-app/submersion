import 'package:submersion/core/providers/provider.dart';

import 'package:submersion/features/certifications/domain/entities/certification.dart';
import 'package:submersion/features/certifications/presentation/providers/certification_providers.dart';
import 'package:submersion/features/dive_log/presentation/providers/dive_providers.dart';

const _milestoneLadder = [10, 25, 50, 100, 250, 500, 1000];

/// Next round-number dive milestone, or null when there are no dives.
int? nextDiveMilestone(int totalDives) {
  if (totalDives <= 0) return null;
  for (final threshold in _milestoneLadder) {
    if (totalDives < threshold) return threshold;
  }
  return ((totalDives ~/ 500) + 1) * 500;
}

/// An upcoming certification anniversary.
class CertAnniversary {
  final String certName;
  final int years;
  final DateTime date;

  const CertAnniversary({
    required this.certName,
    required this.years,
    required this.date,
  });
}

/// Certification anniversaries falling within [windowDays] of [today],
/// soonest first. Certifications without an issue date are ignored.
List<CertAnniversary> upcomingAnniversaries(
  List<Certification> certs,
  DateTime today, {
  int windowDays = 60,
}) {
  final result = <CertAnniversary>[];
  final todayDay = DateTime(today.year, today.month, today.day);
  for (final cert in certs) {
    final issued = cert.issueDate;
    if (issued == null) continue;
    var next = DateTime(todayDay.year, issued.month, issued.day);
    if (next.isBefore(todayDay)) {
      next = DateTime(todayDay.year + 1, issued.month, issued.day);
    }
    final years = next.year - issued.year;
    if (years <= 0) continue;
    if (next.difference(todayDay).inDays <= windowDays) {
      result.add(
        CertAnniversary(certName: cert.name, years: years, date: next),
      );
    }
  }
  result.sort((a, b) => a.date.compareTo(b.date));
  return result;
}

/// Milestone data for the dashboard card.
class DashboardMilestones {
  final int? nextMilestone;
  final int? divesRemaining;
  final List<CertAnniversary> anniversaries;

  const DashboardMilestones({
    required this.nextMilestone,
    required this.divesRemaining,
    required this.anniversaries,
  });

  bool get isEmpty => nextMilestone == null && anniversaries.isEmpty;
}

/// Next dive-count milestone and upcoming certification anniversaries.
final milestonesProvider = FutureProvider<DashboardMilestones>((ref) async {
  final stats = await ref.watch(diveStatisticsProvider.future);
  final certsAsync = ref.watch(certificationListNotifierProvider);
  final certs = certsAsync.valueOrNull ?? const <Certification>[];

  final next = nextDiveMilestone(stats.totalDives);
  return DashboardMilestones(
    nextMilestone: next,
    divesRemaining: next == null ? null : next - stats.totalDives,
    anniversaries: upcomingAnniversaries(certs, DateTime.now()),
  );
});
