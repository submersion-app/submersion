import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/core/database/database.dart';
import 'package:submersion/features/signatures/data/services/signature_storage_service.dart';

import '../../../../helpers/test_database.dart';

/// A signature on a dive shared by two courses belongs to both (#2515).
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late AppDatabase db;

  setUp(() async {
    db = await setUpTestDatabase();
    Future<void> sql(String s) => db.customStatement(s);
    await sql(
      "INSERT INTO divers (id, name, created_at, updated_at) "
      "VALUES ('me', 'Me', 0, 0)",
    );
    await sql(
      'INSERT INTO courses (id, diver_id, name, agency, start_date, '
      "created_at, updated_at) VALUES ('an', 'me', 'AN', 'tdi', 0, 0, 0), "
      "('dp', 'me', 'DP', 'tdi', 0, 0, 0)",
    );
    await sql(
      'INSERT INTO dives (id, diver_id, dive_date_time, course_id, '
      "created_at, updated_at) VALUES ('v1', 'me', 0, 'an', 0, 0)",
    );
    await sql(
      'INSERT INTO dive_courses (id, dive_id, course_id, created_at) VALUES '
      "('l1', 'v1', 'an', 0), ('l2', 'v1', 'dp', 0)",
    );
  });
  tearDown(tearDownTestDatabase);

  test(
    'getSignaturesForCourse finds a shared dive under each course',
    () async {
      final service = SignatureStorageService();
      await service.saveSignature(
        diveId: 'v1',
        imageBytes: Uint8List.fromList(const [1, 2, 3]),
        signerName: 'Alex Reyes',
      );
      expect(await service.getSignaturesForCourse('an'), hasLength(1));
      expect(await service.getSignaturesForCourse('dp'), hasLength(1));
    },
  );
}
