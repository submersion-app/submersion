import 'package:flutter/material.dart';
import 'package:submersion/core/providers/provider.dart';
import 'package:go_router/go_router.dart';

import 'package:submersion/features/equipment/presentation/utils/equipment_row_label.dart';
import 'package:submersion/features/equipment/presentation/utils/equipment_row_labels_of.dart';
import 'package:submersion/l10n/l10n_extension.dart';
import 'package:submersion/features/divers/presentation/providers/diver_providers.dart';
import 'package:submersion/features/equipment/domain/entities/equipment_set.dart';
import 'package:submersion/features/equipment/domain/entities/equipment_item.dart';
import 'package:submersion/features/equipment/presentation/providers/equipment_providers.dart';
import 'package:submersion/features/equipment/presentation/providers/equipment_set_providers.dart';
import 'package:submersion/features/equipment/domain/entities/equipment_set_geofence.dart';
import 'package:submersion/features/equipment/presentation/utils/equipment_enum_display.dart';
import 'package:submersion/features/equipment/domain/services/equipment_arranger.dart';
import 'package:submersion/features/equipment/presentation/providers/equipment_arrangement_provider.dart';
import 'package:submersion/features/equipment/presentation/widgets/foldable_type_group_rows.dart';
import 'package:submersion/features/equipment/figure/domain/figure_composer.dart';
import 'package:submersion/features/equipment/figure/domain/figure_inputs.dart';
import 'package:submersion/features/equipment/figure/presentation/figure_model_memo.dart';
import 'package:submersion/features/equipment/figure/presentation/figure_number_badge.dart';
import 'package:submersion/features/equipment/figure/presentation/figure_selection.dart';
import 'package:submersion/features/equipment/figure/presentation/gear_figure.dart';
import 'package:submersion/features/equipment/presentation/helpers/equipment_set_history_save.dart';
import 'package:submersion/features/equipment/presentation/helpers/gear_expansion.dart';
import 'package:submersion/features/equipment/domain/services/equipment_set_clone_seed.dart';
import 'package:submersion/features/equipment/presentation/helpers/equipment_set_form_values.dart';
import 'package:submersion/features/equipment/presentation/providers/equipment_clone_providers.dart';
import 'package:submersion/features/equipment/presentation/providers/equipment_component_providers.dart';
import 'package:submersion/features/equipment/presentation/widgets/set_bundle_sections.dart';
import 'package:submersion/features/equipment/presentation/widgets/set_equipment_checkbox_row.dart';
import 'package:submersion/features/equipment/presentation/widgets/set_geofences_editor.dart';
import 'package:submersion/features/equipment/presentation/widgets/unsaved_changes_scope.dart';
import 'package:submersion/shared/widgets/app_bar_text_action.dart';
import 'package:submersion/shared/widgets/markdown_notes/markdown_notes_field.dart';

class EquipmentSetEditPage extends ConsumerStatefulWidget {
  final String? setId;

  /// For a new set: the set it is cloned from (issue #2156). The form starts
  /// from [equipmentSetCloneSeed] of it, and a save pops with the new id.
  final String? cloneFromId;

  const EquipmentSetEditPage({super.key, this.setId, this.cloneFromId});

  bool get isEditing => setId != null;

  bool get isCloning => setId == null && cloneFromId != null;

  @override
  ConsumerState<EquipmentSetEditPage> createState() =>
      _EquipmentSetEditPageState();
}

class _EquipmentSetEditPageState extends ConsumerState<EquipmentSetEditPage>
    with
        FigureSelection<EquipmentSetEditPage>,
        FoldableTypeGroupsState<EquipmentSetEditPage> {
  final _formKey = GlobalKey<FormState>();

  /// The live figure's model, reused while the ticked items are unchanged.
  final _memo = FigureModelMemo();
  final _nameController = TextEditingController();
  final _descriptionController = TextEditingController();

  final Set<String> _selectedEquipmentIds = {};
  bool _isLoading = false;
  bool _isInitialized = false;
  bool _isDefault = false;
  bool _autoApplyOnComputerImport = false;
  bool _showFigure = true;

  /// Whether the list also shows the parts of assemblies it lists (#2514).
  /// Ticked rows, and rows touched here, always show, so an untick can be
  /// undone in place.
  bool _showParts = false;
  Set<String> _touchedIds = const {};
  List<EquipmentSetGeofence> _geofences = [];

  /// What the set carries besides its own gear (issue #4525).
  SetBundleListValues _lists = SetBundleListValues.empty;

  /// The form as it opened, to tell whether Back would lose anything. Null
  /// for a clone: the copy itself is unsaved, so Back always asks.
  EquipmentSetFormValues? _opened = EquipmentSetFormValues.blank;

  /// Whether the Back guard was last built holding Back. Typing does not
  /// rebuild the page, so the text fields rebuild it when this goes stale.
  bool _guarding = false;

  /// True while the form is being filled in, so that is not taken for typing.
  bool _seeding = false;

  /// The diver a clone was seeded for: after a profile switch it is not theirs.
  String? _cloneDiverId;

  EquipmentSetFormValues get _values => EquipmentSetFormValues(
    name: _nameController.text,
    description: _descriptionController.text,
    equipmentIds: _selectedEquipmentIds,
    isDefault: _isDefault,
    autoApplyOnComputerImport: _autoApplyOnComputerImport,
    showFigure: _showFigure,
    geofences: _geofences,
    lists: _lists,
  );

  bool get _hasChanges => _opened != _values;

  @override
  void initState() {
    super.initState();
    _nameController.addListener(_onTextChanged);
    _descriptionController.addListener(_onTextChanged);
  }

  void _onTextChanged() {
    if (!_seeding && mounted && _hasChanges != _guarding) setState(() {});
  }

  @override
  void dispose() {
    _nameController.dispose();
    _descriptionController.dispose();
    super.dispose();
  }

  void _initializeFromClone(EquipmentSet source) {
    // The owner the source was authorized for, not a second diver reading.
    final active = ref.read(validatedCurrentDiverIdProvider).valueOrNull;
    _cloneDiverId = active == null ? null : source.diverId;
    _initializeFromSet(
      equipmentSetCloneSeed(
        source,
        copyName: context.l10n.equipment_clone_nameCopy,
      ),
    );
    _opened = null;
  }

  void _initializeFromSet(EquipmentSet set) {
    if (_isInitialized) return;
    _isInitialized = true;
    _opened = EquipmentSetFormValues.of(set);

    _seeding = true;
    _nameController.text = set.name;
    _descriptionController.text = set.description;
    _seeding = false;
    _selectedEquipmentIds.addAll(set.equipmentIds);
    _isDefault = set.isDefault;
    _autoApplyOnComputerImport = set.autoApplyOnComputerImport;
    _showFigure = set.showFigure;
    _geofences = List.of(set.geofences);
    _lists = SetBundleListValues.of(set);
  }

  /// Drops selections whose equipment has been deleted since the form opened.
  ///
  /// Gear deleted while the page is open (a sync, the equipment tab) would
  /// stay selected with no checkbox, and the save would re-insert a dangling
  /// key (#819). An id the fresh [set] still lists is kept: retired gear and
  /// gear [allEquipmentProvider] does not return are still members.
  ///
  /// A clone ([set] null) keeps only gear the diver can see, so no member
  /// whose share was removed (#2046) is a row they cannot see or untick.
  void _pruneDeletedSelections(
    EquipmentSet? set,
    List<EquipmentItem>? everyEquipment,
  ) {
    if (everyEquipment == null) return;
    final known = {...everyEquipment.map((e) => e.id), ...?set?.equipmentIds};
    _selectedEquipmentIds.retainWhere(known.contains);
    // The diver did not drop these, so Back must not ask about them.
    _opened = _opened?.retainingEquipment(known.contains);
  }

  @override
  Widget build(BuildContext context) {
    final allEquipmentAsync = ref.watch(activeEquipmentProvider);
    // Existence check for _pruneDeletedSelections. Deliberately not
    // activeEquipmentProvider: retired gear still belongs to a set, it just
    // gets no checkbox.
    final everyEquipment = ref.watch(allEquipmentProvider).valueOrNull;

    // The form over [existing] (null for a new set or a clone), with gear
    // deleted meanwhile dropped from the selection.
    Widget form(EquipmentSet? existing) {
      _pruneDeletedSelections(existing, everyEquipment);
      return _buildForm(context, allEquipmentAsync, existing);
    }

    // A seeded clone stops watching its source (deleting it must not discard
    // the clone), but it stays the diver's it was seeded for.
    if (widget.isCloning && _isInitialized) {
      final diverId = ref.watch(validatedCurrentDiverIdProvider).valueOrNull;
      return diverId == _cloneDiverId ? form(null) : _notFound(context);
    }

    final loadId = widget.setId ?? widget.cloneFromId;
    if (loadId != null) {
      final setAsync = ref.watch(
        widget.isCloning
            ? equipmentSetCloneSourceProvider(loadId)
            : equipmentSetProvider(loadId),
      );
      return setAsync.when(
        data: (set) {
          if (set == null) return _notFound(context);
          if (widget.isCloning) {
            _initializeFromClone(set);
            return form(null);
          }
          _initializeFromSet(set);
          return form(set);
        },
        loading: () => Scaffold(
          appBar: AppBar(
            title: Text(context.l10n.equipment_setEdit_loadingTitle),
          ),
          body: const Center(child: CircularProgressIndicator()),
        ),
        error: (error, _) => Scaffold(
          appBar: AppBar(
            title: Text(context.l10n.equipment_setEdit_errorTitle),
          ),
          body: Center(
            child: Text(context.l10n.equipment_setEdit_errorMessage('$error')),
          ),
        ),
      );
    }

    return _buildForm(context, allEquipmentAsync, null);
  }

  Widget _notFound(BuildContext context) => Scaffold(
    appBar: AppBar(title: Text(context.l10n.equipment_setEdit_notFoundTitle)),
    body: Center(child: Text(context.l10n.equipment_setEdit_notFoundMessage)),
  );

  Widget _buildForm(
    BuildContext context,
    AsyncValue<List<EquipmentItem>> equipmentAsync,
    EquipmentSet? existingSet,
  ) {
    // Back asks before unsaved changes are lost, in every mode, as the
    // equipment form does (issue #2156).
    _guarding = _hasChanges;
    return UnsavedChangesScope(
      hasChanges: _guarding,
      child: Scaffold(
        appBar: AppBar(
          title: Text(
            widget.isEditing
                ? context.l10n.equipment_setEdit_appBar_editTitle
                : widget.isCloning
                ? context.l10n.equipment_setEdit_appBar_cloneTitle
                : context.l10n.equipment_setEdit_appBar_newTitle,
          ),
          // Save sits top right, where the gear editor has it (issue #2266),
          // and is the form's only save action (issue #3174).
          actions: [
            Tooltip(
              message: widget.isEditing
                  ? context.l10n.equipment_setEdit_saveTooltip_edit
                  : context.l10n.equipment_setEdit_saveTooltip_new,
              child: AppBarTextAction(
                label: context.l10n.common_action_save,
                onPressed: _isLoading ? null : () => _saveSet(existingSet),
                busy: _isLoading,
              ),
            ),
          ],
        ),
        body: Form(
          key: _formKey,
          child: _formScroll(
            children: [
              // Name
              TextFormField(
                controller: _nameController,
                decoration: InputDecoration(
                  labelText: context.l10n.equipment_setEdit_nameLabel,
                  prefixIcon: const Icon(Icons.folder),
                  hintText: context.l10n.equipment_setEdit_nameHint,
                ),
                validator: (value) {
                  if (value == null || value.isEmpty) {
                    return context.l10n.equipment_setEdit_nameValidation;
                  }
                  return null;
                },
              ),
              const SizedBox(height: 16),

              // Description
              MarkdownNotesField(
                controller: _descriptionController,
                decoration: InputDecoration(
                  labelText: context.l10n.equipment_setEdit_descriptionLabel,
                  prefixIcon: const Icon(Icons.description),
                  hintText: context.l10n.equipment_setEdit_descriptionHint,
                ),
                maxLines: 2,
              ),
              const SizedBox(height: 24),

              // Default set
              SwitchListTile(
                contentPadding: EdgeInsets.zero,
                title: Text(context.l10n.equipment_setEdit_defaultSwitch_title),
                subtitle: Text(
                  context.l10n.equipment_setEdit_defaultSwitch_subtitle,
                ),
                value: _isDefault,
                onChanged: (v) => setState(() => _isDefault = v),
              ),
              const SizedBox(height: 8),

              // Auto-apply when this set's computer is imported (issue #1020)
              SwitchListTile(
                contentPadding: EdgeInsets.zero,
                title: Text(
                  context.l10n.equipment_setEdit_computerAutoApplySwitch_title,
                ),
                subtitle: Text(
                  context
                      .l10n
                      .equipment_setEdit_computerAutoApplySwitch_subtitle,
                ),
                value: _autoApplyOnComputerImport,
                onChanged: (v) =>
                    setState(() => _autoApplyOnComputerImport = v),
              ),
              const SizedBox(height: 8),

              // The diver figure on the set page (issue #2326), on by default.
              SwitchListTile(
                contentPadding: EdgeInsets.zero,
                title: Text(context.l10n.equipment_setEdit_figureSwitch_title),
                subtitle: Text(
                  context.l10n.equipment_setEdit_figureSwitch_subtitle,
                ),
                value: _showFigure,
                onChanged: (v) => setState(() => _showFigure = v),
              ),
              const SizedBox(height: 16),

              SetGeofencesEditor(
                fences: _geofences,
                setId: widget.setId ?? '',
                onChanged: (fences) => setState(() => _geofences = fences),
              ),
              const SizedBox(height: 24),

              SetBundleSections(
                setId: widget.setId ?? '',
                diverId:
                    existingSet?.diverId ??
                    ref.watch(validatedCurrentDiverIdProvider).valueOrNull,
                ownGearIds: _selectedEquipmentIds,
                values: _lists,
                onChanged: (lists) => setState(() => _lists = lists),
              ),
              const SizedBox(height: 24),

              // Equipment selection
              Text(
                context.l10n.equipment_setEdit_selectEquipmentTitle,
                style: Theme.of(context).textTheme.titleMedium,
              ),
              const SizedBox(height: 8),
              Text(
                context.l10n.equipment_setEdit_selectEquipmentSubtitle,
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: Theme.of(context).colorScheme.onSurfaceVariant,
                ),
              ),
              const SizedBox(height: 16),

              equipmentAsync.when(
                data: (equipment) {
                  if (equipment.isEmpty) {
                    return Card(
                      child: Padding(
                        padding: const EdgeInsets.all(32),
                        child: Center(
                          child: Column(
                            children: [
                              ExcludeSemantics(
                                child: Icon(
                                  Icons.backpack_outlined,
                                  size: 48,
                                  color: Theme.of(context)
                                      .colorScheme
                                      .onSurfaceVariant
                                      .withValues(alpha: 0.5),
                                ),
                              ),
                              const SizedBox(height: 8),
                              Text(
                                context
                                    .l10n
                                    .equipment_setEdit_noEquipmentAvailable,
                                style: Theme.of(context).textTheme.bodyMedium
                                    ?.copyWith(
                                      color: Theme.of(
                                        context,
                                      ).colorScheme.onSurfaceVariant,
                                    ),
                              ),
                              const SizedBox(height: 8),
                              Text(
                                context
                                    .l10n
                                    .equipment_setEdit_addEquipmentFirst,
                                style: Theme.of(context).textTheme.bodySmall
                                    ?.copyWith(
                                      color: Theme.of(
                                        context,
                                      ).colorScheme.onSurfaceVariant,
                                    ),
                                textAlign: TextAlign.center,
                              ),
                            ],
                          ),
                        ),
                      ),
                    );
                  }

                  // This grouped by type but ordered neither the groups nor the
                  // items inside them, so the picker had the same unspecified
                  // order the dive surfaces did (#1486, #1576). Selection is
                  // held in a Set of ids, so reordering the render cannot
                  // disturb what is ticked.
                  final componentsAsync = ref.watch(
                    equipmentComponentsIndexProvider,
                  );
                  final components = componentsAsync.hasError
                      ? ComponentsIndex.empty
                      : componentsAsync.value;
                  // A listed assembly brings its parts (#2514): hide each one
                  // behind a switch unless ticked or touched.
                  final partIds = assemblyPartsAmong(
                    components ?? ComponentsIndex.empty,
                    equipment,
                  ).difference({..._selectedEquipmentIds, ..._touchedIds});
                  final listed = _showParts
                      ? equipment
                      : [
                          for (final e in equipment)
                            if (!partIds.contains(e.id)) e,
                        ];
                  final groups = arrangeEquipment(
                    listed,
                    ref.watch(equipmentArrangementProvider),
                    typeLabel: (type) => type.localizedName(context.l10n),
                  );
                  // Labelled as one list, so identical items read differently
                  // from each other (#1549).
                  final labels = equipmentRowLabelsOf(context, ref, listed);
                  // Folding (issue #3364): once the set's members are known,
                  // groups holding one start open and the rest closed.
                  final typeGroups = [
                    for (final group in groups) (group.type, group.items),
                  ];
                  ensureOpenTypeGroups(
                    typeGroups,
                    _selectedEquipmentIds,
                    ready: !widget.isEditing || _isInitialized,
                  );

                  // Members the diver can no longer see (a share was removed,
                  // issue #2046) stay selected, so saving keeps them; they are
                  // listed without a checkbox and marked.
                  final visibleIds = ref
                      .watch(allEquipmentProvider)
                      .value
                      ?.map((e) => e.id)
                      .toSet();
                  final unshared = unsharedSetMembers(existingSet, visibleIds);

                  // The live figure (issue #2326): the ticked items that have
                  // a row here, in the order the page lists them, so its
                  // numbers run down the rows. A retired member has no row,
                  // so it is not drawn. Parts wait for the components index,
                  // as on the set page.
                  final ordered = [
                    for (final group in groups)
                      for (final item in group.items)
                        if (_selectedEquipmentIds.contains(item.id)) item,
                  ];
                  final model =
                      _showFigure && components != null && ordered.isNotEmpty
                      ? _memo.of(
                          (
                            equipment,
                            [for (final item in ordered) item.id].join('|'),
                            components,
                            ref.watch(equipmentArrangementProvider),
                            Localizations.localeOf(context),
                          ),
                          () => composeFigure(
                            figureInputsFromItems(
                              ordered,
                              components: components,
                            ),
                          ),
                        )
                      : null;
                  final numberById = model == null
                      ? const <String, int>{}
                      : {for (final p in model.numbered) p.item.id: p.number};
                  // The widest badge the rows will show, at the diver's text
                  // size: the highest number takes the most digits.
                  final badgeSlot = model == null
                      ? null
                      : FigureNumberBadge.widthFor(
                          model.itemCount,
                          24,
                          textScaler: MediaQuery.textScalerOf(context),
                        );
                  return Column(
                    children: [
                      if (model != null) ...[
                        Card(
                          key: figureKey,
                          child: Padding(
                            padding: const EdgeInsets.all(16),
                            // Typing a name does not rebuild the page, so the
                            // summary listens to the field itself.
                            child: ValueListenableBuilder<TextEditingValue>(
                              valueListenable: _nameController,
                              builder: (context, value, _) {
                                final name = value.text.trim();
                                return GearFigure(
                                  model: model,
                                  title: name.isEmpty
                                      ? context
                                            .l10n
                                            .equipment_setEdit_appBar_newTitle
                                      : name,
                                  selectedItemId: selectedFigureItemId,
                                  selectionSerial: figureSelectionSerial,
                                  onItemTap: (placed) =>
                                      selectFigureItem(placed.item.id),
                                );
                              },
                            ),
                          ),
                        ),
                        const SizedBox(height: 8),
                      ],
                      if (_showParts || partIds.isNotEmpty)
                        SwitchListTile(
                          key: const Key('set-edit-show-assembly-parts'),
                          dense: true,
                          contentPadding: EdgeInsets.zero,
                          title: Text(
                            context
                                .l10n
                                .diveLog_equipmentPicker_showAssemblyParts,
                          ),
                          value: _showParts,
                          onChanged: (v) => setState(() => _showParts = v),
                        ),
                      if (unshared.isNotEmpty)
                        Card(
                          margin: const EdgeInsets.only(bottom: 8),
                          child: Column(
                            children: [
                              for (final item in unshared)
                                ListTile(
                                  enabled: false,
                                  title: Text(item.name),
                                  subtitle: Text(
                                    context.l10n.equipment_set_noLongerShared,
                                  ),
                                ),
                            ],
                          ),
                        ),
                      ...foldableTypeGroupRows(
                        context,
                        groups: typeGroups,
                        open: openTypeGroups,
                        ticked: _selectedEquipmentIds,
                        onToggle: toggleTypeGroup,
                        rowBuilder: (item) => _buildEquipmentCheckbox(
                          context,
                          item,
                          labels,
                          numberById[item.id],
                          badgeSlot: badgeSlot,
                        ),
                      ),
                    ],
                  );
                },
                loading: () => const Center(child: CircularProgressIndicator()),
                error: (error, _) => Center(
                  child: Text(
                    context.l10n.equipment_setEdit_errorMessage('$error'),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  /// The form's scroll view: every row is built while the figure shows, so a
  /// figure tap can scroll to any (#2326); off, it stays a lazy list.
  Widget _formScroll({required List<Widget> children}) => _showFigure
      ? SingleChildScrollView(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: children,
          ),
        )
      : ListView(padding: const EdgeInsets.all(16), children: children);

  /// One picker row; see [SetEquipmentCheckboxRow]. Null [number] when the
  /// figure is off or the item is not on it.
  Widget _buildEquipmentCheckbox(
    BuildContext context,
    EquipmentItem item,
    Map<String, EquipmentRowLabel> labels,
    int? number, {
    double? badgeSlot,
  }) => KeyedSubtree(
    key: figureRowKey(item.id),
    child: SetEquipmentCheckboxRow(
      item: item,
      detail: labels[item.id]?.subtitle,
      isSelected: _selectedEquipmentIds.contains(item.id),
      number: number,
      badgeSlot: badgeSlot,
      flashing: number != null && item.id == selectedFigureItemId,
      onBadgeTap: () => selectFigureItem(item.id, revealFigure: true),
      onChanged: (value) => setState(() {
        if (value == true) {
          _selectedEquipmentIds.add(item.id);
        } else {
          _selectedEquipmentIds.remove(item.id);
        }
        _touchedIds = {..._touchedIds, item.id};
      }),
    ),
  );

  Future<void> _saveSet(EquipmentSet? existingSet) async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _isLoading = true);
    try {
      final diverId =
          existingSet?.diverId ??
          await ref.read(validatedCurrentDiverIdProvider.future);
      // Pruned here if Save beat the gear list. A diver switched away during
      // that wait is not saved: addSet would give the copy to the new diver.
      if (widget.isCloning) {
        final every = await ref.read(allEquipmentProvider.future);
        if (await ref.read(validatedCurrentDiverIdProvider.future) !=
            _cloneDiverId) {
          return;
        }
        _pruneDeletedSelections(null, every);
      }

      final set = EquipmentSet(
        id: widget.setId ?? '',
        diverId: diverId,
        name: _nameController.text.trim(),
        description: _descriptionController.text.trim(),
        equipmentIds: _selectedEquipmentIds.toList(),
        includedSetIds: _lists.includedSetIds,
        weightPresetIds: _lists.weightPresetIds,
        cylinderConfigIds: _lists.cylinderConfigIds,
        autoApplyOnComputerImport: _autoApplyOnComputerImport,
        showFigure: _showFigure,
        createdAt: existingSet?.createdAt ?? DateTime.now(),
        updatedAt: DateTime.now(),
      );

      final notifier = ref.read(equipmentSetListNotifierProvider.notifier);
      final String savedId;
      Future<void> Function()? replay;
      if (widget.isEditing) {
        // A cancel in the dives question (issue #4283) saves nothing.
        if (!mounted) return;
        replay = await saveSetWithHistory(context, ref, set, existingSet!);
        if (replay == null) return;
        savedId = set.id;
      } else {
        final created = await notifier.addSet(set);
        savedId = created.id;
      }

      await saveThenReplay(() async {
        // Default flag (per-diver mutual exclusion in the repository). Off
        // clears it, so nothing auto-applies until one is set again.
        if (_isDefault) {
          await notifier.setAsDefault(savedId);
        } else if (existingSet?.isDefault ?? false) {
          await notifier.clearDefault(savedId);
        }

        // Reconcile geofences: remove dropped, add/update the rest.
        final repo = ref.read(equipmentSetRepositoryProvider);
        final existingGeofences = await repo.getGeofencesForSet(savedId);
        final keptIds = _geofences.map((g) => g.id).toSet();
        for (final old in existingGeofences) {
          if (!keptIds.contains(old.id)) {
            await notifier.removeGeofence(savedId, old.id);
          }
        }
        for (final g in _geofences) {
          final fence = g.copyWith(setId: savedId);
          if (existingGeofences.any((e) => e.id == g.id)) {
            await notifier.updateGeofence(fence);
          } else {
            await notifier.addGeofence(fence);
          }
        }
      }, replay);

      if (mounted) {
        final messenger = ScaffoldMessenger.of(context);
        final saved = widget.isEditing
            ? context.l10n.equipment_setEdit_snackbar_updated
            : widget.isCloning
            ? context.l10n.equipment_setEdit_snackbar_cloned
            : context.l10n.equipment_setEdit_snackbar_created;
        // A clone hands its id back, so the set page can show the clone in
        // place of its source (issue #2156).
        context.pop(widget.isCloning ? savedId : null);
        messenger.showSnackBar(SnackBar(content: Text(saved)));
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(context.l10n.equipment_setEdit_snackbar_error('$e')),
            backgroundColor: Theme.of(context).colorScheme.error,
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }
}
