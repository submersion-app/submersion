import 'dart:convert';
import 'dart:typed_data';

import 'package:drift/drift.dart' show Value;
import 'package:flutter_test/flutter_test.dart';
import 'package:image/image.dart' as img;
import 'package:submersion/core/database/database.dart' show DivesCompanion;
import 'package:submersion/core/services/database_service.dart';
import 'package:submersion/features/buddies/data/services/buddy_card_builder.dart';
import 'package:submersion/features/buddies/domain/entities/buddy_card_share_choices.dart';
import 'package:submersion/features/buddies/domain/services/buddy_card_codec.dart';
import 'package:submersion/features/certification_agencies/domain/certification_catalog.dart';
import 'package:submersion/features/certifications/data/repositories/certification_repository.dart';
import 'package:submersion/features/certifications/domain/entities/certification.dart';
import 'package:submersion/features/dive_log/data/repositories/dive_repository_impl.dart';
import 'package:submersion/features/divers/data/repositories/diver_repository.dart';
import 'package:submersion/features/divers/domain/entities/diver.dart';

import '../../../helpers/test_database.dart';

void main() {
  late BuddyCardBuilder builder;

  setUp(() async {
    await setUpTestDatabase();
    builder = BuddyCardBuilder(
      divers: DiverRepository(),
      certifications: CertificationRepository(),
      dives: DiveRepository(),
      catalog: () async => CertificationCatalog(),
    );
  });
  tearDown(() => DatabaseService.instance.resetForTesting());

  Uint8List bigPhoto() {
    final image = img.Image(width: 512, height: 512);
    for (var y = 0; y < 512; y++) {
      for (var x = 0; x < 512; x++) {
        image.setPixelRgb(x, y, (x * 7) % 256, (y * 13) % 256, (x ^ y) % 256);
      }
    }
    return Uint8List.fromList(img.encodeJpg(image, quality: 95));
  }

  Future<void> seedDiver({
    String? phone = '+1 555 0199',
    String? email = 'jordan@example.com',
    Uint8List? photo,
    int? prior = 20,
    bool medical = false,
    String? social = '@jordan',
  }) async {
    await DiverRepository().createDiver(
      Diver(
        id: 'd1',
        name: 'Jordan Blake',
        phone: phone,
        email: email,
        photo: photo,
        socialHandle: social,
        priorDiveCount: prior,
        divingSince: DateTime(2012),
        medicalNotes: medical ? 'SECRET-MEDICAL' : '',
        allergies: medical ? 'SECRET-ALLERGY' : null,
        createdAt: DateTime(2026),
        updatedAt: DateTime(2026),
      ),
    );
  }

  Future<void> seedDive(DateTime at) async {
    final db = DatabaseService.instance.database;
    await db
        .into(db.dives)
        .insert(
          DivesCompanion.insert(
            id: 'dive-${at.millisecondsSinceEpoch}',
            diverId: const Value('d1'),
            diveDateTime: at.millisecondsSinceEpoch,
            createdAt: 1,
            updatedAt: 1,
          ),
        );
  }

  Future<void> seedCert(String agency, String level, String name) async {
    await CertificationRepository().createCertification(
      Certification(
        id: '',
        diverId: 'd1',
        name: name,
        agency: agency,
        level: level,
        cardNumber: 'NUM-$level',
        issueDate: DateTime(2018),
        createdAt: DateTime(2026),
        updatedAt: DateTime(2026),
      ),
    );
  }

  test('card id is the diver id and name is always sent', () async {
    await seedDiver();
    final card = await builder.build(
      'd1',
      const BuddyCardShareChoices(
        photo: false,
        phone: false,
        email: false,
        certifications: false,
        cardDetails: false,
        diveCount: false,
        divingSince: false,
        lastDive: false,
        social: false,
      ),
    );
    expect(card.id, 'd1');
    expect(card.name, 'Jordan Blake');
    expect(card.phone, isNull);
    expect(card.email, isNull);
    expect(card.certs, isEmpty);
    expect(card.dives, isNull);
    expect(card.since, isNull);
    expect(card.last, isNull);
    expect(card.social, isNull);
  });

  test('builds only the chosen fields', () async {
    await seedDiver();
    final card = await builder.build('d1', BuddyCardShareChoices.defaults);
    expect(card.phone, '+1 555 0199');
    expect(card.email, 'jordan@example.com');
    expect(card.social, isNull, reason: 'social is off by default');
    expect(card.since, 2012);
  });

  test('dive count is logged dives plus priorDiveCount', () async {
    await seedDiver(prior: 20);
    await seedDive(DateTime.utc(2026, 9, 1, 10));
    await seedDive(DateTime.utc(2026, 10, 3, 9));
    final card = await builder.build('d1', BuddyCardShareChoices.defaults);
    expect(card.dives, 22);
  });

  test('last is the newest dive date', () async {
    await seedDiver();
    await seedDive(DateTime.utc(2026, 9, 1, 10));
    await seedDive(DateTime.utc(2026, 10, 3, 23, 30));
    final card = await builder.build('d1', BuddyCardShareChoices.defaults);
    expect(card.last, DateTime(2026, 10, 3));
  });

  test('certs are highest first, without numbers unless cardDetails', () async {
    await seedDiver();
    await seedCert('padi', 'openWater', 'Open Water Diver');
    await seedCert('padi', 'rescue', 'Rescue Diver');
    var card = await builder.build('d1', BuddyCardShareChoices.defaults);
    expect(card.certs.map((c) => c.level), ['Rescue Diver', 'Open Water']);
    expect(card.certs.first.agency, 'PADI');
    expect(card.certs.every((c) => c.cardNumber == null), isTrue);

    card = await builder.build(
      'd1',
      BuddyCardShareChoices.defaults.copyWith(cardDetails: true),
    );
    expect(card.certs.first.cardNumber, 'NUM-rescue');
    expect(card.certs.first.issueDate, DateTime(2018));
  });

  test('photo is resized to at most 160 px and 12 KB', () async {
    await seedDiver(photo: bigPhoto());
    final card = await builder.build('d1', BuddyCardShareChoices.defaults);
    expect(card.photo, isNotNull);
    expect(card.photo!.length, lessThanOrEqualTo(BuddyCardCodec.maxPhotoBytes));
    final decoded = img.decodeJpg(card.photo!)!;
    expect(decoded.width, lessThanOrEqualTo(160));
    expect(decoded.height, lessThanOrEqualTo(160));
  });

  test('a diver with nothing filled gives a name-only card', () async {
    await seedDiver(phone: null, email: null, prior: null, social: null);
    final card = await builder.build('d1', BuddyCardShareChoices.defaults);
    expect(card.phone, isNull);
    expect(card.email, isNull);
    expect(card.certs, isEmpty);
    expect(card.photo, isNull);
    expect(card.dives, isNull, reason: 'no dives logged and no prior count');
    final fields = await builder.availableFields('d1');
    expect(fields, {BuddyCardField.divingSince});
  });

  test('never reads medical, insurance or emergency fields', () async {
    await seedDiver(medical: true);
    final card = await builder.build(
      'd1',
      BuddyCardShareChoices.defaults.copyWith(social: true, cardDetails: true),
    );
    final text = utf8.decode(BuddyCardCodec.encodeFull(card));
    expect(text, isNot(contains('SECRET')));
  });
}
