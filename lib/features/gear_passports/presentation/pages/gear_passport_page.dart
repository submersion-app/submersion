import 'package:flutter/material.dart';

import 'package:submersion/core/constants/enums.dart';
import 'package:submersion/core/providers/provider.dart';
import 'package:submersion/core/services/logger_service.dart';
import 'package:submersion/features/cylinder_passports/presentation/pages/passport_page.dart';
import 'package:submersion/features/cylinder_passports/presentation/providers/cylinder_passport_providers.dart';
import 'package:submersion/features/cylinder_passports/presentation/utils/print_passport_labels.dart';
import 'package:submersion/features/cylinder_passports/presentation/widgets/passport_trip_card.dart';
import 'package:submersion/features/divers/presentation/providers/diver_providers.dart';
import 'package:submersion/features/equipment/presentation/providers/equipment_providers.dart';
import 'package:submersion/features/equipment/presentation/widgets/equipment_location_card.dart';
import 'package:submersion/features/equipment/presentation/widgets/exposure_card.dart';
import 'package:submersion/features/equipment/presentation/widgets/service_clocks_card.dart';
import 'package:submersion/features/equipment/presentation/widgets/service_record_dialog.dart';
import 'package:submersion/features/gear_passports/domain/entities/gear_tag_payload.dart';
import 'package:submersion/features/gear_passports/presentation/widgets/gear_passport_header.dart';
import 'package:submersion/features/gear_passports/presentation/widgets/gear_recent_service_card.dart';
import 'package:submersion/features/gear_passports/presentation/widgets/gear_tag_card.dart';
import 'package:submersion/l10n/l10n_extension.dart';

/// One item's gear passport (gear tag spec 9). A tank shows the cylinder
/// passport instead, so a stale link or a retyped item never lands on the
/// wrong page.
class GearPassportPage extends ConsumerStatefulWidget {
  const GearPassportPage({
    super.key,
    required this.equipmentId,
    this.scannedTag,
  });

  final String equipmentId;
  final GearTagPayload? scannedTag;

  @override
  ConsumerState<GearPassportPage> createState() => _GearPassportPageState();
}

class _GearPassportPageState extends ConsumerState<GearPassportPage> {
  static final _log = LoggerService.forClass(GearPassportPage);

  @override
  void initState() {
    super.initState();
    // Minted on first open, as the cylinder passport does; every await is
    // followed by a mounted check, and a failure is logged.
    Future<void>.microtask(_mintIfNeeded);
  }

  Future<void> _mintIfNeeded() async {
    final id = widget.equipmentId;
    try {
      final existing = await ref.read(passportIdProvider(id).future);
      if (existing != null || !mounted) return;
      final item = await ref.read(equipmentItemProvider(id).future);
      if (!mounted ||
          item == null ||
          item.type == EquipmentType.tank ||
          item.isWanted) {
        return;
      }
      final diverId = await ref.read(validatedCurrentDiverIdProvider.future);
      if (!mounted) return;
      await ref
          .read(cylinderPassportRepositoryProvider)
          .ensurePassportId(id, diverId: diverId);
      if (mounted) ref.invalidate(passportIdProvider(id));
    } catch (e, stackTrace) {
      _log.error(
        'Failed to mint a passport id for $id',
        error: e,
        stackTrace: stackTrace,
      );
    }
  }

  Future<void> _printLabel(String equipmentId, BuildContext button) async {
    final messenger = ScaffoldMessenger.of(context);
    final failedText = context.l10n.passport_tag_printFailed;
    try {
      await printPassportLabels(context, ref, [equipmentId], anchor: button);
    } catch (e, stackTrace) {
      _log.error(
        'Failed to print the label for $equipmentId',
        error: e,
        stackTrace: stackTrace,
      );
      if (!mounted) return;
      messenger.showSnackBar(SnackBar(content: Text(failedText)));
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final equipmentAsync = ref.watch(equipmentItemProvider(widget.equipmentId));
    return equipmentAsync.when(
      loading: () => Scaffold(
        appBar: AppBar(title: Text(l10n.gearPassport_title)),
        body: const Center(child: CircularProgressIndicator()),
      ),
      error: (e, _) => Scaffold(
        appBar: AppBar(title: Text(l10n.gearPassport_title)),
        body: Center(child: Text(e.toString())),
      ),
      data: (equipment) {
        if (equipment != null && equipment.type == EquipmentType.tank) {
          return PassportPage(equipmentId: equipment.id);
        }
        return Scaffold(
          appBar: AppBar(title: Text(l10n.gearPassport_title)),
          body: equipment == null
              ? const SizedBox.shrink()
              : SingleChildScrollView(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      GearPassportHeader(equipment: equipment),
                      const SizedBox(height: 16),
                      if (!equipment.isWanted) ...[
                        ServiceClocksCard(
                          equipmentId: equipment.id,
                          equipmentType: equipment.type,
                          onLogService: (status) => showLogServiceDialog(
                            context,
                            ref,
                            equipmentId: equipment.id,
                            serviceKindId: status.kind.id,
                          ),
                        ),
                        const SizedBox(height: 16),
                      ],
                      GearRecentServiceCard(equipmentId: equipment.id),
                      const SizedBox(height: 16),
                      ExposureCard(equipmentId: equipment.id),
                      const SizedBox(height: 16),
                      EquipmentLocationCard(equipment: equipment),
                      const SizedBox(height: 16),
                      PassportTripCard(equipmentId: equipment.id),
                      if (!equipment.isWanted) ...[
                        const SizedBox(height: 16),
                        GearTagCard(
                          equipment: equipment,
                          scannedTag: widget.scannedTag,
                          onPrintLabel: (b) => _printLabel(equipment.id, b),
                        ),
                      ],
                    ],
                  ),
                ),
        );
      },
    );
  }
}
