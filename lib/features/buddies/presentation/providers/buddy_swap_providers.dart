import 'package:file_picker/file_picker.dart';
import 'package:flutter/foundation.dart';

import 'package:submersion/core/providers/provider.dart';
import 'package:submersion/core/services/nearby/multipeer/multipeer_nearby_carrier.dart';
import 'package:submersion/features/buddies/data/services/buddy_card_nfc.dart';
import 'package:submersion/features/buddies/data/services/card_emulation_service.dart';
import 'package:submersion/features/buddies/domain/entities/buddy_card.dart';
import 'package:submersion/features/buddies/presentation/services/buddy_swap_session.dart';
import 'package:submersion/features/buddies/presentation/services/recent_buddy_card_links.dart';
import 'package:submersion/features/cylinder_passports/presentation/providers/cylinder_passport_providers.dart';
import 'package:submersion/features/demo_mode/data/demo_mode_gate.dart';
import 'package:submersion/features/demo_mode/domain/demo_sealed_feature.dart';
import 'package:submersion/features/settings/presentation/providers/nearby_providers.dart';

/// Buddy cards over NFC: reading, sticker writing, and Android tag sharing.
final buddyCardNfcProvider = Provider<BuddyCardNfc>((ref) {
  return BuddyCardNfc(
    tags: ref.watch(nfcTagServiceProvider),
    emulation: ref.watch(cardEmulationProvider),
    onTagLink: ref.watch(recentBuddyCardLinksProvider).note,
  );
});

/// Multipeer Connectivity on Apple devices; null elsewhere.
final multipeerCarrierProvider = Provider<MultipeerNearbyCarrier?>((ref) {
  if (kIsWeb) return null;
  if (defaultTargetPlatform != TargetPlatform.iOS &&
      defaultTargetPlatform != TargetPlatform.macOS) {
    return null;
  }
  final carrier = MultipeerNearbyCarrier();
  ref.onDispose(carrier.dispose);
  return carrier;
});

/// Makes the swap screen's session for the diver's [card]. Tests override
/// it with a fake.
final buddySwapSessionFactoryProvider =
    Provider<BuddySwapSession Function(BuddyCard card)>((ref) {
      return (card) => NearbyBuddySwapSession(
        card: card,
        manager: ref.read(nearbyLinkManagerProvider),
        identity: () => ref.read(nearbySyncEngineProvider).identity(),
        secrets: ref.read(nearbyPairSecretsProvider),
        nfc: ref.read(buddyCardNfcProvider),
        multipeer: ref.read(multipeerCarrierProvider),
      );
    });

/// Picks a buddy card file and returns its bytes; null when none was
/// picked. Tests override it.
final buddyCardFilePickerProvider = Provider<Future<Uint8List?> Function()>((
  ref,
) {
  return () async {
    // Demo mode (issue #3708): no card comes in from a file.
    DemoModeGate.instance.ensureNotDemo(DemoSealedFeature.fileImport);
    final picked = await FilePicker.pickFiles(type: FileType.any);
    if (picked.isEmpty) return null;
    return picked.first.readAsBytes();
  };
});
