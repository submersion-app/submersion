import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import 'package:submersion/core/constants/enums.dart';
import 'package:submersion/core/providers/provider.dart';
import 'package:submersion/core/utils/currency.dart';
import 'package:submersion/core/utils/number_input.dart';
import 'package:submersion/core/utils/unit_formatter.dart';
import 'package:submersion/features/equipment/domain/entities/service_kind.dart';
import 'package:submersion/features/equipment/domain/entities/service_record.dart';
import 'package:submersion/features/equipment/domain/entities/service_schedule.dart';
import 'package:submersion/features/equipment/domain/services/default_service_cost_resolver.dart';
import 'package:submersion/features/equipment/presentation/providers/equipment_providers.dart';
import 'package:submersion/features/equipment/presentation/utils/service_category_label.dart';
import 'package:submersion/features/settings/presentation/providers/settings_providers.dart';
import 'package:submersion/l10n/l10n_extension.dart';
import 'package:submersion/shared/widgets/app_date_picker.dart';

/// Service Record Dialog for Add/Edit
class ServiceRecordDialog extends ConsumerStatefulWidget {
  final String equipmentId;
  final ServiceRecord? existingRecord;

  /// Pre-selects which service clock this record fulfills.
  final String? serviceKindId;
  final Future<void> Function(ServiceRecord) onSave;

  const ServiceRecordDialog({
    super.key,
    required this.equipmentId,
    this.existingRecord,
    this.serviceKindId,
    required this.onSave,
  });

  @override
  ConsumerState<ServiceRecordDialog> createState() =>
      _ServiceRecordDialogState();
}

class _ServiceRecordDialogState extends ConsumerState<ServiceRecordDialog> {
  final _formKey = GlobalKey<FormState>();
  late ServiceCategory _serviceCategory;
  late DateTime _serviceDate;
  final _providerController = TextEditingController();
  final _costController = TextEditingController();
  final _currencyController = TextEditingController();
  final _notesController = TextEditingController();
  DateTime? _nextServiceDue;
  String? _serviceKindId;
  bool _isSaving = false;

  /// Set as soon as the diver types in the cost field. Once set, the default
  /// price never writes over it again, including when the clock selection
  /// changes and re-resolves.
  bool _costTouched = false;

  /// The same guard for the currency, tracked separately: the two fields are
  /// edited independently, so typing a price must not forfeit a currency the
  /// diver picked, and vice versa.
  bool _currencyTouched = false;

  /// The same guard for the category: it is prefilled from the chosen service
  /// type, so without this flag changing the type would silently overwrite a
  /// category the diver had already picked.
  bool _categoryTouched = false;

  /// The code this dialog opened with: the record's stored currency when
  /// editing, the diver's default for a new record. Currency is free text, so
  /// this can be outside the presets; keeping it lets the dropdown offer it.
  String _initialCurrencyCode = '';

  bool get isEditing => widget.existingRecord != null;

  @override
  void initState() {
    super.initState();
    if (isEditing) {
      final record = widget.existingRecord!;
      _serviceCategory = record.serviceCategory;
      _serviceDate = record.serviceDate;
      _providerController.text = record.provider ?? '';
      // Seeded in the diver's locale to match how the field is read back;
      // see formatDecimalForInput for why the two halves must agree.
      final cost = record.cost;
      _costController.text = cost == null ? '' : formatDecimalForInput(cost);
      _initialCurrencyCode = record.currency;
      _notesController.text = record.notes;
      _nextServiceDue = record.nextServiceDue;
      _serviceKindId = record.serviceKindId;
    } else {
      _serviceCategory = ServiceCategory.annual;
      _serviceDate = DateTime.now();
      _serviceKindId = widget.serviceKindId;
      _initialCurrencyCode = _fallbackCurrencyCode();
    }
    _currencyController.text = _initialCurrencyCode;
  }

  /// The code to store when the currency field is left blank: the diver's
  /// default, or USD if that is somehow unset (the column is NOT NULL).
  String _fallbackCurrencyCode() {
    final code = ref.read(defaultCurrencyProvider).trim().toUpperCase();
    return code.isEmpty ? 'USD' : code;
  }

  @override
  void dispose() {
    _providerController.dispose();
    _costController.dispose();
    _currencyController.dispose();
    _notesController.dispose();
    super.dispose();
  }

  /// Fills the cost, currency and category fields from their defaults.
  ///
  /// A convenience, not a binding value: it only ever fills an untouched
  /// field on a NEW record. Editing must never re-prefill, or a cost the
  /// diver deliberately cleared would silently come back.
  ///
  /// This cannot live in initState, because the kinds and schedules arrive
  /// from FutureProviders that have not resolved when the dialog is built.
  void _maybePrefillFromKind(
    List<ServiceKind> kinds,
    List<ServiceSchedule> schedules,
  ) {
    if (isEditing) return;
    // Guarded on its own flag for the same reason as the currency below: this
    // runs on every build, so a category the diver picked must survive any
    // later setState, including changing the service type.
    if (!_categoryTouched) {
      final category = resolveDefaultServiceCategory(
        serviceKindId: _serviceKindId,
        kinds: kinds,
      );
      if (category != null && category != _serviceCategory) {
        _serviceCategory = category;
      }
    }
    final resolved = resolveDefaultServiceCost(
      serviceKindId: _serviceKindId,
      schedules: schedules,
      kinds: kinds,
    );
    if (!_costTouched) {
      final text = resolved.cost == null
          ? ''
          : formatDecimalForInput(resolved.cost!);
      if (_costController.text != text) _costController.text = text;
    }
    // Guarded on its own flag: this runs on every build, so without it any
    // later setState (changing the type, date or clock) would silently revert
    // a currency the diver had already chosen.
    if (!_currencyTouched && resolved.currency != null) {
      if (_currencyController.text != resolved.currency) {
        _currencyController.text = resolved.currency!;
      }
    }
  }

  /// Codes the currency dropdown offers.
  ///
  /// [currencyCodesWith] leads with one code outside the presets; the live
  /// value is added too, because a default resolved from a kind or schedule
  /// can be an ISO code the presets do not carry, and it must remain visible
  /// and re-selectable rather than silently missing from the list.
  List<String> _currencyOptions() {
    final codes = currencyCodesWith(_initialCurrencyCode);
    final live = _currencyController.text.trim().toUpperCase();
    if (live.isEmpty || codes.contains(live)) return codes;
    return [live, ...codes];
  }

  @override
  Widget build(BuildContext context) {
    final settings = ref.watch(settingsProvider);
    final units = UnitFormatter(settings);

    // Resolved every build while the field is untouched, so switching the
    // clock re-prices the record.
    _maybePrefillFromKind(
      ref.watch(serviceKindsProvider).valueOrNull ?? const <ServiceKind>[],
      ref
              .watch(serviceSchedulesForEquipmentProvider(widget.equipmentId))
              .valueOrNull ??
          const <ServiceSchedule>[],
    );

    return AlertDialog(
      title: Text(
        isEditing
            ? context.l10n.equipment_serviceDialog_editTitle
            : context.l10n.equipment_serviceDialog_addTitle,
      ),
      content: SizedBox(
        width: double.maxFinite,
        child: Form(
          key: _formKey,
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                // The service type this record fulfills, which is also the
                // clock it resets. Leads the form: it is the one thing the
                // diver must choose, and the category below follows from it.
                ref
                    .watch(serviceKindsProvider)
                    .maybeWhen(
                      data: (kinds) => Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          DropdownButtonFormField<String?>(
                            key: const Key('service-record-service-type'),
                            initialValue:
                                kinds.any((k) => k.id == _serviceKindId)
                                ? _serviceKindId
                                : null,
                            decoration: InputDecoration(
                              labelText: context
                                  .l10n
                                  .equipment_serviceDialog_serviceTypeLabel,
                              helperText: context
                                  .l10n
                                  .equipment_serviceDialog_serviceTypeHelper,
                              helperMaxLines: 2,
                              prefixIcon: const Icon(Icons.build),
                            ),
                            // Required when creating, optional when editing:
                            // forcing a pick on an existing record would
                            // attach a clock and move its anchor.
                            validator: (value) => !isEditing && value == null
                                ? context
                                      .l10n
                                      .equipment_serviceDialog_serviceTypeRequired
                                : null,
                            items: [
                              DropdownMenuItem<String?>(
                                value: null,
                                child: Text(
                                  context
                                      .l10n
                                      .equipment_serviceDialog_serviceTypeNotSet,
                                ),
                              ),
                              for (final kind in kinds)
                                DropdownMenuItem<String?>(
                                  value: kind.id,
                                  child: Text(kind.name),
                                ),
                            ],
                            onChanged: (value) {
                              setState(() => _serviceKindId = value);
                            },
                          ),
                          Align(
                            alignment: AlignmentDirectional.centerEnd,
                            child: TextButton(
                              onPressed: () =>
                                  context.pushNamed('manageServiceTypes'),
                              child: Text(
                                context
                                    .l10n
                                    .equipment_serviceDialog_manageServiceTypes,
                              ),
                            ),
                          ),
                          const SizedBox(height: 8),
                        ],
                      ),
                      orElse: () => const SizedBox.shrink(),
                    ),

                // What kind of work it was. Secondary to the service type
                // above, and prefilled from it.
                DropdownButtonFormField<ServiceCategory>(
                  key: const Key('service-record-category'),
                  initialValue: _serviceCategory,
                  decoration: InputDecoration(
                    labelText:
                        context.l10n.equipment_serviceDialog_categoryLabel,
                    helperText:
                        context.l10n.equipment_serviceDialog_categoryHelper,
                    prefixIcon: const Icon(Icons.category_outlined),
                  ),
                  items: ServiceCategory.values.map((category) {
                    return DropdownMenuItem(
                      value: category,
                      child: Text(category.label(context.l10n)),
                    );
                  }).toList(),
                  onChanged: (value) {
                    if (value != null) {
                      _categoryTouched = true;
                      setState(() => _serviceCategory = value);
                    }
                  },
                ),
                const SizedBox(height: 16),

                // Service date picker
                Semantics(
                  button: true,
                  label: context
                      .l10n
                      .equipment_serviceDialog_serviceDateSemanticLabel,
                  child: InkWell(
                    onTap: () => _pickServiceDate(),
                    child: InputDecorator(
                      decoration: InputDecoration(
                        labelText: context
                            .l10n
                            .equipment_serviceDialog_serviceDateLabel,
                        prefixIcon: const Icon(Icons.calendar_today),
                      ),
                      child: Text(units.formatDate(_serviceDate)),
                    ),
                  ),
                ),
                const SizedBox(height: 16),

                // Provider field
                TextFormField(
                  key: const Key('service-record-provider'),
                  controller: _providerController,
                  decoration: InputDecoration(
                    labelText:
                        context.l10n.equipment_serviceDialog_providerLabel,
                    prefixIcon: const Icon(Icons.store),
                    hintText: context.l10n.equipment_serviceDialog_providerHint,
                  ),
                ),
                const SizedBox(height: 16),

                // Cost field, with the currency it is priced in.
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(
                      flex: 2,
                      // Rebuild the cost field when the currency changes so
                      // its prefix shows the right symbol (EUR -> €, ...).
                      child: ValueListenableBuilder<TextEditingValue>(
                        valueListenable: _currencyController,
                        builder: (context, value, _) {
                          final symbol = currencySymbol(value.text);
                          return TextFormField(
                            key: const Key('service-record-cost'),
                            controller: _costController,
                            onChanged: (_) => _costTouched = true,
                            decoration: InputDecoration(
                              labelText: context
                                  .l10n
                                  .equipment_serviceDialog_costLabel,
                              prefixText: symbol.isEmpty ? null : '$symbol ',
                              hintText:
                                  context.l10n.equipment_serviceDialog_costHint,
                            ),
                            keyboardType: const TextInputType.numberWithOptions(
                              decimal: true,
                            ),
                            validator: (value) {
                              if (value != null && value.isNotEmpty) {
                                final parsed = parseUserDecimal(value);
                                if (parsed == null || parsed < 0) {
                                  return context
                                      .l10n
                                      .equipment_serviceDialog_costValidation;
                                }
                              }
                              return null;
                            },
                          );
                        },
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      // Editable dropdown: common currencies as presets, but
                      // any ISO code can still be typed. The stored code leads
                      // the list when it is outside the presets.
                      child: DropdownMenu<String>(
                        controller: _currencyController,
                        expandedInsets: EdgeInsets.zero,
                        requestFocusOnTap: true,
                        enableFilter: true,
                        label: Text(
                          context.l10n.equipment_serviceDialog_currencyLabel,
                        ),
                        onSelected: (_) => _currencyTouched = true,
                        dropdownMenuEntries: [
                          for (final code in _currencyOptions())
                            DropdownMenuEntry(
                              value: code,
                              label: code,
                              leadingIcon: SizedBox(
                                width: 28,
                                child: Center(
                                  child: Text(currencySymbol(code)),
                                ),
                              ),
                            ),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),

                // Next service due date picker
                Semantics(
                  button: true,
                  label: context
                      .l10n
                      .equipment_serviceDialog_nextServiceDueSemanticLabel,
                  child: InkWell(
                    onTap: () => _pickNextServiceDate(),
                    child: InputDecorator(
                      decoration: InputDecoration(
                        labelText: context
                            .l10n
                            .equipment_serviceDialog_nextServiceDueLabel,
                        prefixIcon: const Icon(Icons.event),
                        suffixIcon: _nextServiceDue != null
                            ? IconButton(
                                icon: const Icon(Icons.clear),
                                tooltip: context
                                    .l10n
                                    .equipment_serviceDialog_clearNextServiceDateTooltip,
                                onPressed: () =>
                                    setState(() => _nextServiceDue = null),
                              )
                            : null,
                      ),
                      child: Text(
                        _nextServiceDue != null
                            ? units.formatDate(_nextServiceDue)
                            : context
                                  .l10n
                                  .equipment_serviceDialog_nextServiceNotSet,
                        style: TextStyle(
                          color: _nextServiceDue == null
                              ? Theme.of(context).colorScheme.onSurfaceVariant
                              : null,
                        ),
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 16),

                // Notes field
                TextFormField(
                  controller: _notesController,
                  decoration: InputDecoration(
                    labelText: context.l10n.equipment_serviceDialog_notesLabel,
                    prefixIcon: const Icon(Icons.notes),
                    alignLabelWithHint: true,
                  ),
                  maxLines: 3,
                ),
              ],
            ),
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: _isSaving ? null : () => Navigator.of(context).pop(),
          child: Text(context.l10n.equipment_serviceDialog_cancelButton),
        ),
        FilledButton(
          onPressed: _isSaving ? null : _save,
          child: _isSaving
              ? const SizedBox(
                  width: 20,
                  height: 20,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              : Text(
                  isEditing
                      ? context.l10n.equipment_serviceDialog_updateButton
                      : context.l10n.equipment_serviceDialog_addButton,
                ),
        ),
      ],
    );
  }

  Future<void> _pickServiceDate() async {
    final picked = await showAppDatePicker(
      context: context,
      initialDate: _serviceDate,
      firstDate: DateTime(1950),
      lastDate: DateTime.now(),
    );
    if (picked != null) {
      setState(() => _serviceDate = picked);
    }
  }

  Future<void> _pickNextServiceDate() async {
    // firstDate deliberately reaches into the past, matching the service-date
    // picker. A next-due date that has already passed is normal data rather
    // than a corrupt state -- ServiceRecord.isOverdue exists for exactly that,
    // and a diver back-filling an old service enters one directly. Pinning
    // firstDate to today made an overdue record's initialDate precede it,
    // which trips showDatePicker's assert and crashes the picker.
    final picked = await showAppDatePicker(
      context: context,
      initialDate:
          _nextServiceDue ?? DateTime.now().add(const Duration(days: 365)),
      firstDate: DateTime(1950),
      lastDate: DateTime.now().add(const Duration(days: 365 * 10)),
    );
    if (picked != null) {
      setState(() => _nextServiceDue = picked);
    }
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isSaving = true);

    try {
      final now = DateTime.now();
      final record = ServiceRecord(
        id: widget.existingRecord?.id ?? '',
        equipmentId: widget.equipmentId,
        serviceCategory: _serviceCategory,
        serviceKindId: _serviceKindId,
        serviceDate: _serviceDate,
        provider: _providerController.text.trim().isEmpty
            ? null
            : _providerController.text.trim(),
        cost: parseUserDecimal(_costController.text),
        currency: _currencyController.text.trim().isEmpty
            ? _fallbackCurrencyCode()
            : _currencyController.text.trim().toUpperCase(),
        nextServiceDue: _nextServiceDue,
        notes: _notesController.text.trim(),
        createdAt: widget.existingRecord?.createdAt ?? now,
        updatedAt: now,
      );

      await widget.onSave(record);

      if (mounted) {
        Navigator.of(context).pop();
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              isEditing
                  ? context.l10n.equipment_serviceDialog_snackbar_updated
                  : context.l10n.equipment_serviceDialog_snackbar_added,
            ),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              context.l10n.equipment_serviceDialog_snackbar_error('$e'),
            ),
          ),
        );
        setState(() => _isSaving = false);
      }
    }
  }
}
