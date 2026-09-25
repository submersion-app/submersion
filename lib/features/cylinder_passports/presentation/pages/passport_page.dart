import 'package:flutter/material.dart';

import 'package:submersion/core/providers/provider.dart';
import 'package:submersion/features/cylinder_passports/domain/entities/cylinder_passport_payload.dart';
import 'package:submersion/features/cylinder_passports/presentation/providers/cylinder_passport_providers.dart';
import 'package:submersion/features/cylinder_passports/presentation/widgets/passport_current_fill_card.dart';
import 'package:submersion/features/cylinder_passports/presentation/widgets/passport_fill_history_card.dart';
import 'package:submersion/features/cylinder_passports/presentation/widgets/passport_o2_warning_banner.dart';
import 'package:submersion/features/cylinder_passports/presentation/widgets/passport_service_card.dart';
import 'package:submersion/features/cylinder_passports/presentation/widgets/passport_spec_card.dart';
import 'package:submersion/features/cylinder_passports/presentation/widgets/passport_tag_card.dart';
import 'package:submersion/features/divers/presentation/providers/diver_providers.dart';
import 'package:submersion/features/equipment/domain/entities/equipment_item.dart';
import 'package:submersion/features/equipment/presentation/providers/equipment_providers.dart';
import 'package:submersion/l10n/l10n_extension.dart';

/// One cylinder's passport (spec section 8): every card names its source of
/// truth, and every value with a unit goes through the unit formatter.
class PassportPage extends ConsumerStatefulWidget {
  const PassportPage({super.key, required this.equipmentId, this.scannedTag});

  final String equipmentId;

  /// The tag that opened this passport, when a scan or a link did; drives
  /// the stale-tag hint on the Tag card.
  final CylinderPassportPayload? scannedTag;

  @override
  ConsumerState<PassportPage> createState() => _PassportPageState();
}

class _PassportPageState extends ConsumerState<PassportPage> {
  @override
  void initState() {
    super.initState();
    // The passport id is minted the first time the passport is opened, so
    // every card below can rely on one existing.
    Future<void>.microtask(() async {
      final existing = await ref.read(
        passportIdProvider(widget.equipmentId).future,
      );
      if (existing != null || !mounted) return;
      final diverId = await ref.read(validatedCurrentDiverIdProvider.future);
      await ref
          .read(cylinderPassportRepositoryProvider)
          .ensurePassportId(widget.equipmentId, diverId: diverId);
      if (mounted) ref.invalidate(passportIdProvider(widget.equipmentId));
    });
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final equipmentAsync = ref.watch(equipmentItemProvider(widget.equipmentId));
    final passportId = ref.watch(passportIdProvider(widget.equipmentId)).value;
    return Scaffold(
      appBar: AppBar(title: Text(l10n.passport_title)),
      body: equipmentAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(child: Text(e.toString())),
        data: (equipment) {
          if (equipment == null) return const SizedBox.shrink();
          return SingleChildScrollView(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                _PassportHeader(equipment: equipment),
                const SizedBox(height: 16),
                PassportO2WarningBanner(equipmentId: equipment.id),
                PassportSpecCard(equipment: equipment),
                const SizedBox(height: 16),
                PassportServiceCard(equipment: equipment),
                const SizedBox(height: 16),
                PassportCurrentFillCard(
                  equipmentId: equipment.id,
                  passportId: passportId,
                ),
                const SizedBox(height: 16),
                PassportFillHistoryCard(equipmentId: equipment.id),
                const SizedBox(height: 16),
                PassportTagCard(
                  equipment: equipment,
                  scannedTag: widget.scannedTag,
                  // Task 15 wires onPrintLabel.
                ),
              ],
            ),
          );
        },
      ),
    );
  }
}

class _PassportHeader extends StatelessWidget {
  const _PassportHeader({required this.equipment});

  final EquipmentItem equipment;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final subtitle = [
      if (equipment.brand?.isNotEmpty ?? false) equipment.brand!,
      if (equipment.model?.isNotEmpty ?? false) equipment.model!,
      if (equipment.serialNumber?.isNotEmpty ?? false) equipment.serialNumber!,
    ].join(' ');
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(equipment.name, style: theme.textTheme.headlineMedium),
        if (equipment.identifier != null)
          Text(equipment.identifier!, style: theme.textTheme.titleMedium),
        if (subtitle.isNotEmpty)
          Text(subtitle, style: theme.textTheme.bodyMedium),
      ],
    );
  }
}
