import 'package:flutter_test/flutter_test.dart' hide isNull;
import 'package:drift/drift.dart';
import 'package:submersion/core/database/database.dart';
import 'package:submersion/features/buddies/data/repositories/buddy_conversion_repository.dart';
import 'package:submersion/features/buddies/data/repositories/buddy_repository.dart';
import 'package:submersion/features/buddies/domain/entities/buddy.dart'
    as domain;
import 'package:submersion/features/dive_roles/domain/entities/dive_role.dart';

import '../../../../helpers/test_database.dart';

void main() {
  late AppDatabase db;
  late BuddyConversionRepository conversionRepository;
  late BuddyRepository buddyRepository;

  setUp(() async {
    db = await setUpTestDatabase();
    conversionRepository = BuddyConversionRepository();
    buddyRepository = BuddyRepository();
  });

  tearDown(() async {
    await tearDownTestDatabase();
  });

  group('BuddyConversionRepository', () {
    test(
      'convertBuddyToDiveCenter should successfully convert a buddy',
      () async {
        // 1. Create a buddy
        final buddy = await buddyRepository.createBuddy(
          domain.Buddy(
            id: 'buddy-1',
            name: 'Dive Shop Buddy',
            email: 'shop@example.com',
            phone: '123456789',
            notes: 'Important notes',
            createdAt: DateTime.now(),
            updatedAt: DateTime.now(),
          ),
        );

        // 2. Create some dives
        final now = DateTime.now().millisecondsSinceEpoch;

        // Dive 1: Linked to buddy, diveCenterId is null
        await db
            .into(db.dives)
            .insert(
              DivesCompanion.insert(
                id: 'dive-1',
                diveDateTime: now,
                updatedAt: now,
                createdAt: now,
              ),
            );
        await db
            .into(db.diveBuddies)
            .insert(
              DiveBuddiesCompanion.insert(
                id: 'link-1',
                diveId: 'dive-1',
                buddyId: buddy.id,
                role: const Value(DiveRole.buddyId),
                createdAt: now,
              ),
            );

        // Dive 2: Linked to buddy, diveCenterId is ALREADY set
        const existingDiveCenterId = 'existing-center-id';
        await db
            .into(db.diveCenters)
            .insert(
              DiveCentersCompanion.insert(
                id: existingDiveCenterId,
                name: 'Existing Center',
                createdAt: now,
                updatedAt: now,
              ),
            );
        await db
            .into(db.dives)
            .insert(
              DivesCompanion.insert(
                id: 'dive-2',
                diveDateTime: now,
                diveCenterId: const Value(existingDiveCenterId),
                updatedAt: now,
                createdAt: now,
              ),
            );
        await db
            .into(db.diveBuddies)
            .insert(
              DiveBuddiesCompanion.insert(
                id: 'link-2',
                diveId: 'dive-2',
                buddyId: buddy.id,
                role: const Value(DiveRole.buddyId),
                createdAt: now,
              ),
            );

        // Dive 3: NOT linked to buddy
        await db
            .into(db.dives)
            .insert(
              DivesCompanion.insert(
                id: 'dive-3',
                diveDateTime: now,
                updatedAt: now,
                createdAt: now,
              ),
            );

        // 3. Perform conversion
        final diveCenterId = await conversionRepository
            .convertBuddyToDiveCenter(buddy);

        // 4. Verifications

        // Verify Dive Center created
        final diveCenter = await (db.select(
          db.diveCenters,
        )..where((t) => t.id.equals(diveCenterId))).getSingle();
        expect(diveCenter.name, equals(buddy.name));
        expect(diveCenter.email, equals(buddy.email));
        expect(diveCenter.phone, equals(buddy.phone));
        expect(diveCenter.notes, equals(buddy.notes));

        // Verify Dive 1 updated (diveCenterId set)
        final dive1 = await (db.select(
          db.dives,
        )..where((t) => t.id.equals('dive-1'))).getSingle();
        expect(dive1.diveCenterId, equals(diveCenterId));

        // Verify Dive 2 NOT updated (kept existing diveCenterId)
        final dive2 = await (db.select(
          db.dives,
        )..where((t) => t.id.equals('dive-2'))).getSingle();
        expect(dive2.diveCenterId, equals(existingDiveCenterId));

        // Verify Dive 3 NOT updated
        final dive3 = await (db.select(
          db.dives,
        )..where((t) => t.id.equals('dive-3'))).getSingle();
        expect(dive3.diveCenterId, null);

        // Verify Buddy links removed from junction table
        final links = await (db.select(
          db.diveBuddies,
        )..where((t) => t.buddyId.equals(buddy.id))).get();
        expect(links, isEmpty);

        // Verify Buddy deleted
        final buddies = await (db.select(
          db.buddies,
        )..where((t) => t.id.equals(buddy.id))).get();
        expect(buddies, isEmpty);
      },
    );

    test(
      'convertBuddyToDiveCenter (covers _handleConvertToDiveCenter UI action) '
      'should successfully convert a buddy with all related data and tombstones',
      () async {
        // 0. Create a diver to satisfy FK constraint
        const diverId = 'diver-1';
        await db
            .into(db.divers)
            .insert(
              DiversCompanion.insert(
                id: diverId,
                name: 'Test Diver',
                createdAt: DateTime.now().millisecondsSinceEpoch,
                updatedAt: DateTime.now().millisecondsSinceEpoch,
              ),
            );

        // 1. Create a buddy with diverId
        final buddy = await buddyRepository.createBuddy(
          domain.Buddy(
            id: 'buddy-conv-1',
            diverId: diverId,
            name: 'Conversion Shop',
            email: 'conv@example.com',
            phone: '987654321',
            notes: 'Conversion notes',
            createdAt: DateTime.now(),
            updatedAt: DateTime.now(),
          ),
        );

        // 2. Add some related data: certs and roles
        final now = DateTime.now().millisecondsSinceEpoch;
        await db
            .into(db.certifications)
            .insert(
              CertificationsCompanion.insert(
                id: 'cert-1',
                name: 'OWD',
                agency: 'PADI',
                buddyId: const Value('buddy-conv-1'),
                createdAt: now,
                updatedAt: now,
              ),
            );
        await db
            .into(db.buddyRoles)
            .insert(
              BuddyRoleRow(
                id: 'role-1',
                buddyId: 'buddy-conv-1',
                role: 'instructor',
                createdAt: now,
                updatedAt: now,
                notes: '',
              ),
            );

        // 3. Create a dive linked to buddy
        await db
            .into(db.dives)
            .insert(
              DivesCompanion.insert(
                id: 'dive-conv-1',
                diveDateTime: now,
                updatedAt: now,
                createdAt: now,
              ),
            );
        await db
            .into(db.diveBuddies)
            .insert(
              DiveBuddiesCompanion.insert(
                id: 'link-conv-1',
                diveId: 'dive-conv-1',
                buddyId: buddy.id,
                role: const Value(DiveRole.buddyId),
                createdAt: now,
              ),
            );

        // 4. Perform conversion
        final diveCenterId = await conversionRepository
            .convertBuddyToDiveCenter(buddy);

        // 5. Verifications

        // Verify Dive Center created with correct diverId
        final diveCenter = await (db.select(
          db.diveCenters,
        )..where((t) => t.id.equals(diveCenterId))).getSingle();
        expect(diveCenter.name, equals(buddy.name));
        expect(diveCenter.diverId, equals(diverId));

        // Verify Dive updated
        final dive = await (db.select(
          db.dives,
        )..where((t) => t.id.equals('dive-conv-1'))).getSingle();
        expect(dive.diveCenterId, equals(diveCenterId));

        // Verify Buddy deleted
        final buddies = await (db.select(
          db.buddies,
        )..where((t) => t.id.equals(buddy.id))).get();
        expect(buddies, isEmpty);

        // Verify Related data deleted
        final certs = await (db.select(
          db.certifications,
        )..where((t) => t.buddyId.equals(buddy.id))).get();
        expect(certs, isEmpty);

        final roles = await (db.select(
          db.buddyRoles,
        )..where((t) => t.buddyId.equals(buddy.id))).get();
        expect(roles, isEmpty);

        // Verify Tombstones exist in deletion_log
        final logs = await db.select(db.deletionLog).get();
        final logEntities = logs.map((l) => l.entityType).toList();
        expect(logEntities, contains('buddies'));
        expect(logEntities, contains('certifications'));
        expect(logEntities, contains('buddyRoles'));
        expect(logEntities, contains('diveBuddies'));
      },
    );
  });
}
