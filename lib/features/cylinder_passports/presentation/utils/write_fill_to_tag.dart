import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:submersion/features/cylinder_passports/domain/entities/cylinder_passport_payload.dart';
import 'package:submersion/features/cylinder_passports/presentation/providers/cylinder_passport_providers.dart';
import 'package:submersion/features/cylinder_passports/presentation/widgets/passport_tag_card.dart';
import 'package:submersion/features/equipment/presentation/providers/equipment_providers.dart';

/// What an NFC write for [equipmentId] carries right now: the full payload
/// with the newest fill, as the Tag card builds it (spec section 11).
final tagPayloadProvider = FutureProvider.autoDispose
    .family<CylinderPassportPayload?, String>((ref, equipmentId) async {
      final item = await ref.watch(equipmentItemProvider(equipmentId).future);
      if (item == null) return null;
      return fullPayloadFor(
        item,
        passportId: await ref.watch(passportIdProvider(equipmentId).future),
        clocks: await ref.watch(
          serviceClockStatusesProvider(equipmentId).future,
        ),
        records: await ref.watch(
          serviceRecordsForEquipmentProvider(equipmentId).future,
        ),
        now: DateTime.now(),
        newestFill: await ref.watch(newestFillProvider(equipmentId).future),
      );
    });
