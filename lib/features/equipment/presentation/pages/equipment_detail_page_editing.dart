part of 'equipment_detail_page.dart';

/// The gear item page's use of the shared editing host (issue #4527, phase
/// 3, plan 6): its cards, the frames its sections sit in and its pane. How a
/// sitting on an item loads and saves is [GearItemSittingHost]'s.
mixin _EquipmentDetailPageEditing
    on
        ConsumerState<EquipmentDetailPage>,
        RecordEditHost<EquipmentDetailPage, EquipmentItem>,
        RecordOpenUnlocked<EquipmentDetailPage, EquipmentItem>,
        GearItemSittingHost<EquipmentDetailPage> {
  @override
  String get hostRecordId => widget.equipmentId;

  @override
  bool openUnlockedOf(EquipmentDetailPage widget) => widget.openUnlocked;

  @override
  VoidCallback? get onOpenedSittingEnded => widget.onSittingEnded;

  @override
  void onEditChanged() {
    noteOpenedSittingEnded();
    super.onEditChanged();
  }

  @override
  Iterable<EditCard<EquipmentItem>> get hostEditCards =>
      gearItemEditCards.values;

  /// In the list's pane, an item the list's view no longer shows (its
  /// status, its tags) is offered the view that does, as the form did.
  @override
  void onGearItemSaved(
    EditSession<EquipmentItem> session,
    EquipmentItem? after,
    ProviderContainer container,
  ) {
    if (after == null || !widget.embedded || !mounted) return;
    unawaited(
      offerViewRevealingSavedItem(
        messenger: ScaffoldMessenger.of(context),
        l10n: context.l10n,
        container: container,
        equipmentId: after.id,
        status: after.status,
      ),
    );
  }

  /// The cards the page leaves out while they are empty.
  @override
  List<AddStripEntry> addStripEntries(EquipmentItem working) {
    final session = maybeEditController?.session;
    if (session == null) return const [];
    return [
      for (final id in gearItemOptionalCards)
        if (gearItemEditCards[id]!.isEmpty(working) && !_showsWhileEmpty(id))
          AddStripEntry(
            cardId: id.name,
            label: gearItemEditCards[id]!.title(context),
            changed: session.changedCardIds.contains(id.name),
          ),
    ];
  }

  /// Whether [id] is shown though empty: open or brought in from the strip
  /// during the sitting.
  bool _showsWhileEmpty(GearItemCardId id) {
    final controller = maybeEditController;
    if (controller == null || !controller.isUnlocked) return false;
    return controller.openCardIds.contains(id.name) ||
        controller.addedCardIds.contains(id.name);
  }

  /// [child] as the card [id], framed for editing in place; [topGap] is the
  /// gap a card that places its own puts above itself.
  Widget _framed(GearItemCardId id, Widget child, {double topGap = 0}) =>
      RecordCardFrame<EquipmentItem>(
        card: gearItemEditCards[id]!,
        topGap: topGap,
        child: child,
      );
}

/// [child], a section the page calculates, faded and labelled
/// "Calculated" while unlocked; untouched where the page does not edit in
/// place.
Widget _calculated(Widget child) => RecordCardFade<EquipmentItem>(
  reason: RecordCardFadeReason.calculated,
  child: child,
);
