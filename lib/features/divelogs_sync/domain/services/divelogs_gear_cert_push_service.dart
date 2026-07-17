import 'package:submersion/core/constants/enums.dart';
import 'package:submersion/core/services/divelogs/divelogs_api_client.dart';
import 'package:submersion/features/certifications/domain/entities/certification.dart';
import 'package:submersion/features/divelogs_sync/data/mappers/divelogs_export_mapper.dart';
import 'package:submersion/features/divelogs_sync/data/mappers/divelogs_reference_mappers.dart';
import 'package:submersion/features/equipment/domain/entities/equipment_item.dart';

class GearCertPushResult {
  final int gearPushed;
  final int certsPushed;
  final String? error;

  const GearCertPushResult({
    required this.gearPushed,
    required this.certsPushed,
    this.error,
  });

  bool get failed => error != null;
}

/// Create-only push of gear and certifications (spec Phase 3). Sequential;
/// a failure stops the run and reports partial counts — the next compare
/// converges on whatever was already created (stateless model).
class DivelogsGearCertPushService {
  DivelogsGearCertPushService({required DivelogsApiClient api}) : _api = api;

  final DivelogsApiClient _api;

  Future<GearCertPushResult> push({
    required List<EquipmentItem> gear,
    required List<Certification> certs,
    required Map<int, String> geartypes,
  }) async {
    var gearPushed = 0;
    var certsPushed = 0;
    try {
      for (final item in gear) {
        final geartypeId = DivelogsReferenceMappers.geartypeIdForEquipmentType(
          item.type,
          geartypes,
        );
        final purchaseDate = item.purchaseDate;
        final lastServiceDate = item.lastServiceDate;
        await _api.postGear({
          'name': item.name,
          ?'geartype': geartypeId,
          if (purchaseDate != null) 'purchasedate': divelogsDate(purchaseDate),
          if (lastServiceDate != null)
            'last_servicedate': divelogsDate(lastServiceDate),
        });
        gearPushed++;
      }
      for (final cert in certs) {
        final issueDate = cert.issueDate;
        if (issueDate == null) continue; // planner excludes these already
        await _api.postCertification(
          name: cert.name,
          date: divelogsDate(issueDate),
          org: cert.agency == CertificationAgency.other
              ? null
              : cert.agency.displayName,
        );
        certsPushed++;
      }
    } on DivelogsApiException catch (e) {
      return GearCertPushResult(
        gearPushed: gearPushed,
        certsPushed: certsPushed,
        error: e.message,
      );
    }
    return GearCertPushResult(gearPushed: gearPushed, certsPushed: certsPushed);
  }
}
