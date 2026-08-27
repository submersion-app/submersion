import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:submersion/core/constants/enums.dart';
import 'package:submersion/core/services/divelogs/divelogs_api_client.dart';
import 'package:submersion/features/certifications/domain/entities/certification.dart';
import 'package:submersion/features/divelogs_sync/domain/services/divelogs_gear_cert_push_service.dart';
import 'package:submersion/features/equipment/domain/entities/equipment_item.dart';

/// Captures BaseRequests so multipart cert fields stay inspectable.
class _CapturingClient extends http.BaseClient {
  _CapturingClient(this.onRequest, {this.statusFor});

  final void Function(http.BaseRequest) onRequest;
  final int Function(http.BaseRequest)? statusFor;

  @override
  Future<http.StreamedResponse> send(http.BaseRequest request) async {
    onRequest(request);
    final status = statusFor?.call(request) ?? 200;
    return http.StreamedResponse(Stream.value('{}'.codeUnits), status);
  }
}

void main() {
  final now = DateTime.utc(2024);

  DivelogsApiClient api(
    void Function(http.BaseRequest) onRequest, {
    int Function(http.BaseRequest)? statusFor,
  }) => DivelogsApiClient(
    getBearerToken: () async => 't',
    onTokenRejected: () {},
    httpClient: _CapturingClient(onRequest, statusFor: statusFor),
  );

  test(
    'pushes gear with mapped geartype and formatted dates, then certs',
    () async {
      final requests = <http.BaseRequest>[];
      final service = DivelogsGearCertPushService(api: api(requests.add));
      final result = await service.push(
        gear: [
          EquipmentItem(
            id: 'g1',
            name: 'Zeagle Ranger',
            type: EquipmentType.bcd,
            purchaseDate: DateTime.utc(2020, 3, 5),
          ),
        ],
        certs: [
          Certification(
            id: 'c1',
            name: 'Open Water',
            agency: CertificationAgency.padi,
            issueDate: DateTime.utc(2022, 6, 15),
            createdAt: now,
            updatedAt: now,
          ),
        ],
        geartypes: const {1: 'Regulator', 2: 'Jacket'},
      );

      expect(result.gearPushed, 1);
      expect(result.certsPushed, 1);
      expect(result.failed, isFalse);

      final gearReq = requests[0] as http.Request;
      expect(gearReq.url.path, '/api/gear');
      expect(jsonDecode(gearReq.body), {
        'name': 'Zeagle Ranger',
        'geartype': 2,
        'purchasedate': '2020-03-05',
      });

      final certReq = requests[1] as http.MultipartRequest;
      expect(certReq.url.path, '/api/certifications');
      expect(certReq.fields, {
        'name': 'Open Water',
        'date': '2022-06-15',
        'org': 'PADI',
      });
    },
  );

  test('other-agency certs omit org; unmappable geartype omitted', () async {
    final requests = <http.BaseRequest>[];
    await DivelogsGearCertPushService(api: api(requests.add)).push(
      gear: [
        const EquipmentItem(id: 'g1', name: 'Cam', type: EquipmentType.camera),
      ],
      certs: [
        Certification(
          id: 'c1',
          name: 'Club Cert',
          agency: CertificationAgency.other,
          issueDate: DateTime.utc(2021, 2, 3),
          createdAt: now,
          updatedAt: now,
        ),
      ],
      geartypes: const {1: 'Regulator'},
    );

    final gearReq = requests[0] as http.Request;
    expect(jsonDecode(gearReq.body), {'name': 'Cam'});
    final certReq = requests[1] as http.MultipartRequest;
    expect(certReq.fields.containsKey('org'), isFalse);
  });

  test('a failure stops the run and reports partial counts', () async {
    var calls = 0;
    final service = DivelogsGearCertPushService(
      api: api((_) => calls++, statusFor: (req) => calls <= 1 ? 200 : 500),
    );
    final result = await service.push(
      gear: [
        const EquipmentItem(id: 'g1', name: 'A', type: EquipmentType.other),
        const EquipmentItem(id: 'g2', name: 'B', type: EquipmentType.other),
      ],
      certs: const [],
      geartypes: const {},
    );
    expect(result.gearPushed, 1);
    expect(result.failed, isTrue);
    expect(result.error, contains('500'));
  });
}
