import 'package:flutter/material.dart';

import 'package:submersion/core/constants/enums.dart';
import 'package:submersion/core/providers/provider.dart';
import 'package:submersion/core/services/logger_service.dart';
import 'package:submersion/features/cylinder_passports/domain/entities/cylinder_passport_payload.dart';
import 'package:submersion/features/cylinder_passports/presentation/providers/cylinder_passport_providers.dart';
import 'package:submersion/features/cylinder_passports/presentation/utils/print_passport_labels.dart';
import 'package:submersion/features/cylinder_passports/presentation/widgets/passport_current_fill_card.dart';
import 'package:submersion/features/cylinder_passports/presentation/widgets/passport_fill_history_card.dart';
import 'package:submersion/features/cylinder_passports/presentation/widgets/passport_o2_warning_banner.dart';
import 'package:submersion/features/cylinder_passports/presentation/widgets/passport_service_card.dart';
import 'package:submersion/features/cylinder_passports/presentation/widgets/passport_spec_card.dart';
import 'package:submersion/features/cylinder_passports/presentation/widgets/passport_tag_card.dart';
import 'package:submersion/features/divers/presentation/providers/diver_providers.dart';
import 'package:submersion/features/equipment/domain/constants/equipment_attribute_catalog.dart';
import 'package:submersion/features/equipment/domain/entities/equipment_item.dart';
import 'package:submersion/features/equipment/presentation/providers/equipment_providers.dart';
import 'package:submersion/features/equipment/presentation/utils/equipment_attribute_l10n.dart';
import 'package:submersion/l10n/l10n_extension.dart';

/// The scanned tag a route carried, or null when the route's extra is
/// anything else. A deep link or a restored route can arrive with an extra
/// of another type, and a hard cast would crash the page.
CylinderPassportPayload? scannedTagFrom(Object? extra) =>
    extra is CylinderPassportPayload ? extra : null;

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
  static final _log = LoggerService.forClass(PassportPage);

  @override
  void initState() {
    super.initState();
    // The passport id is minted the first time a cylinder's passport is
    // opened, so every card below can rely on one existing. Every await is
    // followed by a mounted check (ref is unusable once the page is gone),
    // only a live tank is minted for, and a failure is logged rather than
    // left to escape the microtask.
    Future<void>.microtask(_mintIfNeeded);
  }

  Future<void> _mintIfNeeded() async {
    final id = widget.equipmentId;
    try {
      final existing = await ref.read(passportIdProvider(id).future);
      if (existing != null || !mounted) return;
      final item = await ref.read(equipmentItemProvider(id).future);
      if (!mounted || item == null || item.type != EquipmentType.tank) return;
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

  /// Prints this cylinder's label, telling the diver when it fails instead of
  /// letting a database, PDF or share-sheet error escape the button.
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
                  onPrintLabel: (button) => _printLabel(equipment.id, button),
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
    final material = equipment.attrText(EquipmentAttrKeys.tankMaterial);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(equipment.name, style: theme.textTheme.headlineMedium),
        if (equipment.identifier != null)
          Text(equipment.identifier!, style: theme.textTheme.titleMedium),
        if (subtitle.isNotEmpty)
          Text(subtitle, style: theme.textTheme.bodyMedium),
        if (material != null) ...[
          const SizedBox(height: 8),
          Chip(
            avatar: const Icon(Icons.propane_tank_outlined, size: 18),
            label: Text(
              attributeChoiceLabel(
                context.l10n,
                EquipmentAttrKeys.tankMaterial,
                material,
              ),
            ),
            visualDensity: VisualDensity.compact,
          ),
        ],
      ],
    );
  }
}
