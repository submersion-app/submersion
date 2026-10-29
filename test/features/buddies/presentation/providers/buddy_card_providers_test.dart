import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/core/providers/provider.dart';
import 'package:submersion/features/buddies/domain/entities/buddy_card_share_choices.dart';
import 'package:submersion/features/buddies/presentation/providers/buddy_card_providers.dart';
import 'package:submersion/features/divers/domain/entities/diver.dart';
import 'package:submersion/features/divers/presentation/providers/diver_providers.dart';

Diver _diver(String? share) => Diver(
  id: 'd1',
  name: 'Jordan',
  buddyCardShare: share,
  createdAt: DateTime(2026),
  updatedAt: DateTime(2026),
);

void main() {
  test('choices come from the current diver row', () async {
    final container = ProviderContainer(
      overrides: [
        currentDiverProvider.overrideWith(
          (ref) async => _diver('{"phone":false}'),
        ),
      ],
    );
    addTearDown(container.dispose);
    final choices = await container.read(myBuddyCardChoicesProvider.future);
    expect(choices.phone, isFalse);
    expect(choices.email, isTrue);
  });

  test('no diver means the defaults', () async {
    final container = ProviderContainer(
      overrides: [currentDiverProvider.overrideWith((ref) async => null)],
    );
    addTearDown(container.dispose);
    expect(
      await container.read(myBuddyCardChoicesProvider.future),
      BuddyCardShareChoices.defaults,
    );
  });

  test('withShareChoices stores the JSON on the diver', () {
    final updated = withShareChoices(
      _diver(null),
      BuddyCardShareChoices.defaults.copyWith(social: true),
    );
    expect(
      BuddyCardShareChoices.fromJson(updated.buddyCardShare).social,
      isTrue,
    );
  });
}
