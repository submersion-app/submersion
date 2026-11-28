import 'package:flutter/material.dart';

import 'package:submersion/core/providers/provider.dart';
import 'package:submersion/features/buddies/domain/entities/buddy.dart';
import 'package:submersion/features/buddies/presentation/providers/buddy_providers.dart';
import 'package:submersion/features/dive_centers/domain/entities/dive_center.dart';
import 'package:submersion/features/dive_centers/presentation/providers/dive_center_providers.dart';
import 'package:submersion/features/equipment/presentation/editing/gear_item_edit_fields.dart';
import 'package:submersion/l10n/l10n_extension.dart';

/// At most this many buddies and dive centres are suggested at once.
const _maxSuggestions = 8;

/// The purchase record's Seller (issue #5140): a text field that suggests
/// the diver's buddies and dive centres as they type. Picking one links it
/// and shows it as a chip; anything typed and not picked stays a typed
/// name, so a stranger or a shop needs no contact.
class EquipmentSellerField extends ConsumerStatefulWidget {
  final GearSeller value;
  final ValueChanged<GearSeller> onChanged;

  const EquipmentSellerField({
    super.key,
    required this.value,
    required this.onChanged,
  });

  @override
  ConsumerState<EquipmentSellerField> createState() =>
      _EquipmentSellerFieldState();
}

enum _Kind { buddy, center, typed }

class _Option {
  final _Kind kind;
  final String? id;
  final String name;

  const _Option(this.kind, this.name, [this.id]);
}

bool _isLinked(GearSeller v) => v.buddyId != null || v.centerId != null;

class _EquipmentSellerFieldState extends ConsumerState<EquipmentSellerField> {
  late final TextEditingController _text;
  final _focus = FocusNode();

  @override
  void initState() {
    super.initState();
    _text = TextEditingController(
      text: _isLinked(widget.value) ? '' : widget.value.name,
    );
  }

  @override
  void didUpdateWidget(EquipmentSellerField old) {
    super.didUpdateWidget(old);
    // Back to typing after a chip was cleared, or a value set from outside
    // (a clone's prefill): show the value, not the text left behind. Typing
    // itself never lands here, as its value is the text, give or take the
    // outer spaces the field ignores.
    final value = widget.value;
    if (!_isLinked(value) &&
        (_isLinked(old.value) || value.name.trim() != _text.text.trim())) {
      _text.text = value.name;
    }
  }

  @override
  void dispose() {
    _text.dispose();
    _focus.dispose();
    super.dispose();
  }

  List<_Option> _suggestions(
    String typed,
    List<Buddy> buddies,
    List<DiveCenter> centers,
  ) {
    final query = typed.trim().toLowerCase();
    if (query.isEmpty) return const [];
    bool matches(String name) => name.toLowerCase().contains(query);
    return [
      ...[
        for (final b in buddies)
          if (matches(b.name)) _Option(_Kind.buddy, b.name, b.id),
        for (final c in centers)
          if (matches(c.name)) _Option(_Kind.center, c.name, c.id),
      ].take(_maxSuggestions),
      _Option(_Kind.typed, typed.trim()),
    ];
  }

  void _pick(_Option option) {
    if (option.kind == _Kind.typed) return;
    widget.onChanged((
      buddyId: option.kind == _Kind.buddy ? option.id : null,
      centerId: option.kind == _Kind.center ? option.id : null,
      name: option.name,
    ));
  }

  @override
  Widget build(BuildContext context) {
    final buddies = ref.watch(allBuddiesProvider).value ?? const <Buddy>[];
    final centers =
        ref.watch(allDiveCentersProvider).value ?? const <DiveCenter>[];
    final value = widget.value;
    if (_isLinked(value)) return _chip(context, value, buddies, centers);
    return LayoutBuilder(
      builder: (context, constraints) => RawAutocomplete<_Option>(
        textEditingController: _text,
        focusNode: _focus,
        displayStringForOption: (o) => o.name,
        optionsBuilder: (typed) => _suggestions(typed.text, buddies, centers),
        onSelected: _pick,
        fieldViewBuilder: (context, controller, focusNode, onSubmitted) =>
            TextField(
              key: const ValueKey('gear-edit-seller'),
              controller: controller,
              focusNode: focusNode,
              textCapitalization: TextCapitalization.words,
              decoration: InputDecoration(
                labelText: context.l10n.attrLabel_retailer,
              ),
              onChanged: (text) =>
                  widget.onChanged((buddyId: null, centerId: null, name: text)),
              // Enter keeps what was typed: submitting the list would link
              // its first suggestion, a buddy the diver never picked.
              onSubmitted: (_) => focusNode.unfocus(),
            ),
        optionsViewBuilder: (context, onSelected, options) => _OptionsList(
          width: constraints.maxWidth,
          options: options.toList(),
          onSelected: onSelected,
        ),
      ),
    );
  }

  Widget _chip(
    BuildContext context,
    GearSeller value,
    List<Buddy> buddies,
    List<DiveCenter> centers,
  ) {
    final l10n = context.l10n;
    final isBuddy = value.buddyId != null;
    // The current name when this profile can open the link; otherwise the
    // name stored with it.
    final name = isBuddy
        ? buddies.where((b) => b.id == value.buddyId).firstOrNull?.name
        : centers.where((c) => c.id == value.centerId).firstOrNull?.name;
    return InputDecorator(
      decoration: InputDecoration(labelText: l10n.attrLabel_retailer),
      child: Align(
        alignment: AlignmentDirectional.centerStart,
        child: InputChip(
          key: const ValueKey('gear-edit-seller-chip'),
          avatar: Icon(_iconFor(isBuddy ? _Kind.buddy : _Kind.center)),
          label: Text(
            name ?? value.name,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
          deleteButtonTooltipMessage: l10n.equipment_seller_clear,
          onDeleted: () =>
              widget.onChanged((buddyId: null, centerId: null, name: '')),
        ),
      ),
    );
  }
}

IconData _iconFor(_Kind kind) => switch (kind) {
  _Kind.buddy => Icons.person_outline,
  _Kind.center => Icons.storefront_outlined,
  _Kind.typed => Icons.edit_outlined,
};

class _OptionsList extends StatelessWidget {
  final double width;
  final List<_Option> options;
  final ValueChanged<_Option> onSelected;

  const _OptionsList({
    required this.width,
    required this.options,
    required this.onSelected,
  });

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final theme = Theme.of(context);
    return Align(
      alignment: AlignmentDirectional.topStart,
      child: Material(
        elevation: 4,
        borderRadius: BorderRadius.circular(8),
        child: ConstrainedBox(
          constraints: BoxConstraints(maxWidth: width, maxHeight: 320),
          child: ListView(
            padding: EdgeInsets.zero,
            shrinkWrap: true,
            children: [
              for (final option in options)
                ListTile(
                  dense: true,
                  leading: Icon(_iconFor(option.kind)),
                  title: Text(
                    option.kind == _Kind.typed
                        ? l10n.equipment_seller_keepTyped(option.name)
                        : option.name,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  trailing: switch (option.kind) {
                    _Kind.buddy => Text(
                      l10n.equipment_seller_kindBuddy,
                      style: theme.textTheme.labelSmall,
                    ),
                    _Kind.center => Text(
                      l10n.equipment_seller_kindDiveCenter,
                      style: theme.textTheme.labelSmall,
                    ),
                    _Kind.typed => null,
                  },
                  onTap: () => onSelected(option),
                ),
            ],
          ),
        ),
      ),
    );
  }
}
