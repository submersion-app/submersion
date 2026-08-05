import 'package:submersion/core/constants/enums.dart';
import 'package:submersion/core/services/divelogs/divelogs_models.dart';
import 'package:submersion/features/certifications/domain/entities/certification.dart';
import 'package:submersion/features/equipment/domain/entities/equipment_item.dart';

/// Push/pull diff for gear and certifications (create-only, spec Phase 3).
/// Pull counts are informational — pulling happens in the import wizard.
class GearCertSyncPlan {
  final List<EquipmentItem> pushGear;
  final List<Certification> pushCerts;
  final int matchedGear;
  final int matchedCerts;
  final int pullGear;
  final int pullCerts;

  /// Local certs excluded from push because the API requires a date.
  final int certsMissingDate;

  const GearCertSyncPlan({
    required this.pushGear,
    required this.pushCerts,
    required this.matchedGear,
    required this.matchedCerts,
    required this.pullGear,
    required this.pullCerts,
    required this.certsMissingDate,
  });

  bool get hasPush => pushGear.isNotEmpty || pushCerts.isNotEmpty;
}

/// Name-keyed create-only matching: gear by normalized name; certifications
/// by normalized name plus calendar date when both sides carry one.
class GearCertSyncPlanner {
  const GearCertSyncPlanner();

  GearCertSyncPlan plan({
    required List<DivelogsGearItem> remoteGear,
    required List<DivelogsCertification> remoteCerts,
    required List<EquipmentItem> localGear,
    required List<Certification> localCerts,
  }) {
    String norm(String s) => s.trim().toLowerCase();

    // Gear: one-to-one consumption of remote names.
    final remoteGearNames = <String, int>{};
    for (final item in remoteGear) {
      remoteGearNames.update(norm(item.name), (c) => c + 1, ifAbsent: () => 1);
    }
    final unmatchedLocalGear = <EquipmentItem>[];
    var matchedGear = 0;
    for (final item in localGear) {
      final key = norm(item.name);
      final remaining = remoteGearNames[key] ?? 0;
      if (remaining > 0) {
        remoteGearNames[key] = remaining - 1;
        matchedGear++;
      } else {
        unmatchedLocalGear.add(item);
      }
    }
    final pullGear = remoteGearNames.values.fold(0, (sum, c) => sum + c);
    final pushGear = [
      for (final item in unmatchedLocalGear)
        if (item.isActive &&
            item.status != EquipmentStatus.retired &&
            item.status != EquipmentStatus.lost)
          item,
    ];

    // Certifications: key by name, refine by calendar date when both known.
    String certKey(String name, DateTime? date) => date == null
        ? norm(name)
        : '${norm(name)}|${date.year}-${date.month}-${date.day}';
    bool matches(DivelogsCertification remote, Certification local) {
      if (norm(remote.name) != norm(local.name)) return false;
      final rd = remote.date;
      final ld = local.issueDate;
      if (rd == null || ld == null) return true;
      return certKey(remote.name, rd) == certKey(local.name, ld);
    }

    final unmatchedRemoteCerts = [...remoteCerts];
    final pushCertCandidates = <Certification>[];
    var matchedCerts = 0;
    for (final local in localCerts) {
      final index = unmatchedRemoteCerts.indexWhere(
        (remote) => matches(remote, local),
      );
      if (index >= 0) {
        unmatchedRemoteCerts.removeAt(index);
        matchedCerts++;
      } else {
        pushCertCandidates.add(local);
      }
    }
    final certsMissingDate = pushCertCandidates
        .where((c) => c.issueDate == null)
        .length;
    final pushCerts = [
      for (final cert in pushCertCandidates)
        if (cert.issueDate != null) cert,
    ];

    return GearCertSyncPlan(
      pushGear: pushGear,
      pushCerts: pushCerts,
      matchedGear: matchedGear,
      matchedCerts: matchedCerts,
      pullGear: pullGear,
      pullCerts: unmatchedRemoteCerts.length,
      certsMissingDate: certsMissingDate,
    );
  }
}
