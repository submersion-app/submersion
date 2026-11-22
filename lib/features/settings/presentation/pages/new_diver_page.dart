import 'dart:async';

import 'package:flutter/material.dart';

import 'package:submersion/core/app/app_exit_guard.dart';
import 'package:submersion/core/providers/provider.dart';
import 'package:submersion/features/divers/presentation/providers/diver_providers.dart';
import 'package:submersion/features/settings/presentation/pages/diver_profile_drafts.dart';
import 'package:submersion/features/settings/presentation/widgets/personal_info_fields.dart';
import 'package:submersion/l10n/l10n_extension.dart';
import 'package:submersion/shared/widgets/record_editing/record_editor_host.dart';

/// A new diver (issue #4527, phase 4): a new-record sitting on the shared
/// Cancel and Save bar, with the personal info page's fields. Save creates
/// the diver, with its settings, in one transaction; then the new diver
/// becomes active once the app may leave what is open.
class NewDiverPage extends ConsumerStatefulWidget {
  const NewDiverPage({super.key});

  @override
  ConsumerState<NewDiverPage> createState() => _NewDiverPageState();

  /// The new diver becomes active once the app may leave what is open: the
  /// page's own sitting has ended by now (a committed Save locks it, which
  /// releases its leave check), so only other pages are asked. The diver
  /// stands either way.
  static Future<void> adoptNewDiver({
    required DiverListNotifier list,
    required AppExitGuard guard,
    required CurrentDiverIdNotifier current,
    required String diverId,
  }) async {
    await list.refresh();
    if (await guard.mayLeave()) await current.setCurrentDiver(diverId);
  }
}

class _NewDiverPageState extends ConsumerState<NewDiverPage>
    with RecordEditorHost<NewDiverPage, PersonalInfoDraft> {
  final _formKey = GlobalKey<FormState>();
  final _form = PersonalInfoForm();

  @override
  void initState() {
    super.initState();
    _form.addListener(editorChanged);
    // A blank form is the starting record, not a seed.
    openEditor();
  }

  @override
  void dispose() {
    disposeEditor();
    _form.dispose();
    super.dispose();
  }

  @override
  String get editorTable => 'divers';

  @override
  String? get editorStoredId => null;

  @override
  String? get editorLeaveLocation => '/settings/diver-profile';

  @override
  String editorTitle(BuildContext context) =>
      context.l10n.settings_profileHub_createDiverTitle;

  @override
  PersonalInfoDraft readEditorDraft() => _form.draft;

  @override
  bool validateEditor() => _formKey.currentState?.validate() ?? false;

  @override
  Future<void> writeEditor(String recordId) async {
    await ref
        .read(diverRepositoryProvider)
        .createDiver(
          newDiverFromDraft(recordId, readEditorDraft(), DateTime.now()),
        );
  }

  @override
  void afterEditorSaved(ScaffoldMessengerState messenger) {
    messenger.showSnackBar(
      SnackBar(content: Text(context.l10n.settings_profileHub_saved)),
    );
    // Read now: the page is leaving.
    unawaited(
      NewDiverPage.adoptNewDiver(
        list: ref.read(diverListNotifierProvider.notifier),
        guard: ref.read(appExitGuardProvider),
        current: ref.read(currentDiverIdProvider.notifier),
        diverId: editorRecordId,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return editorScaffold(
      context,
      body: SingleChildScrollView(
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
