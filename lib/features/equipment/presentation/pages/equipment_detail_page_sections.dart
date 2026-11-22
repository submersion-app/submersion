part of 'equipment_detail_page.dart';

/// The gear item page's read sections, each a card that the editing host
/// frames (issue #4527, phase 3, plan 6).
extension _EquipmentDetailSections on _EquipmentDetailContent {
  /// The item's tags under its name: the sitting's while it holds them.
  Widget _headerTagChips() {
    final session = host.maybeEditController?.session;
    if (session == null) return EquipmentTagChips(equipmentId: equipmentId);
    return ListenableBuilder(
      listenable: gearItemTagsList.changes(session),
      builder: (context, _) => EquipmentTagChips(
        equipmentId: equipmentId,
        tags: gearItemTagsList.current(session),
      ),
    );
  }

  Widget _buildHeaderSection(
    BuildContext context,
    EquipmentItem equipment,
    bool isServiceOverdue,
    RollupClock? headerClock,
  ) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            Row(
              children: [
                // The chosen cover photo, else the type icon (#3355).
                EquipmentAvatar(
                  item: equipment,
                  radius: 32,
                  iconSize: 32,
                  backgroundColor: isServiceOverdue
                      ? StatusColors.of(context).alert.container
                      : Theme.of(context).colorScheme.tertiaryContainer,
                  iconColor: isServiceOverdue
                      ? StatusColors.of(context).alert.onContainer
                      : Theme.of(context).colorScheme.onTertiaryContainer,
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Expanded(
                            child: Text(
                              equipment.name,
                              style: Theme.of(context).textTheme.titleLarge,
                            ),
                          ),
                          RecordCardPencil(
                            cardTitle: GearItemCardId.header
                                .localizedDisplayName(context.l10n),
                          ),
                        ],
                      ),
                      Text(
                        equipment.type.localizedName(context.l10n),
                        style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                          color: Theme.of(context).colorScheme.onSurfaceVariant,
                        ),
                      ),
                      // Why the item is out of the kit (#2025). The purchase
                      // of wishlist gear is made in the header block's
                      // editor.
                      EquipmentHeaderStatus(item: equipment),
                      // Tags (issue #1942), under the name and type: the
                      // sitting's while unlocked.
                      _headerTagChips(),
                    ],
                  ),
                ),
              ],
            ),
            if (headerClock case final clock?) ...[
              const SizedBox(height: 16),
              // Worked out from the clocks: faded while unlocked.
              _calculated(
                _ServiceBanner(clock: clock, subjectId: equipment.id),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildDetailsSection(
    BuildContext context,
    WidgetRef ref,
    EquipmentItem equipment,
    UnitFormatter units,
  ) {
    final diveCountAsync = ref.watch(equipmentDiveCountProvider(equipmentId));
    final tripCountAsync = ref.watch(equipmentTripCountProvider(equipmentId));
    // The item this one is installed in. A parent id naming nothing (a
    // parent row that never arrived) resolves to null and shows no row.
    final parentId = equipment.parentEquipmentId;
    final host = parentId == null
        ? null
        : ref.watch(equipmentItemProvider(parentId)).value;
    final showsInstallAge = InstalledInRow.showsInstallAge(equipment, host);

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        // One label column for every row of the card (issue #3678).
        child: DetailRowGroup(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Expanded(
                    child: Text(
                      context.l10n.equipment_detail_detailsTitle,
                      style: Theme.of(context).textTheme.titleMedium,
                    ),
                  ),
                  RecordCardPencil(
                    cardTitle: context.l10n.equipment_detail_detailsTitle,
                  ),
                ],
              ),
              const Divider(),
              _buildDetailRow(
                context,
                context.l10n.equipment_detail_statusLabel,
                equipment.status.localizedName(context.l10n),
              ),
              if (host != null)
                InstalledInRow(part: equipment, host: host, units: units),
              diveCountAsync.when(
                data: (count) => _buildCountLinkRow(
                  context,
                  label: context.l10n.equipment_detail_divesLabel,
                  semanticsLabel:
                      context.l10n.equipment_detail_divesSemanticLabel,
                  countText: count == 1
                      ? context.l10n.equipment_detail_divesCountSingular(count)
                      : context.l10n.equipment_detail_divesCountPlural(count),
                  count: count,
                  onTap: () => openDiveList(
                    context,
                    ref,
                    DiveFilterState.itemUse(equipmentId),
                  ),
                ),
                loading: () => _buildDetailRow(
                  context,
                  context.l10n.equipment_detail_divesLabel,
                  '...',
                ),
                error: (e, s) => const SizedBox.shrink(),
              ),
              EquipmentDiveTimeRow(equipmentId: equipmentId),
              // A reload, since the count follows the trip filter: every dive
              // write runs one, and the row keeps its figure meanwhile.
              tripCountAsync.when(
                skipLoadingOnReload: true,
                data: (count) => _buildCountLinkRow(
                  context,
                  label: context.l10n.equipment_detail_tripsLabel,
                  semanticsLabel:
                      context.l10n.equipment_detail_tripsSemanticLabel,
                  countText: count == 1
                      ? context.l10n.equipment_detail_tripsCountSingular(count)
                      : context.l10n.equipment_detail_tripsCountPlural(count),
                  count: count,
                  onTap: () => openTripList(
                    context,
                    ref,
                    TripFilterState(equipmentId: equipmentId),
                  ),
                ),
                loading: () => _buildDetailRow(
                  context,
                  context.l10n.equipment_detail_tripsLabel,
                  '...',
                ),
                error: (e, s) => const SizedBox.shrink(),
              ),
              // Sharing is chosen in the Details editor; closed, the card
              // shows what the sitting holds.
              EquipmentSharingRow(
                equipment: equipment,
                shown: this.host.maybeEditController?.session,
              ),
              if (equipment.brand != null)
                _buildDetailRow(
                  context,
                  context.l10n.equipment_detail_brandLabel,
                  equipment.brand!,
                ),
              if (equipment.model != null)
                _buildDetailRow(
                  context,
                  context.l10n.equipment_detail_modelLabel,
                  equipment.model!,
                ),
              if (equipment.serialNumber != null)
                _buildDetailRow(
                  context,
                  context.l10n.equipment_detail_serialNumberLabel,
                  equipment.serialNumber!,
                  copyable: true,
                ),
              // Curated specs in catalog order, then custom fields. The
              // purchase group is held back to the purchase block below, and
              // the install date to the installed-in row while it shows one.
              for (final def
                  in EquipmentAttributeCatalog.attributesFor(
                    equipment.type,
                  ).where(
                    (d) =>
                        d.group == AttributeGroup.spec &&
                        !(showsInstallAge &&
                            d.key == EquipmentAttrKeys.installedDate),
                  ))
                if (equipment.attributes.firstWhereOrNull(
                      (a) => !a.isCustom && a.key == def.key,
                    )
                    case final attr? when attr.hasValue)
                  _buildDetailRow(
                    context,
                    attributeLabel(context.l10n, def.key),
                    formatAttributeValue(
                      attr,
                      def,
                      units,
                      context.l10n,
                      workingPressureBar: equipment.workingPressureBar,
                    ),
                  ),
              // The item's colour (issue #2326): its own row with a swatch,
              // only when the stored value is a colour code and the type has
              // a colour. On a type without one it shows as a custom field
              // (issue #2520), the way the Details editor keeps it.
              if (EquipmentAttributeCatalog.hasColor(equipment.type))
                if (normalizeEquipmentColor(
                      equipment.attrText(EquipmentAttrKeys.color),
                    )
                    case final code?)
                  _buildColorRow(context, code),
              // Where the diver moved it on the figure (issue #4493), while
              // the item still has artwork for that spot.
              if (figurePositionLabelOf(context.l10n, equipment)
                  case final shown?)
                _buildDetailRow(
                  context,
                  attributeLabel(
                    context.l10n,
                    EquipmentAttrKeys.figurePosition,
                  ),
                  shown,
                ),
              for (final attr
                  in keepStrayColorAsCustom(
                      equipment.type,
                      equipment.attributes,
                    ).where((a) => a.isCustom).toList()
                    ..sort((a, b) => a.sortOrder.compareTo(b.sortOrder)))
                if (attr.hasValue)
                  _buildDetailRow(context, attr.key, attr.valueText ?? ''),
              if (equipment.purchaseDate != null)
                _buildDetailRow(
                  context,
                  context.l10n.equipment_detail_purchaseDateLabel,
                  units.formatDate(equipment.purchaseDate),
                ),
              if (equipment.purchasePrice != null)
                _buildDetailRow(
                  context,
                  // Wishlist gear (#2025) has a price to pay, not one paid.
                  equipment.isWanted
                      ? context.l10n.equipment_edit_expectedPriceLabel
                      : context.l10n.equipment_detail_purchasePriceLabel,
                  formatMoney(
                    equipment.purchasePrice!,
                    equipment.purchaseCurrency,
                  ),
                ),
              // Purchase record (issue #1517): the receipt trail, shown with
              // the date and price rather than among the physical specs.
              for (final def in EquipmentAttributeCatalog.purchase)
                if (equipment.attributes.firstWhereOrNull(
                      (a) => !a.isCustom && a.key == def.key,
                    )
                    case final attr? when attr.hasValue)
                  _buildPurchaseAttributeRow(context, ref, def, attr, units),
              if (equipment.ownershipDuration != null)
                _buildDetailRow(
                  context,
                  context.l10n.equipment_detail_ownedForLabel,
                  equipmentOwnedForText(
                    context.l10n,
                    equipment.ownershipDuration!,
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }

  /// A count that opens the matching list when it is above zero: the Dives
  /// and Trips rows.
  Widget _buildCountLinkRow(
    BuildContext context, {
    required String label,
    required String semanticsLabel,
    required String countText,
    required int count,
    required VoidCallback onTap,
  }) {
    final theme = Theme.of(context);
    return Semantics(
      button: count > 0,
      label: semanticsLabel,
      child: InkWell(
        onTap: count > 0 ? onTap : null,
        borderRadius: BorderRadius.circular(8),
        child: DetailRow(
          label: label,
          value: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Flexible(
                child: Text(
                  countText,
                  style: theme.textTheme.bodyMedium?.copyWith(
                    color: count > 0 ? theme.colorScheme.primary : null,
                  ),
                ),
              ),
              if (count > 0) ...[
                const SizedBox(width: 4),
                Icon(
                  Icons.chevron_right,
                  size: 18,
                  color: theme.colorScheme.primary,
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildNotesSection(BuildContext context, EquipmentItem equipment) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(
                  Icons.notes,
                  size: 20,
                  color: Theme.of(context).colorScheme.primary,
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    context.l10n.equipment_detail_notesTitle,
                    style: Theme.of(context).textTheme.titleMedium,
                  ),
                ),
                RecordCardPencil(
                  cardTitle: context.l10n.equipment_detail_notesTitle,
                ),
              ],
            ),
            const SizedBox(height: 8),
            MarkdownNotesView(equipment.notes),
          ],
        ),
      ),
    );
  }

  /// One purchase-record row. A `url` attribute whose stored text resolves
  /// to an http(s) link becomes tappable; anything else (including a value
  /// [parseWebLink] rejects) renders as plain text, so a garbled link is
  /// still visible and editable rather than silently dropped.
  Widget _buildPurchaseAttributeRow(
    BuildContext context,
    WidgetRef ref,
    EquipmentAttributeDef def,
    EquipmentAttribute attr,
    UnitFormatter units,
  ) {
    final label = attributeLabel(context.l10n, def.key);
    if (def.kind == AttributeKind.url) {
      final link = parseWebLink(attr.valueText);
      if (link != null) {
        return _buildLinkRow(context, ref, label, attr.valueText!, link);
      }
    }
    return _buildDetailRow(
      context,
      label,
      formatAttributeValue(attr, def, units, context.l10n),
    );
  }

  /// [_buildDetailRow] with the value rendered as a tappable link.
  Widget _buildLinkRow(
    BuildContext context,
    WidgetRef ref,
    String label,
    String value,
    Uri link,
  ) {
    final theme = Theme.of(context);
    return DetailRow(
      label: label,
      value: InkWell(
        key: const ValueKey('equipment-detail-web-link'),
        onTap: () => launchEquipmentWebLink(
          context,
          link,
          launch: ref.read(equipmentWebLinkLaunchProvider),
        ),
        child: Text(
          value,
          style: theme.textTheme.bodyMedium?.copyWith(
            color: theme.colorScheme.primary,
            decoration: TextDecoration.underline,
            decorationColor: theme.colorScheme.primary,
          ),
        ),
      ),
    );
  }

  /// The item's colour: its label, then a swatch and the colour's name.
  Widget _buildColorRow(BuildContext context, String code) {
    final theme = Theme.of(context);
    return DetailRow(
      label: attributeLabel(context.l10n, EquipmentAttrKeys.color),
      value: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            key: const ValueKey('detail-color-swatch'),
            width: 16,
            height: 16,
            decoration: BoxDecoration(
              color: TagColors.fromHex(code),
              shape: BoxShape.circle,
              border: Border.all(color: theme.colorScheme.outlineVariant),
            ),
          ),
          const SizedBox(width: 8),
          Flexible(
            child: Text(
              equipmentColorName(context.l10n, code),
              style: theme.textTheme.bodyMedium,
            ),
          ),
        ],
      ),
    );
  }

  /// Long values (e.g. free-text custom fields) wrap within the value
  /// column instead of overflowing the row.
  Widget _buildDetailRow(
    BuildContext context,
    String label,
    String value, {
    bool copyable = false,
  }) {
    return DetailRow.text(
      label: label,
      value: value,
      valueStyle: Theme.of(context).textTheme.bodyMedium,
      copyable: copyable,
    );
  }
}

/// The header's service banner: which service is due, on which part, and
/// when, in the swatch of its own severity (red overdue, amber due soon).
/// It used to say only "Service is overdue!", which named neither (#2260).
///
/// The text takes the swatch's onContainer rather than the indicator's
/// accent: the banner fills itself with the container colour, and an accent
/// laid on its own container does not read.
class _ServiceBanner extends StatelessWidget {
  final RollupClock clock;
  final String subjectId;

  const _ServiceBanner({required this.clock, required this.subjectId});

  @override
  Widget build(BuildContext context) {
    final colors = StatusColors.of(context);
    final swatch =
        serviceSeveritySwatch(colors, clock.status.severity) ?? colors.alert;
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: swatch.container,
        border: Border.all(color: swatch.outline),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        children: [
          Icon(Icons.warning, color: swatch.onContainer),
          const SizedBox(width: 8),
          Expanded(
            child: ServiceStatusIndicator(
              clock: clock,
              subjectId: subjectId,
              density: ServiceIndicatorDensity.full,
              color: swatch.onContainer,
            ),
          ),
        ],
      ),
    );
  }
}
