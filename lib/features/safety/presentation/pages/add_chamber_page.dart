import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:submersion/features/safety/presentation/providers/emergency_providers.dart';
import 'package:submersion/l10n/l10n_extension.dart';
import 'package:submersion/shared/widgets/record_editing/record_editor_host.dart';

/// The add-chamber form as shown: each field's text as typed.
typedef ChamberDraft = ({
  String name,
  String country,
  String city,
  String phone,
  String notes,
});

/// Minimal form for adding a user hyperbaric chamber entry, on the shared
/// Cancel and Save bar (issue #4527, phase 4). It only creates: a chamber
/// is edited and deleted from its tile on the emergency card.
class AddChamberPage extends ConsumerStatefulWidget {
  const AddChamberPage({super.key});

  @override
  ConsumerState<AddChamberPage> createState() => _AddChamberPageState();
}

class _AddChamberPageState extends ConsumerState<AddChamberPage>
    with RecordEditorHost<AddChamberPage, ChamberDraft> {
  final _formKey = GlobalKey<FormState>();
  final _name = TextEditingController();
  final _country = TextEditingController();
  final _city = TextEditingController();
  final _phone = TextEditingController();
  final _notes = TextEditingController();

  List<TextEditingController> get _controllers => [
    _name,
    _country,
    _city,
    _phone,
    _notes,
  ];

  @override
  void initState() {
    super.initState();
    for (final controller in _controllers) {
      controller.addListener(editorChanged);
    }
    openEditor();
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
  String get editorTable => 'emergency_chambers';

  @override
  String? get editorStoredId => null;

  @override
  String? get editorLeaveLocation => '/settings/diver-profile/emergency-card';

  @override
  String editorTitle(BuildContext context) => context.l10n.addChamber_title;

  @override
  ChamberDraft readEditorDraft() => (
    name: _name.text,
    country: _country.text,
    city: _city.text,
    phone: _phone.text,
    notes: _notes.text,
  );

  @override
  bool validateEditor() => _formKey.currentState?.validate() ?? false;

  @override
  Future<void> writeEditor(String recordId) async {
    // A chamber with no diver is a global one; the card offers Add only
    // with a diver.
    final diverId = editorDiverId;
    if (diverId == null) {
      throw StateError('No active diver to add the chamber for');
    }
    final city = _city.text.trim();
    final notes = _notes.text.trim();
    await ref
        .read(emergencyChamberRepositoryProvider)
        .createChamber(
          id: recordId,
          name: _name.text.trim(),
          country: _country.text.trim().toUpperCase(),
          phone: _phone.text.trim(),
          city: city.isEmpty ? null : city,
          notes: notes.isEmpty ? null : notes,
          diverId: diverId,
        );
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    return editorScaffold(
      context,
      body: Form(
        key: _formKey,
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            TextFormField(
              controller: _name,
              decoration: InputDecoration(labelText: l10n.addChamber_name),
              validator: (v) => (v == null || v.trim().isEmpty)
                  ? l10n.addChamber_nameRequired
                  : null,
            ),
            TextFormField(
              controller: _country,
              decoration: InputDecoration(labelText: l10n.addChamber_country),
              textCapitalization: TextCapitalization.characters,
              // A 2-letter ISO code; the same-country sort compares against
              // upper-case ISO codes, so cap the length to steer input.
              maxLength: 2,
              validator: (v) => (v == null || v.trim().isEmpty)
                  ? l10n.addChamber_countryRequired
                  : null,
            ),
            TextFormField(
              controller: _city,
              decoration: InputDecoration(labelText: l10n.addChamber_city),
            ),
            TextFormField(
              controller: _phone,
              decoration: InputDecoration(labelText: l10n.addChamber_phone),
              keyboardType: TextInputType.phone,
              validator: (v) => (v == null || v.trim().isEmpty)
                  ? l10n.addChamber_phoneRequired
                  : null,
            ),
            TextFormField(
              controller: _notes,
              decoration: InputDecoration(labelText: l10n.addChamber_notes),
              maxLines: 3,
            ),
          ],
        ),
      ),
    );
  }
}
