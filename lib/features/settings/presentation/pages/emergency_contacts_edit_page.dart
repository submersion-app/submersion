import 'package:flutter/material.dart';

import 'package:submersion/core/providers/provider.dart';
import 'package:submersion/features/divers/domain/entities/diver.dart';
import 'package:submersion/features/settings/presentation/pages/diver_profile_drafts.dart';
import 'package:submersion/features/settings/presentation/pages/diver_profile_editor.dart';
import 'package:submersion/l10n/l10n_extension.dart';
import 'package:submersion/shared/widgets/record_editing/record_editor_host.dart';

/// The active diver's two emergency contacts, on the shared Cancel and
/// Save bar (issue #4527, phase 4).
class EmergencyContactsEditPage extends ConsumerStatefulWidget {
  const EmergencyContactsEditPage({super.key});

  @override
  ConsumerState<EmergencyContactsEditPage> createState() =>
      _EmergencyContactsEditPageState();
}

class _EmergencyContactsEditPageState
    extends ConsumerState<EmergencyContactsEditPage>
    with
        RecordEditorHost<EmergencyContactsEditPage, EmergencyContactsDraft>,
        DiverProfileEditor<EmergencyContactsEditPage, EmergencyContactsDraft> {
  final _formKey = GlobalKey<FormState>();

  // Primary emergency contact
  final _ec1NameCtrl = TextEditingController();
  final _ec1PhoneCtrl = TextEditingController();
  final _ec1RelationCtrl = TextEditingController();

  // Secondary emergency contact
  final _ec2NameCtrl = TextEditingController();
  final _ec2PhoneCtrl = TextEditingController();
  final _ec2RelationCtrl = TextEditingController();

  List<TextEditingController> get _allControllers => [
    _ec1NameCtrl,
    _ec1PhoneCtrl,
    _ec1RelationCtrl,
    _ec2NameCtrl,
    _ec2PhoneCtrl,
    _ec2RelationCtrl,
  ];

  @override
  void initState() {
    super.initState();
    for (final ctrl in _allControllers) {
      ctrl.addListener(editorChanged);
    }
    openProfileEditor();
  }

  @override
  void dispose() {
    disposeEditor();
    for (final ctrl in _allControllers) {
      ctrl.dispose();
    }
    super.dispose();
  }

  @override
  String editorTitle(BuildContext context) =>
      context.l10n.settings_profileHub_emergencyContacts;

  @override
  EmergencyContactsDraft readEditorDraft() => (
    name1: _ec1NameCtrl.text,
    phone1: _ec1PhoneCtrl.text,
    relation1: _ec1RelationCtrl.text,
    name2: _ec2NameCtrl.text,
    phone2: _ec2PhoneCtrl.text,
    relation2: _ec2RelationCtrl.text,
  );

  @override
  bool validateEditor() => _formKey.currentState?.validate() ?? false;

  @override
  void fillFromDiver(Diver diver) {
    _ec1NameCtrl.text = diver.emergencyContact.name ?? '';
    _ec1PhoneCtrl.text = diver.emergencyContact.phone ?? '';
    _ec1RelationCtrl.text = diver.emergencyContact.relation ?? '';
    _ec2NameCtrl.text = diver.emergencyContact2.name ?? '';
    _ec2PhoneCtrl.text = diver.emergencyContact2.phone ?? '';
    _ec2RelationCtrl.text = diver.emergencyContact2.relation ?? '';
  }

  @override
  Diver applyEditorDraft(
    Diver stored,
    EmergencyContactsDraft start,
    EmergencyContactsDraft draft,
  ) => applyEmergencyContactsDraft(stored, start, draft);

  @override
  Widget build(BuildContext context) {
    return profileScaffold(
      context,
      form: (context) => SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Form(
          key: _formKey,
          child: Column(
            children: [
              _buildContactCard(
                title: context.l10n.divers_edit_primaryContactTitle,
                nameCtrl: _ec1NameCtrl,
                phoneCtrl: _ec1PhoneCtrl,
                relationCtrl: _ec1RelationCtrl,
              ),
              const SizedBox(height: 16),
              _buildContactCard(
                title: context.l10n.divers_edit_secondaryContactTitle,
                nameCtrl: _ec2NameCtrl,
                phoneCtrl: _ec2PhoneCtrl,
                relationCtrl: _ec2RelationCtrl,
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildContactCard({
    required String title,
    required TextEditingController nameCtrl,
    required TextEditingController phoneCtrl,
    required TextEditingController relationCtrl,
  }) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              title,
              style: Theme.of(
                context,
              ).textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w600),
            ),
            const SizedBox(height: 12),
            TextFormField(
              controller: nameCtrl,
              decoration: InputDecoration(
                labelText: context.l10n.divers_edit_contactNameLabel,
                prefixIcon: const Icon(Icons.person_outline),
              ),
              textCapitalization: TextCapitalization.words,
            ),
            const SizedBox(height: 16),
            TextFormField(
              controller: phoneCtrl,
              decoration: InputDecoration(
                labelText: context.l10n.divers_edit_contactPhoneLabel,
                prefixIcon: const Icon(Icons.phone),
              ),
              keyboardType: TextInputType.phone,
            ),
            const SizedBox(height: 16),
            TextFormField(
              controller: relationCtrl,
              decoration: InputDecoration(
                labelText: context.l10n.divers_edit_relationshipLabel,
                prefixIcon: const Icon(Icons.people),
                hintText: context.l10n.divers_edit_relationshipHint,
              ),
              textCapitalization: TextCapitalization.words,
            ),
          ],
        ),
      ),
    );
  }
}
