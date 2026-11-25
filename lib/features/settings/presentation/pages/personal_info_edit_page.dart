import 'package:flutter/material.dart';

import 'package:submersion/core/providers/provider.dart';
import 'package:submersion/features/divers/domain/entities/diver.dart';
import 'package:submersion/features/settings/presentation/pages/diver_profile_drafts.dart';
import 'package:submersion/features/settings/presentation/pages/diver_profile_editor.dart';
import 'package:submersion/features/settings/presentation/widgets/personal_info_fields.dart';
import 'package:submersion/l10n/l10n_extension.dart';
import 'package:submersion/shared/widgets/record_editing/record_editor_host.dart';

/// The active diver's name, contact details, sex and birth year, on the
/// shared Cancel and Save bar (issue #4527, phase 4). A new diver has its
/// own page, `NewDiverPage`, with the same fields.
class PersonalInfoEditPage extends ConsumerStatefulWidget {
  const PersonalInfoEditPage({super.key});

  @override
  ConsumerState<PersonalInfoEditPage> createState() =>
      _PersonalInfoEditPageState();
}

class _PersonalInfoEditPageState extends ConsumerState<PersonalInfoEditPage>
    with
        RecordEditorHost<PersonalInfoEditPage, PersonalInfoDraft>,
        DiverProfileEditor<PersonalInfoEditPage, PersonalInfoDraft> {
  final _formKey = GlobalKey<FormState>();
  final _form = PersonalInfoForm();

  @override
  void initState() {
    super.initState();
    _form.addListener(editorChanged);
    openProfileEditor();
  }

  @override
  void dispose() {
    disposeEditor();
    _form.dispose();
    super.dispose();
  }

  @override
  String editorTitle(BuildContext context) =>
      context.l10n.settings_profileHub_personalInfo;

  @override
  PersonalInfoDraft readEditorDraft() => _form.draft;

  @override
  bool validateEditor() => _formKey.currentState?.validate() ?? false;

  @override
  void fillFromDiver(Diver diver) => _form.fill(diver);

  @override
  Diver applyEditorDraft(
    Diver stored,
    PersonalInfoDraft start,
    PersonalInfoDraft draft,
  ) => applyPersonalInfoDraft(stored, start, draft);

  @override
  Widget build(BuildContext context) {
    return profileScaffold(
      context,
      form: (context) => SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Card(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Form(
              key: _formKey,
              child: PersonalInfoFields(
                form: _form,
                onSexChanged: (sex) {
                  setState(() => _form.sex = sex);
                  editorChanged();
                },
              ),
            ),
          ),
        ),
      ),
    );
  }
}
