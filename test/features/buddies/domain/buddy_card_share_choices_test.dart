import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/features/buddies/domain/entities/buddy_card_share_choices.dart';

void main() {
  test('defaults match the spec', () {
    const d = BuddyCardShareChoices.defaults;
    expect(d.photo, isTrue);
    expect(d.phone, isTrue);
    expect(d.email, isTrue);
    expect(d.certifications, isTrue);
    expect(d.diveCount, isTrue);
    expect(d.divingSince, isTrue);
    expect(d.lastDive, isTrue);
    expect(d.cardDetails, isFalse);
    expect(d.social, isFalse);
  });

  test('fromJson(null) is defaults', () {
    expect(
      BuddyCardShareChoices.fromJson(null),
      BuddyCardShareChoices.defaults,
    );
  });

  test('fromJson of garbage is defaults', () {
    expect(
      BuddyCardShareChoices.fromJson('not json'),
      BuddyCardShareChoices.defaults,
    );
  });

  test('fromJson ignores unknown keys and keeps defaults for missing', () {
    final c = BuddyCardShareChoices.fromJson('{"phone":false,"x":true}');
    expect(c.phone, isFalse);
    expect(c.email, isTrue);
    expect(c.social, isFalse);
  });

  test('round trip', () {
    final c = BuddyCardShareChoices.defaults.copyWith(
      phone: false,
      social: true,
      cardDetails: true,
    );
    expect(BuddyCardShareChoices.fromJson(c.toJson()), c);
  });
}
