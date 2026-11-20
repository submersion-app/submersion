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
import 'package:submersion/features/cylinder_passports/presentation/widgets/passport_trip_card.dart';
import 'package:submersion/features/cylinder_passports/presentation/widgets/passport_usage_card.dart';
import 'package:submersion/features/cylinder_passports/presentation/widgets/twin_set_card.dart';
import 'package:submersion/features/divers/presentation/providers/diver_providers.dart';
import 'package:submersion/features/equipment/domain/constants/equipment_attribute_catalog.dart';
import 'package:submersion/features/equipment/domain/entities/equipment_item.dart';
import 'package:submersion/features/equipment/presentation/providers/equipment_providers.dart';
import 'package:submersion/features/equipment/presentation/utils/equipment_attribute_l10n.dart';
import 'package:submersion/features/equipment/presentation/editing/gear_item_passport_cards.dart';
import 'package:submersion/features/equipment/presentation/editing/gear_item_passport_sitting.dart';
import 'package:submersion/features/equipment/presentation/editing/gear_item_sitting_host.dart';
import 'package:submersion/l10n/l10n_extension.dart';
import 'package:submersion/shared/widgets/record_editing/add_strip.dart';
import 'package:submersion/shared/widgets/record_editing/edit_card.dart';
import 'package:submersion/shared/widgets/record_editing/edit_session.dart';
import 'package:submersion/shared/widgets/record_editing/record_card_fade.dart';
import 'package:submersion/shared/widgets/record_editing/record_card_frame.dart';
import 'package:submersion/shared/widgets/record_editing/record_edit_controller.dart';
import 'package:submersion/shared/widgets/record_editing/record_edit_host.dart';

/// The scanned tag a route carried, or null when the route's extra is
/// anything else. A deep link or a restored route can arrive with an extra
/// of another type, and a hard cast would crash the page.
CylinderPassportPayload? scannedTagFrom(Object? extra) =>
    extra is CylinderPassportPayload ? extra : null;

/// One cylinder's passport (spec section 8): every card names its source of
/// truth, and every value with a unit goes through the unit formatter.
///
/// It is a satellite page of the cylinder's gear item (issue #4527): opened
/// alone it opens locked, and its own Unlock, Cancel and Save hold and write
/// the item's changes as one History entry; pushed from an unlocked item page
/// ([joined]) it joins that sitting and shows Done.
class PassportPage extends ConsumerStatefulWidget {
  const PassportPage({
    super.key,
    required this.equipmentId,
    this.scannedTag,
    this.joined,
  });

  final String equipmentId;

  /// The tag that opened this passport, when a scan or a link did; drives
  /// the stale-tag hint on the Tag card.
  final CylinderPassportPayload? scannedTag;

  /// The item page's sitting this page was pushed into, while unlocked.
  final RecordEditController<EquipmentItem>? joined;

  @override
  ConsumerState<PassportPage> createState() => _PassportPageState();
}

class _PassportPageState extends ConsumerState<PassportPage>
    with
        RecordEditHost<PassportPage, EquipmentItem>,
        GearItemSittingHost<PassportPage> {
  static final _log = LoggerService.forClass(PassportPage);

  @override
  String get hostRecordId => widget.equipmentId;

  @override
  RecordEditController<EquipmentItem>? get joinedSitting => widget.joined;

  /// The Tag card keeps the page's stale hint and Print button when open.
  late final EditCard<EquipmentItem> _tagCard = passportTagCard(
    scannedTag: widget.scannedTag,
    onPrintLabel: (button) => _printLabel(widget.equipmentId, button),
  );

  @override
  Iterable<EditCard<EquipmentItem>> get hostEditCards => [
    passportServiceCard,
    passportFillsCard,
    _tagCard,
    passportTripCard,
  ];

  @override
  List<AddStripEntry> addStripEntries(EquipmentItem working) => const [];

  /// Only the lists this page's cards hold.
  @override
  void onSittingStart(
    EditSession<EquipmentItem> session,
    ProviderContainer container,
  ) => loadGearPassportSitting(session);

  @override
  void dispose() {
    disposeEditing();
    super.dispose();
  }

  /// [child] as [card].
  Widget _framed(EditCard<EquipmentItem> card, Widget child) =>
      RecordCardFrame<EquipmentItem>(card: card, child: child);

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
    followStored(equipmentItemProvider(widget.equipmentId));
    final equipment = equipmentAsync.value;
    if (equipment == null) {
      return Scaffold(
        appBar: AppBar(title: Text(l10n.passport_title)),
        body: equipmentAsync.when(
          loading: () => const Center(child: CircularProgressIndicator()),
          error: (e, _) => Center(child: Text(e.toString())),
          data: (_) => const SizedBox.shrink(),
        ),
      );
    }
    final shown = shownRecord(equipment);
    return editScaffold(
      record: equipment,
      shown: shown,
      lockedBar: AppBar(
        title: Text(l10n.passport_title),
        actions: [lockButton(shown)],
      ),
      content: _body(shown),
    );
  }

  /// The cards, of [equipment] as the page shows it: the sitting's while
  /// one is open.
  Widget _body(EquipmentItem equipment) {
    final stored = ref.watch(passportIdProvider(widget.equipmentId)).value;
    final session = maybeEditController?.session;
    final passportId = session == null
        ? stored
        : passportIdInSitting(session, stored);
    Widget calculated(Widget child) => RecordCardFade<EquipmentItem>(
      reason: RecordCardFadeReason.calculated,
      child: child,
    );
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _PassportHeader(equipment: equipment),
          TwinSetPartnerLine(equipmentId: equipment.id),
          const SizedBox(height: 16),
          PassportO2WarningBanner(equipmentId: equipment.id),
          calculated(PassportSpecCard(equipment: equipment)),
          const SizedBox(height: 16),
          _framed(
            passportServiceCard,
            PassportServiceCard(equipment: equipment),
          ),
          const SizedBox(height: 16),
          _framed(
            passportFillsCard,
            Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                PassportCurrentFillCard(
                  equipmentId: equipment.id,
                  passportId: passportId,
                ),
                const SizedBox(height: 16),
                PassportFillHistoryCard(equipmentId: equipment.id),
              ],
            ),
          ),
          // The dives this cylinder was used on (issue #2650), with its
          // own gap so a cylinder never used leaves none. Faded only while
          // it shows something: an empty card draws nothing to label. The
          // stored passport's: a tag linked in the sitting is not its yet.
          if (stored != null) _usageCard(stored),
          const SizedBox(height: 16),
          _framed(
            _tagCard,
            PassportTagCard(
              equipment: equipment,
              scannedTag: widget.scannedTag,
              onPrintLabel: (button) => _printLabel(equipment.id, button),
            ),
          ),
          const SizedBox(height: 16),
          _framed(
            passportTripCard,
            PassportTripCard(equipmentId: equipment.id),
          ),
        ],
      ),
    );
  }
}

extension on _PassportPageState {
  Widget _usageCard(String passportId) {
    final card = PassportUsageCard(
      passportId: passportId,
      title: PassportUsageTitle.own,
      topGap: 16,
    );
    final dives = ref.watch(passportUsageProvider(passportId)).value;
    if (dives == null || dives.isEmpty) return card;
    return RecordCardFade<EquipmentItem>(
      reason: RecordCardFadeReason.calculated,
      child: card,
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
