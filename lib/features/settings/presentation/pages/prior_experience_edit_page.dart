import 'package:flutter/material.dart';

import 'package:submersion/core/providers/provider.dart';
import 'package:submersion/core/utils/number_input.dart';
import 'package:submersion/features/divers/domain/entities/diver.dart';
import 'package:submersion/features/settings/presentation/pages/diver_profile_drafts.dart';
import 'package:submersion/features/settings/presentation/pages/diver_profile_editor.dart';
import 'package:submersion/l10n/l10n_extension.dart';
import 'package:submersion/shared/widgets/app_date_picker.dart';
import 'package:submersion/shared/widgets/forms/number_input_validation.dart';
import 'package:submersion/shared/widgets/record_editing/record_editor_host.dart';

/// Edits a diver's pre-app diving experience (prior dive count, prior bottom
/// time, and the year they started diving). These totals fold into the
/// lifetime statistics alongside logged dives.
class PriorExperienceEditPage extends ConsumerStatefulWidget {
  const PriorExperienceEditPage({super.key});

  @override
  ConsumerState<PriorExperienceEditPage> createState() =>
      _PriorExperienceEditPageState();
}

class _PriorExperienceEditPageState
    extends ConsumerState<PriorExperienceEditPage>
    with
        RecordEditorHost<PriorExperienceEditPage, PriorExperienceDraft>,
        DiverProfileEditor<PriorExperienceEditPage, PriorExperienceDraft> {
  final _formKey = GlobalKey<FormState>();
  final _diveCountCtrl = TextEditingController();
  final _hoursCtrl = TextEditingController();
  final _minutesCtrl = TextEditingController();
  int? _divingSinceYear;

  List<TextEditingController> get _controllers => [
    _diveCountCtrl,
    _hoursCtrl,
    _minutesCtrl,
  ];

  @override
  void initState() {
    super.initState();
    for (final controller in _controllers) {
      controller.addListener(editorChanged);
    }
    openProfileEditor();
  }

  @override
  void dispose() {
    disposeEditor();
    for (final controller in _controllers) {
      controller.dispose();
    }
    super.dispose();
  }

  @override
  String editorTitle(BuildContext context) =>
      context.l10n.divers_edit_priorExperienceSection;

  @override
  PriorExperienceDraft readEditorDraft() => (
    diveCount: _diveCountCtrl.text,
    hours: _hoursCtrl.text,
    minutes: _minutesCtrl.text,
    divingSinceYear: _divingSinceYear,
  );

  @override
  bool validateEditor() => _formKey.currentState?.validate() ?? false;

  @override
  void fillFromDiver(Diver diver) {
    final count = diver.priorDiveCount;
    _diveCountCtrl.text = count == null
        ? ''
        : formatDecimalForInput(count.toDouble());
    final seconds = diver.priorDiveTimeSeconds;
    if (seconds != null) {
      _hoursCtrl.text = formatDecimalForInput((seconds ~/ 3600).toDouble());
      _minutesCtrl.text = formatDecimalForInput(
        ((seconds % 3600) ~/ 60).toDouble(),
      );
    }
    _divingSinceYear = diver.divingSince?.year;
  }

  @override
  Diver applyEditorDraft(
    Diver stored,
    PriorExperienceDraft start,
    PriorExperienceDraft draft,
  ) => applyPriorExperienceDraft(stored, start, draft);

  /// Sets the diving-since year, null for not set, and tells the sitting.
  void _setDivingSince(int? year) {
    setState(() => _divingSinceYear = year);
    editorChanged();
  }

  Future<void> _pickDivingSince() async {
    final now = DateTime.now();
    // A year synced from a device already in the next year (around New
    // Year) would start the picker after its last date.
    final year = (_divingSinceYear ?? now.year - 10).clamp(1900, now.year);
    final picked = await showAppDatePicker(
      context: context,
      initialDate: DateTime(year),
      firstDate: DateTime(1900),
      lastDate: DateTime(now.year, 12, 31),
      initialDatePickerMode: DatePickerMode.year,
    );
    if (picked != null && mounted) _setDivingSince(picked.year);
  }

  @override
  Widget build(BuildContext context) {
    return profileScaffold(
      context,
      form: (context) => SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Card(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Form(key: _formKey, child: _buildFields()),
          ),
        ),
      ),
    );
  }

  String? _nonNegativeInt(String? v, {int? max}) => numberValidator(
    context,
    integer: true,
    check: (n) => n < 0 || (max != null && n > max)
        ? context.l10n.divers_edit_priorInvalidNumber
        : null,
  )(v);

  Widget _buildFields() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          context.l10n.divers_edit_priorExperienceHelp,
          style: Theme.of(context).textTheme.bodySmall,
        ),
        const SizedBox(height: 16),
        TextFormField(
          controller: _diveCountCtrl,
          decoration: InputDecoration(
            labelText: context.l10n.divers_edit_priorDivesLabel,
            prefixIcon: const Icon(Icons.waves),
          ),
          keyboardType: TextInputType.number,
          validator: (v) => _nonNegativeInt(v),
        ),
        const SizedBox(height: 16),
        Row(
          children: [
            Expanded(
              child: TextFormField(
                controller: _hoursCtrl,
                decoration: InputDecoration(
                  labelText: context.l10n.divers_edit_priorHoursLabel,
                  prefixIcon: const Icon(Icons.timer),
                ),
                keyboardType: TextInputType.number,
                validator: (v) => _nonNegativeInt(v),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: TextFormField(
                controller: _minutesCtrl,
                decoration: InputDecoration(
                  labelText: context.l10n.divers_edit_priorMinutesLabel,
                ),
                keyboardType: TextInputType.number,
                validator: (v) => _nonNegativeInt(v, max: 59),
              ),
            ),
          ],
        ),
        const SizedBox(height: 8),
        ListTile(
          contentPadding: EdgeInsets.zero,
          leading: const Icon(Icons.event),
          title: Text(context.l10n.divers_edit_divingSinceLabel),
          subtitle: Text(
            _divingSinceYear != null
                ? '$_divingSinceYear'
                : context.l10n.divers_edit_divingSinceNotSet,
          ),
          trailing: _divingSinceYear != null
              ? IconButton(
                  icon: const Icon(Icons.clear),
                  tooltip: context.l10n.divers_edit_clearDivingSinceTooltip,
                  onPressed: () => _setDivingSince(null),
                )
              : null,
          onTap: _pickDivingSince,
        ),
      ],
    );
  }
}
