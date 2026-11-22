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
import 'package:submersion/features/gear_passports/domain/entities/gear_tag_payload.dart';
import 'package:submersion/features/gear_passports/presentation/widgets/gear_passport_header.dart';
import 'package:submersion/features/gear_passports/presentation/widgets/gear_recent_service_card.dart';
import 'package:submersion/features/gear_passports/presentation/widgets/gear_tag_card.dart';
import 'package:submersion/features/equipment/domain/entities/equipment_item.dart';
import 'package:submersion/features/equipment/presentation/editing/gear_item_card_ids.dart';
import 'package:submersion/features/equipment/presentation/editing/gear_item_edit_cards.dart';
import 'package:submersion/features/equipment/presentation/editing/gear_item_passport_cards.dart';
import 'package:submersion/features/equipment/presentation/editing/gear_item_sitting_host.dart';
import 'package:submersion/l10n/l10n_extension.dart';
import 'package:submersion/shared/widgets/record_editing/add_strip.dart';
import 'package:submersion/shared/widgets/record_editing/edit_card.dart';
import 'package:submersion/shared/widgets/record_editing/edit_session.dart';
import 'package:submersion/shared/widgets/record_editing/record_card_fade.dart';
import 'package:submersion/shared/widgets/record_editing/record_card_frame.dart';
import 'package:submersion/shared/widgets/record_editing/record_edit_controller.dart';
import 'package:submersion/shared/widgets/record_editing/record_edit_host.dart';

/// One item's gear passport (gear tag spec 9). A tank shows the cylinder
/// passport instead, so a stale link or a retyped item never lands on the
/// wrong page.
///
/// It is a satellite page of the item (issue #4527), as the cylinder passport
/// is: opened alone it has its own lock and Save, pushed from an unlocked item
/// page ([joined]) it joins that sitting.
class GearPassportPage extends ConsumerStatefulWidget {
  const GearPassportPage({
    super.key,
    required this.equipmentId,
    this.scannedTag,
    this.joined,
  });

  final String equipmentId;
  final GearTagPayload? scannedTag;

  /// The item page's sitting this page was pushed into, while unlocked.
  final RecordEditController<EquipmentItem>? joined;

  @override
  ConsumerState<GearPassportPage> createState() => _GearPassportPageState();
}

class _GearPassportPageState extends ConsumerState<GearPassportPage>
    with
        RecordEditHost<GearPassportPage, EquipmentItem>,
        GearItemSittingHost<GearPassportPage> {
  static final _log = LoggerService.forClass(GearPassportPage);

  @override
  String get hostRecordId => widget.equipmentId;

  @override
  RecordEditController<EquipmentItem>? get joinedSitting => widget.joined;

  /// The Tag card keeps the page's stale hint and Print button when open.
  late final EditCard<EquipmentItem> _tagCard = passportTagCard(
    scannedTag: widget.scannedTag,
    onPrintLabel: (button) => _printLabel(widget.equipmentId, button),
  );

  EditCard<EquipmentItem> get _clocksCard =>
      gearItemEditCards[GearItemCardId.serviceClocks]!;

  EditCard<EquipmentItem> get _locationCard =>
      gearItemEditCards[GearItemCardId.location]!;

  @override
  Iterable<EditCard<EquipmentItem>> get hostEditCards => [
    _clocksCard,
    _locationCard,
    passportTripCard,
    _tagCard,
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
    final stored = equipmentAsync.value;
    if (stored != null && stored.type == EquipmentType.tank) {
      return PassportPage(equipmentId: stored.id, joined: widget.joined);
    }
    followStored(equipmentItemProvider(widget.equipmentId));
    if (stored != null) {
      final shown = shownRecord(stored);
      return editScaffold(
        record: stored,
        shown: shown,
        lockedBar: AppBar(
          title: Text(l10n.gearPassport_title),
          actions: [lockButton(shown)],
        ),
        content: _body(shown),
      );
    }
    return equipmentAsync.when(
      loading: () => Scaffold(
        appBar: AppBar(title: Text(l10n.gearPassport_title)),
        body: const Center(child: CircularProgressIndicator()),
      ),
      error: (e, _) => Scaffold(
        appBar: AppBar(title: Text(l10n.gearPassport_title)),
        body: Center(child: Text(e.toString())),
      ),
      data: (_) => Scaffold(
        appBar: AppBar(title: Text(l10n.gearPassport_title)),
        body: const SizedBox.shrink(),
      ),
    );
  }

  /// The cards, of [equipment] as the page shows it: the sitting's while
  /// one is open.
  Widget _body(EquipmentItem equipment) {
    final session = maybeEditController?.session;
    // See all opens the item's own page: not while this page is in a
    // sitting on the item, its own or the item page's it joined, which
    // would put a second page of the item over it (Call 10).
    final inSitting = maybeEditController?.isUnlocked ?? false;
    Widget calculated(Widget child) => RecordCardFade<EquipmentItem>(
      reason: RecordCardFadeReason.calculated,
      child: child,
    );
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          GearPassportHeader(equipment: equipment),
          const SizedBox(height: 16),
          if (!equipment.isWanted) ...[
            _framed(_clocksCard, ServiceClocksCard(equipmentId: equipment.id)),
            const SizedBox(height: 16),
          ],
          calculated(
            GearRecentServiceCard(
              equipmentId: equipment.id,
              offerSeeAll: !inSitting,
            ),
          ),
          const SizedBox(height: 16),
          calculated(ExposureCard(equipmentId: equipment.id)),
          const SizedBox(height: 16),
          _framed(
            _locationCard,
            EquipmentLocationCard(equipment: equipment, shown: session),
          ),
          const SizedBox(height: 16),
          _framed(
            passportTripCard,
            PassportTripCard(equipmentId: equipment.id),
          ),
          if (!equipment.isWanted) ...[
            const SizedBox(height: 16),
            _framed(
              _tagCard,
              GearTagCard(
                equipment: equipment,
                scannedTag: widget.scannedTag,
                onPrintLabel: (b) => _printLabel(equipment.id, b),
              ),
            ),
          ],
        ],
      ),
    );
  }
}
